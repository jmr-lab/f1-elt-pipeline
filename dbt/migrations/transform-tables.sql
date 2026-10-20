.bail on
-- ============================================================
-- TRANSFORM: jolpica.db → formula1.db
-- Reads from attached jolpica.db, writes to main database (formula1.db)
-- ============================================================

-- ATTACH the raw source database
ATTACH DATABASE 'jolpica.db' AS jolpica;

-- ============================================================
-- PART 2: DROP EXISTING OBJECTS (main schema ONLY)
-- ============================================================
DROP TABLE IF EXISTS main.season;
DROP TABLE IF EXISTS main.circuit;
DROP TABLE IF EXISTS main.driver;
DROP TABLE IF EXISTS main.constructor;
DROP TABLE IF EXISTS main.engine;
DROP TABLE IF EXISTS main.driver_season;
DROP TABLE IF EXISTS main.constructor_season;
DROP TABLE IF EXISTS main.constructor_engine;
DROP TABLE IF EXISTS main.round;
DROP TABLE IF EXISTS main.constructor_driver;
DROP TABLE IF EXISTS main.round_entry;
DROP TABLE IF EXISTS main.session;
DROP TABLE IF EXISTS main.session_entry;
DROP TABLE IF EXISTS main.driver_championship;
DROP TABLE IF EXISTS main.constructor_championship;
DROP TABLE IF EXISTS main.lap;
DROP TABLE IF EXISTS main.pit_stop;
DROP TABLE IF EXISTS main.penalty;
DROP TABLE IF EXISTS main.countries;
DROP TABLE IF EXISTS main.constructor_base;

-- ============================================================
-- PART 3: CREATE DIMENSION TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS season (
    id INTEGER PRIMARY KEY,
    year INTEGER UNIQUE NOT NULL,
    championship_system_id INTEGER,
    wikipedia TEXT
);

CREATE TABLE IF NOT EXISTS circuit (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    reference TEXT,
    locality TEXT,
    country TEXT,
    country_code TEXT,
    latitude REAL,
    longitude REAL,
    altitude INTEGER,
    wikipedia TEXT
);

CREATE TABLE IF NOT EXISTS driver (
    id INTEGER PRIMARY KEY,
    reference TEXT UNIQUE NOT NULL,
    abbreviation TEXT,
    forename TEXT,
    surname TEXT NOT NULL,
    permanent_car_number INTEGER,
    date_of_birth DATE,
    birth_country TEXT,
    wikipedia TEXT
);

CREATE TABLE IF NOT EXISTS constructor (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    reference TEXT UNIQUE NOT NULL,
    constructor_base_id INTEGER,
    primary_color TEXT,
    wikipedia TEXT
);

