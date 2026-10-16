#!/usr/bin/env python3
"""
Publish the transformed F1 SQLite database to Databricks.

Strategy: stage-and-COPY-INTO
  1. Export each SQLite table to Parquet locally (pandas + pyarrow)
  2. Upload the Parquet files to a Unity Catalog volume (Files API)
  3. DROP/CREATE the Delta tables and COPY INTO them from the volume
  4. Recreate the f1summary view (if it exists in source)
  5. Verify row counts against SQLite, then clean up staging

Routing:
  jolpica  <- v1 tables (anything not prefixed v2_)
  jmr_lab  <- v2_ tables, plus the f1summary view

Requires: pip install "databricks-sql-connector>=3.0" pandas pyarrow requests
"""

from __future__ import annotations

import os
import re
import shutil
import sqlite3
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
import requests
from databricks import sql as dbsql

# ---------------------------------------------------------------- config

def env(name: str, default: str = "") -> str:
    """Read an env var, treating unset *and* empty/whitespace as absent."""
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip() or default

SQLITE_PATH = env("SQLITE_PATH", "dist/formula1.db")
SERVER_HOSTNAME = os.environ["DATABRICKS_SERVER_HOSTNAME"]
HTTP_PATH = os.environ["DATABRICKS_HTTP_PATH"]
ACCESS_TOKEN = os.environ["DATABRICKS_TOKEN"]
CATALOG = env("DATABRICKS_CATALOG")

V1_SCHEMA = env("JOLPICA_SCHEMA", "jolpica")
V2_SCHEMA = env("JMRLAB_SCHEMA", "jmr_lab")

# Staging volume: must live in a Unity Catalog catalog.
STAGE_SCHEMA = env("DATABRICKS_STAGE_SCHEMA", V2_SCHEMA)
STAGE_VOLUME = env("DATABRICKS_STAGE_VOLUME", "f1_staging")

VIEW_NAME = "f1summary"

# Rows pulled from SQLite per Parquet file. Bounds memory on large tables.
READ_CHUNK_ROWS = int(env("READ_CHUNK_ROWS", "200000"))

# ---------------------------------------------------------------- helpers

def ident(name: str) -> str:
    """Backtick-quote an identifier for Databricks."""
    return "`" + name.replace("`", "``") + "`"

def sq_ident(name: str) -> str:
    """Double-quote an identifier for SQLite."""
    return '"' + name.replace('"', '""') + '"'

def sql_str(value: str) -> str:
    """Render a Python string as a SQL string literal."""
    if "'" in value:
        raise ValueError(f"unexpected quote in path: {value!r}")
    return "'" + value + "'"

def qualified(schema: str, table: str) -> str:
    if CATALOG:
        return f"{ident(CATALOG)}.{ident(schema)}.{ident(table)}"
    return f"{ident(schema)}.{ident(table)}"

def spark_type(sqlite_type: str) -> str:
    """Map a SQLite declared type onto a Spark SQL type."""
    t = (sqlite_type or "").upper()
    if "INT" in t:
        return "BIGINT"
    if any(k in t for k in ("REAL", "FLOA", "DOUB", "NUMERIC", "DECIMAL")):
        return "DOUBLE"
    return "STRING"

def run(cur, sql: str, label: str = "") -> None:
    try:
        cur.execute(sql)
    except Exception as exc:
        print(f"  x {label or sql[:80]}\n    {exc}", file=sys.stderr)
        raise

# ---------------------------------------------------------------- type planning

def plan_table_types(src_cur, table: str, columns: list[tuple[str, str]]) -> list[tuple[str, str]]:
    """
    Decide the Spark type for every column.

    SQLite does not enforce declared types: an INTEGER column can hold text.
    We inspect the actual storage classes (typeof) and widen when needed, so
    the Parquet schema, the Delta DDL and the data all agree.
    """
    plan: list[tuple[str, str]] = []
    for name, decl in columns:
        st = spark_type(decl)
        src_cur.execute(
            f"SELECT DISTINCT typeof({sq_ident(name)}) FROM {sq_ident(table)} "
            f"WHERE {sq_ident(name)} IS NOT NULL"
        )
        seen = {r[0] for r in src_cur.fetchall()}

        if "text" in seen or "blob" in seen:
            st = "STRING"
        elif st == "BIGINT" and "real" in seen:
            st = "DOUBLE"

        if st != spark_type(decl):
            print(f"    ! {table}.{name}: stored as {sorted(seen)} "
                  f"(declared {decl}) -> widening to {st}")
        plan.append((name, st))
    return plan

