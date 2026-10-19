#!/usr/bin/env python3
"""
Load raw Jolpica CSV files into a SQLite database.

Output: dist/jolpica.db (raw tables only, no transformations)
"""

import os
import pickle
import sqlite3
from pathlib import Path

# Ensure output directory exists
dist_dir = Path("dist")
dist_dir.mkdir(exist_ok=True)

output_db = dist_dir / "jolpica.db"  # Changed from formula1.db

# Remove existing database to ensure clean state
if output_db.exists():
    output_db.unlink()

conn = sqlite3.connect(output_db)

# Load extracted data
input_pickle = Path("output/extracted_data.pkl")
if not input_pickle.exists():
    raise FileNotFoundError(f"Extracted data not found at {input_pickle}")

with open(input_pickle, "rb") as f:
    data = pickle.load(f)

# Create tables and insert data for each entity
for table_name, rows in data.items():
    if not rows:
        print(f"Skipping empty table: {table_name}")
        continue
    
    # Create table
    cursor = conn.cursor()
    cursor.execute(f"DROP TABLE IF EXISTS {table_name}")
    
    # Infer columns from first row
    columns = list(rows[0].keys())
    placeholders = ", ".join(["?" for _ in columns])
    column_names = ", ".join(columns)
    
    # Create table statement
    create_sql = f"CREATE TABLE {table_name} ({column_names})"
    cursor.execute(create_sql)
    
    # Insert data
    insert_sql = f"INSERT INTO {table_name} ({column_names}) VALUES ({placeholders})"
    for row in rows:
        values = [row.get(col) for col in columns]
        cursor.execute(insert_sql, values)
    
    conn.commit()
    print(f"Loaded {len(rows)} rows into {table_name}")

conn.close()
print(f"\nDatabase saved to {output_db}")