CREATE TABLE IF NOT EXISTS engine (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    reference TEXT UNIQUE NOT NULL,
    nationality TEXT,
    founded_year INTEGER,
    wikipedia TEXT
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

CREATE TABLE IF NOT EXISTS constructor_base (
    id INTEGER PRIMARY KEY,
    name TEXT,
    api_id INTEGER
);

-- ============================================================
-- PART 4: CREATE YEAR-GRAIN ATTRIBUTE HISTORY TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS driver_season (
    driver_id INTEGER NOT NULL,
    season_id INTEGER NOT NULL,
    nationality TEXT NOT NULL,
    country_code TEXT,
    PRIMARY KEY (driver_id, season_id),
    FOREIGN KEY (driver_id) REFERENCES driver(id),
    FOREIGN KEY (season_id) REFERENCES season(id)
);

CREATE TABLE IF NOT EXISTS constructor_season (
    constructor_id INTEGER NOT NULL,
    season_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    nationality TEXT NOT NULL,
    country_code TEXT,
    constructor_base_id INTEGER,
    PRIMARY KEY (constructor_id, season_id),
    FOREIGN KEY (constructor_id) REFERENCES constructor(id),
    FOREIGN KEY (season_id) REFERENCES season(id)
);

CREATE TABLE IF NOT EXISTS constructor_engine (
    constructor_id INTEGER NOT NULL,
    season_id INTEGER NOT NULL,
    engine_id INTEGER NOT NULL,
    engine_ref_override TEXT,
    PRIMARY KEY (constructor_id, season_id),
    FOREIGN KEY (constructor_id) REFERENCES constructor(id),
    FOREIGN KEY (season_id) REFERENCES season(id),
    FOREIGN KEY (engine_id) REFERENCES engine(id)
);

-- ============================================================
-- PART 5: CREATE EVENT & RESULTS TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS round (
    id INTEGER PRIMARY KEY,
    season_id INTEGER NOT NULL,
    circuit_id INTEGER NOT NULL,
    number INTEGER NOT NULL,
    name TEXT NOT NULL,
    date TEXT,
    is_cancelled INTEGER DEFAULT 0,
    wikipedia TEXT,
    FOREIGN KEY (season_id) REFERENCES season(id),
    FOREIGN KEY (circuit_id) REFERENCES circuit(id),
    UNIQUE(season_id, number)
);

CREATE TABLE IF NOT EXISTS constructor_driver (
    id INTEGER PRIMARY KEY,
    season_id INTEGER NOT NULL,
    constructor_id INTEGER NOT NULL,
    driver_id INTEGER NOT NULL,
    role TEXT,
    FOREIGN KEY (season_id) REFERENCES season(id),
    FOREIGN KEY (constructor_id) REFERENCES constructor(id),
    FOREIGN KEY (driver_id) REFERENCES driver(id),
    UNIQUE(season_id, constructor_id, driver_id, role)
);

CREATE TABLE IF NOT EXISTS round_entry (
    id INTEGER PRIMARY KEY,
    round_id INTEGER NOT NULL,
    constructor_driver_id INTEGER NOT NULL,
    car_number INTEGER,
    FOREIGN KEY (round_id) REFERENCES round(id),
    FOREIGN KEY (constructor_driver_id) REFERENCES constructor_driver(id)
);

CREATE TABLE IF NOT EXISTS session (
    id INTEGER PRIMARY KEY,
    round_id INTEGER NOT NULL,
    type TEXT NOT NULL,
    number INTEGER,
    timestamp TEXT,
    timezone TEXT,
    scheduled_laps INTEGER,
    point_system_id INTEGER,
    is_cancelled INTEGER DEFAULT 0,
    has_time_data INTEGER,
    FOREIGN KEY (round_id) REFERENCES round(id)
);

CREATE TABLE IF NOT EXISTS session_entry (
    id INTEGER PRIMARY KEY,
    session_id INTEGER NOT NULL,
    round_entry_id INTEGER NOT NULL,
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
    FOREIGN KEY (session_id) REFERENCES session(id),
    FOREIGN KEY (round_entry_id) REFERENCES round_entry(id)
);

-- ============================================================
-- PART 6: CREATE CHAMPIONSHIP TRACKING TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS driver_championship (
    id INTEGER PRIMARY KEY,
    season_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    driver_id INTEGER NOT NULL,
    round_id INTEGER NOT NULL,
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
    UNIQUE(season_id, round_id, driver_id)
);

CREATE TABLE IF NOT EXISTS constructor_championship (
    id INTEGER PRIMARY KEY,
    season_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    constructor_id INTEGER NOT NULL,
    round_id INTEGER NOT NULL,
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
    FOREIGN KEY (constructor_id) REFERENCES constructor(id),
    FOREIGN KEY (round_id) REFERENCES round(id),
    UNIQUE(season_id, round_id, constructor_id)
);

-- ============================================================
-- PART 7: CREATE DETAIL DATA TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS lap (
    id INTEGER PRIMARY KEY,
    session_entry_id INTEGER NOT NULL,
    number INTEGER NOT NULL,
    position INTEGER,
    time TEXT,
    average_speed TEXT,
    is_fastest_lap INTEGER,
    is_deleted INTEGER DEFAULT 0,
    FOREIGN KEY (session_entry_id) REFERENCES session_entry(id)
);

CREATE TABLE IF NOT EXISTS pit_stop (
    id INTEGER PRIMARY KEY,
    session_entry_id INTEGER NOT NULL,
    lap_id INTEGER,
    number INTEGER,
    duration TEXT,
    local_timestamp TEXT,
    FOREIGN KEY (session_entry_id) REFERENCES session_entry(id),
    FOREIGN KEY (lap_id) REFERENCES lap(id)
);

CREATE TABLE IF NOT EXISTS penalty (
    id INTEGER PRIMARY KEY,
    earned_session_entry_id INTEGER,
    served_session_entry_id INTEGER,
    position INTEGER,
    license_points INTEGER,
    is_time_served_in_pit INTEGER,
    time TEXT,
    FOREIGN KEY (earned_session_entry_id) REFERENCES session_entry(id),
    FOREIGN KEY (served_session_entry_id) REFERENCES session_entry(id)
);

-- ============================================================
-- PART 8: CREATE LOOKUP TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS countries (
    id INTEGER PRIMARY KEY,
    country_code TEXT UNIQUE NOT NULL,
    country TEXT,
    iso_alpha3 TEXT,
    continent TEXT
);

-- ============================================================
-- PART 9: COPY DATA FROM JOLPICA (ATTACHED DATABASE)
-- ============================================================

-- Migrate Season (no api_id)
INSERT INTO season (id, year, championship_system_id, wikipedia)
SELECT id, year, championship_system_id, wikipedia FROM jolpica.season;

-- Migrate Circuit (no api_id)
INSERT INTO circuit (id, name, reference, locality, country, country_code,
                        latitude, longitude, altitude, wikipedia)
SELECT id, name, reference, locality, country, country_code,
       latitude, longitude, altitude, wikipedia FROM jolpica.circuit;

-- Driver — source table has 'nationality', not 'country'. Map to birth_country.
INSERT INTO driver (id, reference, abbreviation, forename, surname,
                       permanent_car_number, date_of_birth, birth_country, wikipedia)
SELECT id, reference, abbreviation, forename, surname,
       permanent_car_number, date_of_birth, nationality, wikipedia FROM jolpica.driver;

-- Migrate Constructor (renamed from team, no api_id)
INSERT INTO constructor (id, name, reference, constructor_base_id, primary_color, wikipedia)
SELECT id, name, reference, base_team_id, primary_color, wikipedia FROM jolpica.team;

-- Round — NULL 'number' fallback using ROW_NUMBER() per season ordered by date.
INSERT INTO round (id, season_id, circuit_id, number, name, date, is_cancelled, wikipedia)
SELECT r.id, r.season_id, r.circuit_id,
       CASE
         WHEN r.number IS NOT NULL THEN r.number
         ELSE (SELECT COALESCE(MAX(r2.number), 0) FROM jolpica.round r2 WHERE r2.season_id = r.season_id)
              + ROW_NUMBER() OVER (PARTITION BY r.season_id ORDER BY r.date, r.id)
       END AS number,
       COALESCE(r.name, 'Unknown round'),
       r.date,
       COALESCE(r.is_cancelled, 0),
       r.wikipedia
FROM jolpica.round r;

-- Migrate Constructor Driver (renamed from team_driver, no api_id)
INSERT INTO constructor_driver (id, season_id, constructor_id, driver_id, role)
SELECT id, season_id, team_id, driver_id, role FROM jolpica.team_driver;

-- Migrate Round Entry (rename FK, no api_id)
INSERT INTO round_entry (id, round_id, constructor_driver_id, car_number)
SELECT id, round_id, team_driver_id, car_number FROM jolpica.roundentry;

-- Migrate Session (no api_id)
INSERT INTO session (id, round_id, type, number, timestamp, timezone,
                        scheduled_laps, point_system_id, is_cancelled, has_time_data)
SELECT id, round_id, type, number, timestamp, timezone,
       scheduled_laps, point_system_id, is_cancelled, has_time_data FROM jolpica.session;

-- Migrate Session Entry (no api_id)
INSERT INTO session_entry (id, session_id, round_entry_id, grid, position,
                              points, laps_completed, fastest_lap_rank, time,
                              detail, status, is_classified, is_eligible_for_points)
SELECT id, session_id, round_entry_id, grid, position, points,
       laps_completed, fastest_lap_rank, time, detail, status,
       is_classified, is_eligible_for_points FROM jolpica.session_entry;

-- Driver Championship — derive season_id from year when NULL; skip NULL round_id.
INSERT INTO driver_championship (id, season_id, year, driver_id, round_id, position,
                                     points, win_count, highest_finish, is_eligible,
                                     adjustment_type, session_id, session_number, round_number)
SELECT dc.id,
       COALESCE(dc.season_id, (SELECT s.id FROM jolpica.season s WHERE s.year = dc.year)),
       dc.year, dc.driver_id, dc.round_id, dc.position, dc.points,
       dc.win_count, dc.highest_finish, dc.is_eligible, dc.adjustment_type,
       dc.session_id, dc.session_number, dc.round_number
FROM jolpica.driver_championship dc
WHERE dc.round_id IS NOT NULL
  AND COALESCE(dc.season_id, (SELECT s.id FROM jolpica.season s WHERE s.year = dc.year)) IS NOT NULL;

-- Constructor Championship — derive season_id from year when NULL; skip NULL round_id.
INSERT INTO constructor_championship (id, season_id, year, constructor_id, round_id, position,
                                          points, win_count, highest_finish, is_eligible,
                                          adjustment_type, session_id, session_number, round_number)
SELECT tc.id,
       COALESCE(tc.season_id, (SELECT s.id FROM jolpica.season s WHERE s.year = tc.year)),
       tc.year, tc.team_id, tc.round_id, tc.position, tc.points,
       tc.win_count, tc.highest_finish, tc.is_eligible, tc.adjustment_type,
       tc.session_id, tc.session_number, tc.round_number
FROM jolpica.team_championship tc
WHERE tc.round_id IS NOT NULL
  AND COALESCE(tc.season_id, (SELECT s.id FROM jolpica.season s WHERE s.year = tc.year)) IS NOT NULL;

-- Lap — NULL 'number' fallback using ROW_NUMBER() per session_entry ordered by id.
INSERT INTO lap (id, session_entry_id, number, position, time, average_speed,
                    is_fastest_lap, is_deleted)
SELECT l.id, l.session_entry_id,
       CASE
         WHEN l.number IS NOT NULL THEN l.number
         ELSE (SELECT COALESCE(MAX(l2.number), 0) FROM jolpica.lap l2 WHERE l2.session_entry_id = l.session_entry_id)
              + ROW_NUMBER() OVER (PARTITION BY l.session_entry_id ORDER BY l.id)
       END AS number,
       l.position, l.time, l.average_speed,
       l.is_entry_fastest_lap, l.is_deleted
FROM jolpica.lap l;

-- Migrate Pit Stop (no api_id)
INSERT INTO pit_stop (id, session_entry_id, lap_id, number, duration, local_timestamp)
SELECT id, session_entry_id, lap_id, number, duration, local_timestamp FROM jolpica.pit_stop;

-- Migrate Penalty (no api_id)
INSERT INTO penalty (id, earned_session_entry_id, served_session_entry_id,
                        position, license_points, is_time_served_in_pit, time)
SELECT id, earned_id, served_id, position, license_points,
       is_time_served_in_pit, time FROM jolpica.penalty;

-- Countries Lookup — source table only has (country_code, country).
-- Use rowid as surrogate PK; iso_alpha3 and continent don't exist in source,
-- so insert NULL for those columns (enrich later if desired).
INSERT INTO countries (id, country_code, country, iso_alpha3, continent)
SELECT rowid, country_code, country, NULL, NULL
FROM jolpica._countries_lookup;

-- Migrate Base Team → constructor_base (renamed for consistency)
INSERT INTO constructor_base (id, name, api_id)
SELECT id, name, api_id FROM jolpica.base_team;

-- Migrate Points System
INSERT INTO points_system (id, name, reference, partial, driver_position_points,
                           driver_fastest_lap, team_position_points, team_fastest_lap,
                           shared_drive, is_double_points, api_id)
SELECT id, name, reference, partial, driver_position_points,
       driver_fastest_lap, team_position_points, team_fastest_lap,
       shared_drive, is_double_points, api_id FROM jolpica.points_system;

-- Migrate Championship System
INSERT INTO championship_system (id, name, reference, driver_best_results,
                                  team_best_results, driver_season_split,
                                  team_season_split, team_points_per_session,
                                  eligibility, api_id)
SELECT id, name, reference, driver_best_results, team_best_results,
       driver_season_split, team_season_split, team_points_per_session,
       eligibility, api_id FROM jolpica.championship_system;

-- ============================================================
-- PART 10: CREATE YEAR-GRAIN ATTRIBUTE TABLES FROM EXISTING DATA
-- ============================================================

-- Driver Nationality Per Season — COALESCE NULL nationality to 'Unknown'.
INSERT INTO driver_season (driver_id, season_id, nationality, country_code)
SELECT td.driver_id, td.season_id,
       COALESCE(d.nationality, 'Unknown') AS nationality,
       d.country_code
FROM jolpica.team_driver td
JOIN jolpica.driver d ON td.driver_id = d.id
GROUP BY td.driver_id, td.season_id;

-- Constructor Season — COALESCE NULL nationality and name to 'Unknown'.
INSERT INTO constructor_season (constructor_id, season_id, name, nationality, country_code, constructor_base_id)
SELECT td.team_id, td.season_id,
       COALESCE(t.name, 'Unknown') AS name,
       COALESCE(t.nationality, 'Unknown') AS nationality,
       t.country_code, t.base_team_id
FROM jolpica.team_driver td
JOIN jolpica.team t ON td.team_id = t.id
GROUP BY td.team_id, td.season_id;

-- ============================================================
-- PART 11: POPULATE ENGINE TABLE
-- ============================================================

INSERT INTO engine (id, name, reference, nationality, founded_year, wikipedia) VALUES
(1, 'Ferrari', 'ferrari', 'Italian', 1929, 'https://en.wikipedia.org/wiki/Scuderia_Ferrari'),
(2, 'Mercedes', 'mercedes', 'German', 1926, 'https://en.wikipedia.org/wiki/Mercedes-Benz_in_Formula_One'),
(3, 'Renault', 'renault', 'French', 1977, 'https://en.wikipedia.org/wiki/Renault_in_Formula_One'),
(4, 'Honda', 'honda', 'Japanese', 1964, 'https://en.wikipedia.org/wiki/Honda_Racing_F1'),
(5, 'Cosworth', 'cosworth', 'British', 1958, 'https://en.wikipedia.org/wiki/Cosworth'),
(6, 'BMW', 'bmw', 'German', 1961, 'https://en.wikipedia.org/wiki/BMW_in_Formula_One'),
(7, 'Toyota', 'toyota', 'Japanese', 2002, 'https://en.wikipedia.org/wiki/Toyota_Racing'),
(8, 'BRM', 'brm', 'British', 1945, 'https://en.wikipedia.org/wiki/British_Racing_Motors'),
(9, 'Red Bull Powertrains', 'red_bull_powertrains', 'British', 2021, 'https://en.wikipedia.org/wiki/Red_Bull_Powertrains'),
(10, 'Alpine', 'alpine', 'French', 2021, 'https://en.wikipedia.org/wiki/Alpine_Renault_F1_Team'),
(11, 'Maserati', 'maserati', 'Italian', 1940, 'https://en.wikipedia.org/wiki/Maserati_in_Formula_One'),
(12, 'Repco', 'repco', 'Australian', 1966, 'https://en.wikipedia.org/wiki/Repco'),
(13, 'Climax', 'climax', 'British', 1952, 'https://en.wikipedia.org/wiki/Cosworth_Climax'),
(14, 'Judd', 'judd', 'British', 1983, 'https://en.wikipedia.org/wiki/Judd_(engine)'),
(15, 'Ilmor', 'ilmor', 'British', 1983, 'https://en.wikipedia.org/wiki/Ilmor'),
(16, 'TAG', 'tag', 'Luxembourgish', 1979, 'https://en.wikipedia.org/wiki/Techniques_d%27Avant_Garde'),
(17, 'Porsche', 'porsche', 'German', 1931, 'https://en.wikipedia.org/wiki/Porsche_in_Formula_One'),
(18, 'Ford', 'ford', 'American', 1962, 'https://en.wikipedia.org/wiki/Cosworth_DFV');

-- Resolve season_id via year join (was using calendar years as season IDs, breaking FK relationship)
INSERT INTO constructor_engine (constructor_id, season_id, engine_id, engine_ref_override)
SELECT c.id, s.id, e.id, NULL
FROM (
    SELECT 'ferrari'  AS constructor_ref, 'ferrari'  AS engine_ref, 2005 AS first_year, 2025 AS last_year
    UNION ALL
    SELECT 'mercedes', 'mercedes', 2010, 2025
) AS m
JOIN constructor c ON c.reference = m.constructor_ref
JOIN engine      e ON e.reference = m.engine_ref
JOIN season      s ON s.year BETWEEN m.first_year AND m.last_year;

-- ============================================================
-- PART 12: CREATE INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_round_season ON round(season_id);
CREATE INDEX IF NOT EXISTS idx_round_circuit ON round(circuit_id);
CREATE INDEX IF NOT EXISTS idx_session_round ON session(round_id);
CREATE INDEX IF NOT EXISTS idx_session_type ON session(type);
CREATE INDEX IF NOT EXISTS idx_session_entry_session ON session_entry(session_id);
CREATE INDEX IF NOT EXISTS idx_session_entry_position ON session_entry(position);
CREATE INDEX IF NOT EXISTS idx_driver_season_driver ON driver_season(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_season_year ON driver_season(season_id);
CREATE INDEX IF NOT EXISTS idx_constructor_season_constructor ON constructor_season(constructor_id);
CREATE INDEX IF NOT EXISTS idx_constructor_season_year ON constructor_season(season_id);
CREATE INDEX IF NOT EXISTS idx_constructor_engine_constructor ON constructor_engine(constructor_id);
CREATE INDEX IF NOT EXISTS idx_constructor_driver_season ON constructor_driver(season_id);
CREATE INDEX IF NOT EXISTS idx_constructor_driver_driver ON constructor_driver(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_champ_driver ON driver_championship(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_champ_season ON driver_championship(season_id);
CREATE INDEX IF NOT EXISTS idx_constructor_champ_constructor ON constructor_championship(constructor_id);
CREATE INDEX IF NOT EXISTS idx_lap_session_entry ON lap(session_entry_id, number);
CREATE INDEX IF NOT EXISTS idx_pitstop_session_entry ON pit_stop(session_entry_id);
CREATE INDEX IF NOT EXISTS idx_points_system_id ON points_system(id);
CREATE INDEX IF NOT EXISTS idx_championship_system_id ON championship_system(id);

-- ============================================================
-- PART 14: DETACH SOURCE
-- ============================================================

DETACH DATABASE jolpica;

-- ============================================================
-- PART 15: FINAL CLEANUP
-- ============================================================

VACUUM;