def coerce_frame(df: pd.DataFrame, plan: list[tuple[str, str]]) -> pd.DataFrame:
    """
    Force every column to the planned type.

    Applied identically to every chunk so all Parquet files for a table share
    one schema -- otherwise COPY INTO would reject mismatched files.
    Nullable dtypes are used so NULLs survive and map to real Parquet types.
    """
    out = {}
    for name, st in plan:
        col = df[name]
        if st == "BIGINT":
            out[name] = pd.to_numeric(col, errors="coerce").astype("Int64")
        elif st == "DOUBLE":
            out[name] = pd.to_numeric(col, errors="coerce").astype("Float64")
        elif st == "BOOLEAN":
            out[name] = col.astype("boolean")
        else:
            out[name] = col.astype("string")
    return pd.DataFrame(out, columns=[n for n, _ in plan])

# ---------------------------------------------------------------- staging

def export_table(src_conn, table: str, plan, out_dir: Path) -> list[Path]:
    """Write a table to one or more Parquet files. Returns the file paths."""
    out_dir.mkdir(parents=True, exist_ok=True)
    cols = ", ".join(sq_ident(n) for n, _ in plan)
    reader = pd.read_sql_query(
        f"SELECT {cols} FROM {sq_ident(table)}", src_conn, chunksize=READ_CHUNK_ROWS
    )

    files: list[Path] = []
    for i, chunk in enumerate(reader):
        path = out_dir / f"part-{i:05d}.parquet"
        coerce_frame(chunk, plan).to_parquet(path, index=False, engine="pyarrow")
        files.append(path)
    return files

def upload_file(uc_path: str, local_path: Path) -> None:
    """Upload one file to a Unity Catalog volume via the Files API."""
    url = f"https://{SERVER_HOSTNAME}/api/2.0/fs/files{uc_path}"
    headers = {
        "Authorization": f"Bearer {ACCESS_TOKEN}",
        "Content-Type": "application/octet-stream",
    }
    # Send bytes rather than a file object: avoids chunked transfer-encoding,
    # which the Files API endpoint does not reliably accept.
    with open(local_path, "rb") as fh:
        payload = fh.read()
    resp = requests.put(url, headers=headers, data=payload, timeout=600)
    if resp.status_code >= 300:
        raise RuntimeError(
            f"upload failed ({resp.status_code}) for {uc_path}: {resp.text[:300]}"
        )

def delete_file(uc_path: str) -> bool:
    """Best-effort delete of a single file from a volume."""
    url = f"https://{SERVER_HOSTNAME}/api/2.0/fs/files{uc_path}"
    try:
        resp = requests.delete(
            url, headers={"Authorization": f"Bearer {ACCESS_TOKEN}"}, timeout=120
        )
        return resp.status_code < 300
    except requests.RequestException:
        return False

# ---------------------------------------------------------------- databricks

def create_schemas(cur) -> None:
    for schema in (V1_SCHEMA, V2_SCHEMA):
        target = f"{ident(CATALOG)}.{ident(schema)}" if CATALOG else ident(schema)
        run(cur, f"CREATE SCHEMA IF NOT EXISTS {target}", f"create schema {schema}")
        print(f"  ok schema {schema}")

def create_volume(cur) -> str:
    """Create the staging volume if needed; return its /Volumes path."""
    if not CATALOG or not STAGE_SCHEMA:
        sys.exit(
            "DATABRICKS_CATALOG and the staging schema must both be non-empty: "
            "staging volumes require a three-level Unity Catalog namespace."
        )
    name = f"{ident(CATALOG)}.{ident(STAGE_SCHEMA)}.{ident(STAGE_VOLUME)}"
    run(cur, f"CREATE VOLUME IF NOT EXISTS {name}", f"create volume {STAGE_VOLUME}")
    print(f"  ok volume {CATALOG}.{STAGE_SCHEMA}.{STAGE_VOLUME}")
    return f"/Volumes/{CATALOG}/{STAGE_SCHEMA}/{STAGE_VOLUME}"

