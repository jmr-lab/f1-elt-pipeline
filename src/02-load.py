"""
F1 Star Schema Database Builder

Normalizes extracted CSV files into SQLite database with
proper relationships matching the Jolpica schema.
"""

from pathlib import Path
from typing import Dict
import pandas as pd
import pickle
import sqlite3
import sys

TABLE_NAME_MAPPING = {
    'season': 'season',
    'circuit': 'circuit',
    'driver': 'driver',
    'team': 'team',
    'baseteam': 'base_team',
    'round': 'round',
    'roundentry': 'roundentry',
    'session': 'session',
    'sessionentry': 'session_entry',
    'teamdriver': 'team_driver',
    'driverchampionship': 'driver_championship',
    'teamchampionship': 'team_championship',
    'lap': 'lap',
    'pitstop': 'pit_stop',
    'penalty': 'penalty',
    'pointsystem': 'points_system',
    'championshipsystem': 'championship_system',
    'championshipadjustment': 'championship_adjustment'
}

def get_extracted_data_path() -> Path:
    """Locate the extracted_data.pkl file."""
    src_folder = Path(__file__).resolve().parent
    output_folder = src_folder.parent / "output"
    return output_folder / "extracted_data.pkl"

def get_db_folder() -> Path:
    """Return the data/db folder, creating it if needed."""
    src_folder = Path(__file__).resolve().parent
    db_folder = src_folder.parent / "data" / "db"
    db_folder.mkdir(parents=True, exist_ok=True)
    return db_folder

