#!/usr/bin/env python3
"""
Publish the F1 SQLite databases to Databricks.

Strategy: stage-and-COPY-INTO
  1. Export each SQLite table to Parquet locally (pandas + pyarrow)
  2. Upload the Parquet files to a Unity Catalog volume (Files API)
  3. DROP/CREATE the Delta tables and COPY INTO them from the volume
  4. Verify row counts against SQLite, then clean up staging

Sources:
  dist/jolpica.db    -> jolpica schema   (star schema tables)
  dist/resources.db  -> resources schema (static seed tables)

Requires: pip install "databricks-sql-connector>=3.0" pandas pyarrow requests
"""

from __future__ import annotations

import os
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

# source database -> target schema pairs
SOURCE_DATABASES: list[tuple[str, str]] = [
    (env("SQLITE_PATH", "dist/jolpica.db"), env("JOLPICA_SCHEMA", "jolpica")),
    (env("RESOURCES_SQLITE_PATH", "dist/resources.db"), env("RESOURCES_SCHEMA", "resources")),
]

SERVER_HOSTNAME = os.environ["DATABRICKS_SERVER_HOSTNAME"]
HTTP_PATH = os.environ["DATABRICKS_HTTP_PATH"]
ACCESS_TOKEN = os.environ["DATABRICKS_TOKEN"]
CATALOG = env("DATABRICKS_CATALOG")

# Staging volume: must live in a Unity Catalog catalog.
STAGE_SCHEMA = env("DATABRICKS_STAGE_SCHEMA", "jolpica")
STAGE_VOLUME = env("DATABRICKS_STAGE_VOLUME", "f1_staging")

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
    """Build a fully qualified table name."""
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
    """Execute SQL, raising on error with a helpful label."""
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

def create_schema(cur, schema: str) -> None:
    """Create a target schema if needed."""
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

def migrate_table(src_conn, src_cur, dst_cur, table: str, target_schema: str,
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
    local_dir = local_root / run_dir.replace("/", "_") / table
    files = export_table(src_conn, table, plan, local_dir)

    # --- 2. upload to the volume
    remote_dir = f"{volume_root}/{run_dir}/{table}"
    uploaded: list[str] = []
    for path in files:
        uc_path = f"{remote_dir}/{path.name}"
        upload_file(uc_path, path)
        uploaded.append(uc_path)

    # --- 3. recreate the Delta table
    target = qualified(target_schema, table)
    run(dst_cur, f"DROP TABLE IF EXISTS {target}", f"drop {target_schema}.{table}")

    ddl_cols = ",\n  ".join(f"{ident(n)} {t}" for n, t in plan)
    run(dst_cur, f"CREATE TABLE {target} (\n  {ddl_cols}\n) USING DELTA",
        f"create {target_schema}.{table}")

    # --- 4. load from the volume
    if uploaded:
        run(
            dst_cur,
            f"COPY INTO {target}\nFROM {sql_str(remote_dir)}\nFILEFORMAT = PARQUET",
            f"copy into {target_schema}.{table}",
        )

    dst_cur.execute(f"SELECT COUNT(*) FROM {target}")
    loaded = dst_cur.fetchone()[0]

    # Local Parquet is no longer needed once uploaded.
    shutil.rmtree(local_dir, ignore_errors=True)
    return expected, loaded, uploaded

# ---------------------------------------------------------------- per-database publish

def publish_database(src_cur_unused, dst_cur, db_path: str, target_schema: str,
                     volume_root: str, run_dir: str, local_root: Path,
                     uploaded_paths: list[str]) -> tuple[int, list[tuple[str, int, int]], int]:
    """Publish every table of one SQLite database into one Databricks schema.

    Returns (tables_published, mismatches, total_rows).
    """
    src = sqlite3.connect(db_path)
    src_cur = src.cursor()

    try:
        src_cur.execute(
            "SELECT name FROM sqlite_master "
            "WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
        )
        all_tables = [r[0] for r in src_cur.fetchall()]

        print(f"Source: {db_path}")
        print(f"  {len(all_tables)} tables -> {target_schema}\n")

        tables_published = 0
        mismatches: list[tuple[str, int, int]] = []
        total_rows = 0

        for t in all_tables:
            expected, loaded, paths = migrate_table(
                src, src_cur, dst_cur, t, target_schema,
                volume_root, run_dir, local_root
            )
            uploaded_paths.extend(paths)
            total_rows += loaded
            tables_published += 1
            note = "" if expected == loaded else "   <-- MISMATCH"
            if expected != loaded:
                mismatches.append((f"{target_schema}.{t}", expected, loaded))
            print(f"  ok {t:<34} {loaded:>9} rows{note}")

        return tables_published, mismatches, total_rows
    finally:
        src.close()

# ---------------------------------------------------------------- main

def main() -> None:
    # Keep only sources whose SQLite file exists; resources.db is optional.
    sources: list[tuple[str, str, str]] = []  # (db_path, schema, subdir)
    for db_path, schema in SOURCE_DATABASES:
        if not os.path.exists(db_path):
            print(f"Skipping {db_path}: file not found")
            continue
        subdir = Path(db_path).stem  # jolpica / resources
        sources.append((db_path, schema, subdir))

    if not sources:
        sys.exit("No source databases found - nothing to publish.")

    print(f"Target: {SERVER_HOSTNAME} catalog={CATALOG}")
    for _, schema, _ in sources:
        print(f"  -> schema {schema}")
    print(f"Staging: /Volumes/{CATALOG}/{STAGE_SCHEMA}/{STAGE_VOLUME}\n")

    conn = dbsql.connect(
        server_hostname=SERVER_HOSTNAME,
        http_path=HTTP_PATH,
        access_token=ACCESS_TOKEN,
    )

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    local_root = Path(tempfile.mkdtemp(prefix="f1-stage-"))

    uploaded_paths: list[str] = []
    all_mismatches: list[tuple[str, int, int]] = []
    grand_total_rows = 0
    grand_total_tables = 0

    try:
        with conn.cursor() as dst_cur:
            print("[setup]")
            for _, schema, _ in sources:
                create_schema(dst_cur, schema)
            volume_root = create_volume(dst_cur)

            for db_path, schema, subdir in sources:
                print(f"\n[tables] {Path(db_path).name} -> {schema}")
                run_dir = f"{stamp}/{subdir}"
                tables_published, mismatches, total_rows = publish_database(
                    dst_cur, dst_cur, db_path, schema,
                    volume_root, run_dir, local_root, uploaded_paths
                )
                grand_total_tables += tables_published
                grand_total_rows += total_rows
                all_mismatches.extend(mismatches)
    finally:
        conn.close()
        shutil.rmtree(local_root, ignore_errors=True)

    # --- staging cleanup (best effort; never fails the run)
    print("\n[cleanup]")
    removed = sum(1 for p in uploaded_paths if delete_file(p))
    table_dirs = sorted({p.rsplit("/", 1)[0] for p in uploaded_paths})
    for d in table_dirs:
        delete_file(d)  # per-table directory
    print(f"  removed {removed}/{len(uploaded_paths)} staged file(s)")

    # Exit with error only on row-count mismatches
    if all_mismatches:
        print("\nRow count mismatches detected:")
        for name, exp, got in all_mismatches:
            print(f"  {name}: expected {exp}, got {got}")
        sys.exit(1)

    print(f"\nTotal rows published: {grand_total_rows:,}")
    print("\nDone.")

if __name__ == "__main__":
    main()