def migrate_table(src_conn, src_cur, dst_cur, schema: str, table: str,
                  volume_root: str, run_dir: str,
                  local_root: Path) -> tuple[int, int, list[str]]:
    """
    Export -> upload -> DROP/CREATE/COPY INTO one table.

    Returns (expected_rows, loaded_rows, uploaded_paths).
    """
    src_cur.execute(f"PRAGMA table_info({sq_ident(table)})")
    info = src_cur.fetchall()
    if not info:
        print(f"  ! {table}: no columns, skipping")
        return 0, 0, []

    columns = [(r[1], r[2]) for r in info]
    plan = plan_table_types(src_cur, table, columns)

    src_cur.execute(f"SELECT COUNT(*) FROM {sq_ident(table)}")
    expected = src_cur.fetchone()[0]

    # --- 1. export locally
    local_dir = local_root / schema / table
    files = export_table(src_conn, table, plan, local_dir)

    # --- 2. upload to the volume
    remote_dir = f"{volume_root}/{run_dir}/{schema}/{table}"
    uploaded: list[str] = []
    for path in files:
        uc_path = f"{remote_dir}/{path.name}"
        upload_file(uc_path, path)
        uploaded.append(uc_path)

    # --- 3. recreate the Delta table
    target = qualified(schema, table)
    run(dst_cur, f"DROP TABLE IF EXISTS {target}", f"drop {schema}.{table}")

    ddl_cols = ",\n  ".join(f"{ident(n)} {t}" for n, t in plan)
    run(dst_cur, f"CREATE TABLE {target} (\n  {ddl_cols}\n) USING DELTA",
        f"create {schema}.{table}")

    # --- 4. load from the volume
    if uploaded:
        run(
            dst_cur,
            f"COPY INTO {target}\nFROM {sql_str(remote_dir)}\nFILEFORMAT = PARQUET",
            f"copy into {schema}.{table}",
        )

    dst_cur.execute(f"SELECT COUNT(*) FROM {target}")
    loaded = dst_cur.fetchone()[0]

    # Local Parquet is no longer needed once uploaded.
    shutil.rmtree(local_dir, ignore_errors=True)
    return expected, loaded, uploaded

def to_spark_identifiers(sql: str) -> str:
    """
    Convert SQLite double-quoted identifiers to Spark backticks.

    SQLite accepts "rank" as a quoted identifier; Spark SQL treats double
    quotes as string literals, so reserved words must be backticked instead.
    """
    return re.sub(
        r'"([^"]*)"',
        lambda m: "`" + m.group(1).replace("`", "``") + "`",
        sql,
    )