def create_complete_schema(conn: sqlite3.Connection) -> None:
    """Create the normalized F1 database schema with FK constraints."""
    
    conn.execute("PRAGMA foreign_keys = OFF;")
    
    schema_sql = """
    -- Dimension tables (created first)
    CREATE TABLE IF NOT EXISTS season (
        id INTEGER PRIMARY KEY,
        year INTEGER UNIQUE,
        api_id INTEGER,
        championship_system_id INTEGER,
        wikipedia TEXT
    );
    
    CREATE TABLE IF NOT EXISTS circuit (
        id INTEGER PRIMARY KEY,
        name TEXT,
        reference TEXT,
        locality TEXT,
        country TEXT,
        country_code TEXT,
        latitude REAL,
        longitude REAL,
        altitude INTEGER,
        wikipedia TEXT,
        api_id INTEGER
    );
    
    CREATE TABLE IF NOT EXISTS driver (
        id INTEGER PRIMARY KEY,
        reference TEXT,
        abbreviation TEXT,
        forename TEXT,
        surname TEXT,
        nationality TEXT,
        country_code TEXT,
        date_of_birth DATE,
        permanent_car_number INTEGER,
        wikipedia TEXT,
        api_id INTEGER
    );
    
    CREATE TABLE IF NOT EXISTS team (
        id INTEGER PRIMARY KEY,
        name TEXT,
        reference TEXT,
        nationality TEXT,
        country_code TEXT,
        base_team_id INTEGER,
        primary_color TEXT,
        wikipedia TEXT,
        api_id INTEGER
    );
    
    -- Fact tables WITH FK constraints
    CREATE TABLE IF NOT EXISTS round (
        id INTEGER PRIMARY KEY,
        season_id INTEGER,
        circuit_id INTEGER,
        number INTEGER,
        race_number INTEGER,
        name TEXT,
        date TEXT,
        is_cancelled INTEGER,
        wikipedia TEXT,
        api_id INTEGER,
        FOREIGN KEY (season_id) REFERENCES season(id),
        FOREIGN KEY (circuit_id) REFERENCES circuit(id)
    );
    
    CREATE TABLE IF NOT EXISTS team_driver (
        id INTEGER PRIMARY KEY,
        season_id INTEGER,
        team_id INTEGER,
        driver_id INTEGER,
        role TEXT,
        api_id INTEGER,
        FOREIGN KEY (season_id) REFERENCES season(id),
        FOREIGN KEY (team_id) REFERENCES team(id),
        FOREIGN KEY (driver_id) REFERENCES driver(id)
    );
    
    CREATE TABLE IF NOT EXISTS roundentry (
        id INTEGER PRIMARY KEY,
        round_id INTEGER,
        team_driver_id INTEGER,
        car_number INTEGER,
        api_id INTEGER,
        FOREIGN KEY (round_id) REFERENCES round(id),
        FOREIGN KEY (team_driver_id) REFERENCES team_driver(id)
    );
    
    CREATE TABLE IF NOT EXISTS session (
        id INTEGER PRIMARY KEY,
        round_id INTEGER,
        type TEXT,
        number INTEGER,
        timestamp TEXT,
        timezone TEXT,
        scheduled_laps INTEGER,
        point_system_id INTEGER,
        is_cancelled INTEGER,
        has_time_data INTEGER,
        api_id INTEGER,
        FOREIGN KEY (round_id) REFERENCES round(id)
    );
    
    CREATE TABLE IF NOT EXISTS session_entry (
        id INTEGER PRIMARY KEY,
        session_id INTEGER,
        round_entry_id INTEGER,
        grid INTEGER,
        position INTEGER,
        points REAL,
        laps_completed INTEGER,
        fastest_lap_rank INTEGER,
        time TEXT,
        detail TEXT,
        status TEXT,
        is_classified INTEGER,
        is_eligible_for_points INTEGER,
        api_id INTEGER,
        FOREIGN KEY (session_id) REFERENCES session(id),
        FOREIGN KEY (round_entry_id) REFERENCES roundentry(id)
    );
    
    CREATE TABLE IF NOT EXISTS driver_championship (
        id INTEGER PRIMARY KEY,
        season_id INTEGER,
        year INTEGER,
        driver_id INTEGER,
        round_id INTEGER,
        position INTEGER,
        points REAL,
        win_count INTEGER,
        highest_finish INTEGER,
        is_eligible INTEGER,
        adjustment_type TEXT,
        session_id INTEGER,
        session_number INTEGER,
        round_number INTEGER,
        FOREIGN KEY (season_id) REFERENCES season(id),
        FOREIGN KEY (driver_id) REFERENCES driver(id),
        FOREIGN KEY (round_id) REFERENCES round(id),
        FOREIGN KEY (session_id) REFERENCES session(id)
    );
    
    CREATE TABLE IF NOT EXISTS team_championship (
        id INTEGER PRIMARY KEY,
        season_id INTEGER,
        year INTEGER,
        team_id INTEGER,
        round_id INTEGER,
        position INTEGER,
        points REAL,
        win_count INTEGER,
        highest_finish INTEGER,
        is_eligible INTEGER,
        adjustment_type TEXT,
        session_id INTEGER,
        session_number INTEGER,
        round_number INTEGER
    );
    
    CREATE TABLE IF NOT EXISTS lap (
        id INTEGER PRIMARY KEY,
        session_entry_id INTEGER,
        number INTEGER,
        position INTEGER,
        time TEXT,
        average_speed TEXT,
        is_entry_fastest_lap INTEGER,
        is_deleted INTEGER,
        api_id INTEGER
    );
    
    CREATE TABLE IF NOT EXISTS pit_stop (
        id INTEGER PRIMARY KEY,
        session_entry_id INTEGER,
        lap_id INTEGER,
        number INTEGER,
        duration TEXT,
        local_timestamp TEXT,
        api_id INTEGER
    );
    
    CREATE TABLE IF NOT EXISTS penalty (
        id INTEGER PRIMARY KEY,
        earned_id INTEGER,
        served_id INTEGER,
        position INTEGER,
        license_points INTEGER,
        is_time_served_in_pit INTEGER,
        time TEXT,
        api_id INTEGER
    );
    
    CREATE TABLE IF NOT EXISTS base_team (
        id INTEGER PRIMARY KEY,
        name TEXT,
        api_id INTEGER
    );
    
    CREATE TABLE IF NOT EXISTS points_system (
        id INTEGER PRIMARY KEY,
        name TEXT,
        reference TEXT,
        partial INTEGER,
        driver_position_points INTEGER,
        driver_fastest_lap INTEGER,
        team_position_points INTEGER,
        team_fastest_lap INTEGER,
        shared_drive INTEGER,
        is_double_points INTEGER,
        api_id INTEGER
    );
    
    CREATE TABLE IF NOT EXISTS championship_system (
        id INTEGER PRIMARY KEY,
        name TEXT,
        reference TEXT,
        driver_best_results INTEGER,
        team_best_results INTEGER,
        driver_season_split INTEGER,
        team_season_split INTEGER,
        team_points_per_session INTEGER,
        eligibility TEXT,
        api_id INTEGER
    );
    
    CREATE TABLE IF NOT EXISTS championship_adjustment (
        id INTEGER PRIMARY KEY,
        adjustment INTEGER,
        api_id INTEGER,
        driver_id INTEGER,
        points REAL,
        season_id INTEGER,
        team_id INTEGER
    );
    
    -- Indexes
    CREATE INDEX IF NOT EXISTS idx_round_season ON round(season_id);
    CREATE INDEX IF NOT EXISTS idx_round_circuit ON round(circuit_id);
    CREATE INDEX IF NOT EXISTS idx_session_round ON session(round_id);
    CREATE INDEX IF NOT EXISTS idx_session_entry_session ON session_entry(session_id);
    CREATE INDEX IF NOT EXISTS idx_driver_champ_season ON driver_championship(season_id);
    CREATE INDEX IF NOT EXISTS idx_team_champ_season ON team_championship(season_id);
    CREATE INDEX IF NOT EXISTS idx_session_entry_round_entry ON session_entry(round_entry_id);
    CREATE INDEX IF NOT EXISTS idx_roundentry_round ON roundentry(round_id);
    CREATE INDEX IF NOT EXISTS idx_roundentry_team_driver ON roundentry(team_driver_id);
    CREATE INDEX IF NOT EXISTS idx_team_driver_driver ON team_driver(driver_id);
    CREATE INDEX IF NOT EXISTS idx_team_driver_team ON team_driver(team_id);
    """
    
    conn.executescript(schema_sql)
    
    # REMOVED: FK re-enabling here (now controlled solely by build_f1_db)


