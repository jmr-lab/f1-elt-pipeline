#!/usr/bin/env python3
"""
Publish the transformed F1 SQLite database to Databricks.

Routing:
  jolpica  <- v1 tables (anything not prefixed v2_)
  jmr_lab  <- v2_ tables, plus the f1summary view

Requires: pip install databricks-sql-connector
"""

from __future__ import annotations

import math
import os
import re
import sqlite3
import sys

from databricks import sql as dbsql

SQLITE_PATH = os.environ.get("SQLITE_PATH", "dist/formula1.db")
SERVER_HOSTNAME = os.environ["DATABRICKS_SERVER_HOSTNAME"]   # dbc-xxxx.cloud.databricks.com
HTTP_PATH = os.environ["DATABRICKS_HTTP_PATH"]               # /sql/1.0/warehouses/<id>
ACCESS_TOKEN = os.environ["DATABRICKS_TOKEN"]
CATALOG = os.environ.get("DATABRICKS_CATALOG", "").strip()   # optional; blank => 2-part names

V1_SCHEMA = os.environ.get("JOLPICA_SCHEMA", "jolpica")
V2_SCHEMA = os.environ.get("JMRLAB_SCHEMA", "jmr_lab")

VIEW_NAME = "f1summary"
ROWS_PER_STATEMENT = 500


# ---------------------------------------------------------------- helpers

def ident(name: str) -> str:
    return "`" + name.replace("`", "``") + "`"


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


def literal(value) -> str:
    """Render a Python value as a SQL literal."""
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if math.isnan(value) or math.isinf(value):
            return "NULL"
        return repr(value)
    return "'" + str(value).replace("'", "''") + "'"


def run(cur, sql: str, label: str = "") -> None:
    try:
        cur.execute(sql)
    except Exception as exc:
        print(f"  ✗ {label or sql[:80]}\n    {exc}", file=sys.stderr)
        raise


# ---------------------------------------------------------------- migration

def create_schemas(cur) -> None:
    for schema in (V1_SCHEMA, V2_SCHEMA):
        target = f"{ident(CATALOG)}.{ident(schema)}" if CATALOG else ident(schema)
        run(cur, f"CREATE SCHEMA IF NOT EXISTS {target}", f"create schema {schema}")
        print(f"  ✓ schema {schema}")


def migrate_table(src, cur, schema: str, table: str) -> int:
    src.execute(f"PRAGMA table_info({ident(table)})")
    info = src.fetchall()
    if not info:
        print(f"  ! {table}: no columns, skipping")
        return 0

    columns = [(r[1], r[2]) for r in info]
    col_names = [c[0] for c in columns]

    # Full refresh
    target = qualified(schema, table)
    run(cur, f"DROP TABLE IF EXISTS {target}", f"drop {schema}.{table}")

    ddl_cols = ",\n  ".join(f"{ident(n)} {spark_type(t)}" for n, t in columns)
    run(cur, f"CREATE TABLE {target} (\n  {ddl_cols}\n) USING DELTA",
        f"create {schema}.{table}")

    col_list = ", ".join(ident(c) for c in col_names)
    select_list = ", ".join(ident(c) for c in col_names)

    src.execute(f"SELECT {select_list} FROM {ident(table)}")

    total = 0
    while True:
        rows = src.fetchmany(ROWS_PER_STATEMENT)
        if not rows:
            break
        values = ",\n  ".join(
            "(" + ", ".join(literal(v) for v in row) + ")" for row in rows
        )
        run(
            cur,
            f"INSERT INTO {target} ({col_list}) VALUES\n  {values}",
            f"insert into {schema}.{table}",
        )
        total += len(rows)

    return total


def migrate_view(src, cur, schema: str, view: str, table_map: dict[str, str]) -> None:
    src.execute("SELECT sql FROM sqlite_master WHERE type='view' AND name=?", (view,))
    row = src.fetchone()
    if not row or not row[0]:
        print(f"  ! view {view}: not found, skipping")
        return

    ddl = row[0]

    # Split off the view body so we can rebuild the header ourselves.
    match = re.match(
        r'^\s*CREATE\s+(?:OR\s+REPLACE\s+)?VIEW\s+[`"\[]?\w+[`"\]]?\s+AS\s+',
        ddl,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if not match:
        print(f"  ! view {view}: could not parse definition, skipping")
        return
    body = ddl[match.end():]

    # Qualify every table reference, longest names first so that
    # 'v2_driver' is rewritten before 'driver'.
    for tbl, dest_schema in sorted(table_map.items(), key=lambda kv: -len(kv[0])):
        body = re.sub(
            rf"(?<![\w.`]){re.escape(tbl)}(?![\w`])",
            qualified(dest_schema, tbl),
            body,
        )

    target = qualified(schema, view)
    run(cur, f"DROP VIEW IF EXISTS {target}", f"drop view {schema}.{view}")
    run(cur, f"CREATE VIEW {target} AS\n{body}", f"create view {schema}.{view}")
    print(f"  ✓ view {schema}.{view}")


# ---------------------------------------------------------------- main

def main() -> None:
    if not os.path.exists(SQLITE_PATH):
        sys.exit(f"SQLite database not found: {SQLITE_PATH}")

    src = sqlite3.connect(SQLITE_PATH)
    src.execute(
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
    )
    all_tables = [r[0] for r in src.fetchall()]

    v1_tables = [t for t in all_tables if not t.startswith("v2_")]
    v2_tables = [t for t in all_tables if t.startswith("v2_")]

    table_map = {t: V1_SCHEMA for t in v1_tables}
    table_map.update({t: V2_SCHEMA for t in v2_tables})

    print(f"Source: {SQLITE_PATH}")
    print(f"  {len(v1_tables)} v1 tables -> {V1_SCHEMA}")
    print(f"  {len(v2_tables)} v2 tables -> {V2_SCHEMA}")
    print(f"Target: {SERVER_HOSTNAME}{f' catalog={CATALOG}' if CATALOG else ''}\n")

    conn = dbsql.connect(
        server_hostname=SERVER_HOSTNAME,
        http_path=HTTP_PATH,
        access_token=ACCESS_TOKEN,
    )
    try:
        with conn.cursor() as cur:
            print("[schemas]")
            create_schemas(cur)

            for label, schema, tables in (
                ("v1", V1_SCHEMA, v1_tables),
                ("v2", V2_SCHEMA, v2_tables),
            ):
                print(f"\n[{label}] -> {schema}")
                for t in tables:
                    n = migrate_table(src, cur, schema, t)
                    print(f"  ✓ {t:<34} {n:>8} rows")

            print("\n[views]")
            migrate_view(src, cur, V2_SCHEMA, VIEW_NAME, table_map)

            print("\n[verify]")
            for schema, tables in ((V1_SCHEMA, v1_tables), (V2_SCHEMA, v2_tables)):
                for t in tables:
                    cur.execute(f"SELECT COUNT(*) FROM {qualified(schema, t)}")
                    print(f"  {schema}.{t:<32} {cur.fetchone()[0]:>8}")
            cur.execute(f"SELECT COUNT(*) FROM {qualified(V2_SCHEMA, VIEW_NAME)}")
            print(f"  {V2_SCHEMA}.{VIEW_NAME:<32} {cur.fetchone()[0]:>8}")
    finally:
        conn.close()
        src.close()

    print("\nDone.")


if __name__ == "__main__":
    main()