def migrate_view(src_cur, dst_cur, schema: str, view: str, table_map: dict) -> None:
    src_cur.execute(
        "SELECT sql FROM sqlite_master WHERE type='view' AND name=?", (view,)
    )
    row = src_cur.fetchone()
    if not row or not row[0]:
        print(f"  ! view {view}: not found, skipping")
        return

    ddl = row[0]
    match = re.match(
        r'^\s*CREATE\s+(?:OR\s+REPLACE\s+)?VIEW\s+[`"\[]?\w+[`"\]]?\s+AS\s+',
        ddl,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if not match:
        print(f"  ! view {view}: could not parse definition, skipping")
        return
    body = ddl[match.end():]

    # Rewrite table references ONLY where they follow FROM or JOIN.
    # Anchoring to those keywords stops column aliases that happen to share a
    # table's name (e.g. `AS round`) from being rewritten into table refs.
    # Longest names first so `v2_session_entry` is tried before `session_entry`.
    for tbl, dest_schema in sorted(table_map.items(), key=lambda kv: -len(kv[0])):
        body = re.sub(
            rf"(?i)(\bFROM\s+|\bJOIN\s+){re.escape(tbl)}(?![\w`])",
            lambda m, ds=dest_schema, t=tbl: f"{m.group(1)}{qualified(ds, t)}",
            body,
        )

    # SQLite double-quoted identifiers -> Spark backticks.
    body = to_spark_identifiers(body)

    target = qualified(schema, view)
    run(dst_cur, f"DROP VIEW IF EXISTS {target}", f"drop view {schema}.{view}")
    run(dst_cur, f"CREATE VIEW {target} AS\n{body}", f"create view {schema}.{view}")
    print(f"  ok view {schema}.{view}")

# ---------------------------------------------------------------- main

def main() -> None:
    if not os.path.exists(SQLITE_PATH):
        sys.exit(f"SQLite database not found: {SQLITE_PATH}")

    src = sqlite3.connect(SQLITE_PATH)
    src_cur = src.cursor()

    src_cur.execute(
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
    )
    all_tables = [r[0] for r in src_cur.fetchall()]

    v1_tables = [t for t in all_tables if not t.startswith("v2_")]
    v2_tables = [t for t in all_tables if t.startswith("v2_")]

    table_map = {t: V1_SCHEMA for t in v1_tables}
    table_map.update({t: V2_SCHEMA for t in v2_tables})

    run_dir = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    local_root = Path(tempfile.mkdtemp(prefix="f1-stage-"))

    print(f"Source: {SQLITE_PATH}")
    print(f"  {len(v1_tables)} v1 tables -> {V1_SCHEMA}")
    print(f"  {len(v2_tables)} v2 tables -> {V2_SCHEMA}")
    print(f"Target: {SERVER_HOSTNAME} catalog={CATALOG}")
    print(f"Staging: {local_root} -> /Volumes/{CATALOG}/{STAGE_SCHEMA}/{STAGE_VOLUME}/{run_dir}\n")

    conn = dbsql.connect(
        server_hostname=SERVER_HOSTNAME,
        http_path=HTTP_PATH,
        access_token=ACCESS_TOKEN,
    )

    uploaded_paths: list[str] = []
    mismatches: list[tuple[str, int, int]] = []
    total_rows = 0
    view_created = False

    try:
        with conn.cursor() as dst_cur:
            print("[setup]")
            create_schemas(dst_cur)
            volume_root = create_volume(dst_cur)

            for label, schema, tables in (
                ("v1", V1_SCHEMA, v1_tables),
                ("v2", V2_SCHEMA, v2_tables),
            ):
                print(f"\n[{label}] -> {schema}")
                for t in tables:
                    expected, loaded, paths = migrate_table(
                        src, src_cur, dst_cur, schema, t, volume_root, run_dir, local_root
                    )
                    uploaded_paths.extend(paths)
                    total_rows += loaded
                    note = "" if expected == loaded else "   <-- MISMATCH"
                    if expected != loaded:
                        mismatches.append((f"{schema}.{t}", expected, loaded))
                    print(f"  ok {t:<34} {loaded:>9} rows{note}")

            print("\n[views]")
            migrate_view(src_cur, dst_cur, V2_SCHEMA, VIEW_NAME, table_map)

            # Track whether the view was created for verification
            src_cur.execute(
                "SELECT sql FROM sqlite_master WHERE type='view' AND name=?", (VIEW_NAME,)
            )
            view_row = src_cur.fetchone()
            if view_row and view_row[0]:
                view_created = True

            print("\n[verify]")
            # Tables were already verified per-table above
            # View may not exist if transform-tables.sql didn't create it
            if view_created:
                try:
                    dst_cur.execute(f"SELECT COUNT(*) FROM {qualified(V2_SCHEMA, VIEW_NAME)}")
                    print(f"  {V2_SCHEMA}.{VIEW_NAME:<32} {dst_cur.fetchone()[0]:>9}")
                except Exception as e:
                    print(f"  ! {V2_SCHEMA}.{VIEW_NAME}: {e}")
            else:
                print(f"  - {V2_SCHEMA}.{VIEW_NAME:<32} (not created - check transform-tables.sql)")
            print(f"\n  total rows loaded: {total_rows:,}")
            if mismatches:
                print(f"  {len(mismatches)} table(s) with row-count mismatch:", file=sys.stderr)
                for name, exp, got in mismatches:
                    print(f"    {name}: sqlite={exp:,} databricks={got:,}", file=sys.stderr)
    finally:
        conn.close()
        src.close()
        shutil.rmtree(local_root, ignore_errors=True)

    # --- staging cleanup (best effort; never fails the run)
    print("\n[cleanup]")
    removed = sum(1 for p in uploaded_paths if delete_file(p))
    for p in uploaded_paths:
        delete_file(f"{p.rsplit('/', 1)[0]}")  # per-table directory
    print(f"  removed {removed}/{len(uploaded_paths)} staged file(s)")

    # Exit with error only on row-count mismatches, not on missing view
    if mismatches:
        sys.exit(1)
    print("\nDone.")

if __name__ == "__main__":
    main()