def insert_table_data(
    conn: sqlite3.Connection,
    table_name: str,
    df: pd.DataFrame
) -> int:
    """Insert data from DataFrame into table - preserves schema with FK constraints."""
    
    target_table = TABLE_NAME_MAPPING.get(table_name, table_name)
    
    # Get DB schema columns
    try:
        cursor = conn.execute(f"PRAGMA table_info({target_table});")
        db_columns = {row[1] for row in cursor.fetchall()}
    except Exception as e:
        print(f"{table_name}: Failed to get DB schema: {e}")
        return 0
    
    csv_columns = set(df.columns)
    
    # Filter to only columns that exist in both
    cols_to_use = list(db_columns & csv_columns)
    
    if not cols_to_use:
        print(f"{table_name}: NO matching columns between CSV and DB!")
        print(f" CSV columns: {sorted(csv_columns)}")
        print(f" DB columns:  {sorted(db_columns)}")
        return 0
    
    # Create filtered dataframe with matching columns
    df_subset = df[cols_to_use]
    
    # Attempt insertion
    try:
        df_subset.to_sql(target_table, conn, if_exists='append', index=False)
        # REMOVED print here (only print once in caller loop)
        return len(df_subset)
    except Exception as e:
        print(f"{table_name}: Insertion failed: {type(e).__name__}: {e}")
        print(f" CSV columns ({len(csv_columns)}): {sorted(csv_columns)}")
        print(f" DB columns ({len(db_columns)}):  {sorted(db_columns)}")
        print(f" Matching columns: {cols_to_use}")
        raise


def get_table_processing_order(dataframes: Dict[str, pd.DataFrame]) -> list:
    """
    Return tables in dependency order for FK-safe data insertion.
    
    Order rationale:
    1. Independent dimension tables (no FKs needed)
    2. Dimension tables with minimal FKs
    3. Core fact tables (need dimensions loaded)
    4. Transactional tables (need all upstream tables loaded)
    """
    
    # Define explicit dependency hierarchy using CANONICAL names only
    table_order = [
        # Level 1: Independent tables (load first)
        'season', 'circuit', 'driver', 'team', 'base_team',
        'points_system', 'championship_system',
        
        # Level 2: Depends on Level 1
        'round', 'team_driver',
        
        # Level 3: Depends on Levels 1-2
        'roundentry', 'session',
        
        # Level 4: Depends on Levels 1-3
        'session_entry', 'driver_championship', 'team_championship',
        
        # Level 5: Detail tables (depend on session_entry existing)
        'lap', 'pit_stop', 'penalty',
        
        # Level 6: Special lookup tables
        'championship_adjustment'
    ]
    
    # Filter to only tables that exist in our data
    available_tables = set(dataframes.keys())
    ordered = [t for t in table_order if t in available_tables]
    
    # Add any tables not in our predefined order (edge case fallback)
    remaining = available_tables - set(ordered)
    ordered.extend(sorted(remaining))
    
    return ordered


def filter_empty_tables(dataframes: Dict[str, pd.DataFrame]) -> Dict[str, pd.DataFrame]:
    """Filter out empty DataFrames from processing."""
    return {name: df for name, df in dataframes.items() if not df.empty}


def build_f1_db(
    extracted_data_path: Path = None,
    output_db_path: Path = None
) -> Path:
    """Build the normalized F1 database with FK-safe ordering."""
    
    # Setup paths
    if extracted_data_path is None:
        extracted_data_path = get_extracted_data_path()
    
    if output_db_path is None:
        db_folder = get_db_folder()
        output_db_path = db_folder / "formula1.db"
    
    if not extracted_data_path.exists():
        raise FileNotFoundError(
            f"Extracted data not found at {extracted_data_path}. "
            "Please run extract.py first."
        )
    
    if output_db_path.exists():
        output_db_path.unlink()
        print(f"Cleared existing database: {output_db_path}")
    
    print(f"\n{'='*60}")
    print("Building F1 Star Schema Database")
    print(f"{'='*60}\n")
    
    print(f"Loading extracted data from: {extracted_data_path}")
    with open(extracted_data_path, "rb") as f:
        dataframes = pickle.load(f)
    
    # FILTER EMPTY FIRST
    dataframes = filter_empty_tables(dataframes)
    
    # CRITICAL: Normalize all table names to canonical form
    dataframes = {TABLE_NAME_MAPPING.get(k, k): df for k, df in dataframes.items()}
    
    print(f"Found {len(dataframes)} non-empty tables to process\n")
    
    # Get correct table order (now using canonical names)
    ordered_tables = get_table_processing_order(dataframes)
    print(f"Processing order ({len(ordered_tables)} tables):\n  {' → '.join(ordered_tables)}\n")
    
    conn = sqlite3.connect(str(output_db_path))
    
    # Disable FK during load
    conn.execute("PRAGMA foreign_keys = OFF;")
    
    try:
        print("Creating database schema...")
        create_complete_schema(conn)
        
        print("\nInserting data into tables:\n")
        tables_processed = 0
        
        # Process in dependency order
        for table_name in ordered_tables:
            df = dataframes[table_name]
            
            try:
                row_count = insert_table_data(conn, table_name, df)
                
                if row_count > 0:
                    print(f" {table_name}: {row_count:,} rows")
                    tables_processed += 1
                else:
                    print(f" {table_name}: No matching columns or zero rows")
                    
            except Exception as e:
                print(f" {table_name}: ERROR - {type(e).__name__}: {str(e)[:150]}")
        
        conn.commit()
        
        # NOW enable FK enforcement and verify
        print("\n" + "-"*60)
        print("Post-load FK validation:")
        print("-"*60)
        
        conn.execute("PRAGMA foreign_keys = ON;")
        violations = conn.execute("PRAGMA foreign_key_check;").fetchall()
        
        if violations:
            print(f"Found {len(violations)} FK violation(s):")
            for v in violations[:10]:
                print(f"    - Table '{v[0]}': row_id={v[1]}, parent_table={v[2]}, parent_key_idx={v[3]}")
            if len(violations) > 10:
                print(f"    ... and {len(violations) - 10} more")
        else:
            print("All foreign key constraints validated successfully")
        
        # Summary
        print("\n" + "-"*60)
        print("Final table row counts:")
        print("-"*60)
        
        cursor = conn.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        total_rows = 0
        for (table,) in cursor.fetchall():
            count = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            total_rows += count
            if count > 0:
                print(f"  {table}: {count:,} rows")
            else:
                print(f"  {table}: empty")
        
        print(f"\nDatabase creation complete")
        print(f"Output: {output_db_path.absolute()}")
        print(f"Total rows: {total_rows:,}")
        print(f"Tables loaded: {tables_processed}/{len(dataframes)}")
        
        return output_db_path
        
    finally:
        conn.close()


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Build F1 Star Schema Database"
    )
    parser.add_argument("--input", type=str, default=None, help="Path to extracted_data.pkl")
    parser.add_argument("--output", type=str, default=None, help="Path to output database")
    parser.add_argument("--clean", action="store_true", help="Remove existing database")
    
    args = parser.parse_args()
    
    db_path = Path(args.output) if args.output else Path("output/formula1.db")
    
    if args.clean:
        if db_path.exists():
            print(f"Removing: {db_path}")
            db_path.unlink()
    
    try:
        # Build the star schema database
        result = build_f1_db(
            extracted_data_path=Path(args.input) if args.input else None,
            output_db_path=Path(args.output) if args.output else None
        )
        
        print("Database build complete")
        print(f"Location: {result.absolute()}")

        sys.exit(0)
        
    except Exception as e:
        print(f"\n Error: {e}")
        sys.exit(1)
