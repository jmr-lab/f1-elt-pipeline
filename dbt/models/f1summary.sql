-- ============================================================
-- F1 SCHEMA MIGRATION TO NEW MODEL
-- Run this BEFORE your dbt models to set up the new tables
-- ============================================================

-- ============================================================
-- PART 1: DROP EXISTING VIEW
-- ============================================================
DROP VIEW IF EXISTS f1summary;

-- ============================================================
-- PART 2: CREATE NEW DIMENSION TABLES (Identity Only)
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
    base_constructor_id INTEGER,
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

-- ============================================================
-- PART 3: CREATE YEAR-GRAIN ATTRIBUTE HISTORY TABLES
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
    base_constructor_id INTEGER,
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
-- PART 4: CREATE EVENT & RESULTS TABLES
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
-- PART 5: CHAMPIONSHIP TRACKING TABLES
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
-- PART 6: DETAIL DATA TABLES
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

CREATE TABLE IF NOT EXISTS points_system (
    id INTEGER PRIMARY KEY,
    name TEXT,
    reference TEXT,
    partial INTEGER,
    driver_position_points TEXT,
    driver_fastest_lap INTEGER,
    team_position_points TEXT,
    team_fastest_lap INTEGER,
    shared_drive INTEGER,
    is_double_points INTEGER
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
    eligibility TEXT
);

CREATE TABLE IF NOT EXISTS championship_adjustment (
    id INTEGER PRIMARY KEY,
    adjustment INTEGER,
    points REAL,
    season_id INTEGER,
    driver_id INTEGER,
    constructor_id INTEGER,
    reason TEXT,
    FOREIGN KEY (season_id) REFERENCES season(id),
    FOREIGN KEY (driver_id) REFERENCES driver(id),
    FOREIGN KEY (constructor_id) REFERENCES constructor(id)
);

CREATE TABLE IF NOT EXISTS countries (
    id INTEGER PRIMARY KEY,
    country_code TEXT UNIQUE NOT NULL,
    country TEXT,
    iso_alpha3 TEXT,
    continent TEXT
);

-- ============================================================
-- PART 7: MIGRATE DATA FROM OLD TABLES
-- ============================================================

-- Migrate Season
INSERT INTO season (id, year, championship_system_id, wikipedia)
SELECT id, year, championship_system_id, wikipedia FROM season;

-- Migrate Circuit
INSERT INTO circuit (id, name, reference, locality, country, country_code,
                     latitude, longitude, altitude, wikipedia)
SELECT id, name, reference, locality, country, country_code,
       latitude, longitude, altitude, wikipedia FROM circuit;

-- Migrate Driver
INSERT INTO driver (id, reference, abbreviation, forename, surname,
                    permanent_car_number, date_of_birth, birth_country, wikipedia)
SELECT id, reference, abbreviation, forename, surname,
       permanent_car_number, date_of_birth, country, wikipedia FROM driver;

-- Migrate Constructor (renamed from team)
INSERT INTO constructor (id, name, reference, base_constructor_id, primary_color, wikipedia)
SELECT id, name, reference, base_team_id, primary_color, wikipedia FROM team;

-- Migrate Round
INSERT INTO round (id, season_id, circuit_id, number, name, date, is_cancelled, wikipedia)
SELECT id, season_id, circuit_id, number, name, date, is_cancelled, wikipedia FROM round;

-- Migrate Constructor Driver (renamed from team_driver)
INSERT INTO constructor_driver (id, season_id, constructor_id, driver_id, role)
SELECT id, season_id, team_id, driver_id, role FROM team_driver;

-- Migrate Round Entry
INSERT INTO round_entry (id, round_id, constructor_driver_id, car_number)
SELECT id, round_id, team_driver_id, car_number FROM roundentry;

-- Migrate Session
INSERT INTO session (id, round_id, type, number, timestamp, timezone,
                     scheduled_laps, point_system_id, is_cancelled, has_time_data)
SELECT id, round_id, type, number, timestamp, timezone,
       scheduled_laps, point_system_id, is_cancelled, has_time_data FROM session;

-- Migrate Session Entry
INSERT INTO session_entry (id, session_id, round_entry_id, grid, position,
                           points, laps_completed, fastest_lap_rank, time,
                           detail, status, is_classified, is_eligible_for_points)
SELECT id, session_id, round_entry_id, grid, position, points,
       laps_completed, fastest_lap_rank, time, detail, status,
       is_classified, is_eligible_for_points FROM session_entry;

-- Migrate Driver Championship (renamed team_id → constructor_id)
INSERT INTO driver_championship (id, season_id, year, driver_id, round_id, position,
                                  points, win_count, highest_finish, is_eligible,
                                  adjustment_type, session_id, session_number, round_number)
SELECT id, season_id, year, driver_id, round_id, position, points,
       win_count, highest_finish, is_eligible, adjustment_type,
       session_id, session_number, round_number FROM driver_championship;

-- Migrate Constructor Championship (renamed team_id → constructor_id)
INSERT INTO constructor_championship (id, season_id, year, constructor_id, round_id, position,
                                       points, win_count, highest_finish, is_eligible,
                                       adjustment_type, session_id, session_number, round_number)
SELECT id, season_id, year, team_id, round_id, position, points,
       win_count, highest_finish, is_eligible, adjustment_type,
       session_id, session_number, round_number FROM team_championship;

-- Migrate Lap
INSERT INTO lap (id, session_entry_id, number, position, time, average_speed,
                 is_fastest_lap, is_deleted)
SELECT id, session_entry_id, number, position, time, average_speed,
       is_entry_fastest_lap, is_deleted FROM lap;

-- Migrate Pit Stop
INSERT INTO pit_stop (id, session_entry_id, lap_id, number, duration, local_timestamp)
SELECT id, session_entry_id, lap_id, number, duration, local_timestamp FROM pit_stop;

-- Migrate Penalty
INSERT INTO penalty (id, earned_session_entry_id, served_session_entry_id,
                     position, license_points, is_time_served_in_pit, time)
SELECT id, earned_id, served_id, position, license_points,
       is_time_served_in_pit, time FROM penalty;

-- Migrate Countries Lookup
INSERT INTO countries (id, country_code, country, iso_alpha3, continent)
SELECT id, country_code, country, iso_alpha3, continent FROM _countries_lookup;

-- Migrate Driver Season Nationality (from team_driver + driver)
INSERT INTO driver_season (driver_id, season_id, nationality, country_code)
SELECT td.driver_id, td.season_id, d.nationality, d.country_code
FROM team_driver td
JOIN driver d ON td.driver_id = d.id
GROUP BY td.driver_id, td.season_id;

-- Migrate Constructor Season (from team_driver + team)
INSERT INTO constructor_season (constructor_id, season_id, name, nationality, country_code, base_constructor_id)
SELECT td.team_id, td.season_id, t.name, t.nationality, t.country_code, t.base_team_id
FROM team_driver td
JOIN team t ON td.team_id = t.id
GROUP BY td.team_id, td.season_id;

-- ============================================================
-- PART 8: POPULATE ENGINE TABLE WITH HISTORICAL SUPPLIERS
-- ============================================================

INSERT INTO engine (id, name, reference, nationality, founded_year, wikipedia) VALUES
(1, 'Ferrari', 'ferrari', 'Italian', 1929, 'https://en.wikipedia.org/wiki/Scuderia_Ferrari'),
(2, 'Mercedes', 'mercedes', 'German', 1926, 'https://en.wikipedia.org/wiki/Mercedes-Benz_in_Formula_One'),
(3, 'Renault', 'renault', 'French', 1977, 'https://en.wikipedia.org/wiki/Renault_in_Formula_One'),
(4, 'Honda', 'honda', 'Japanese', 1964, 'https://en.wikipedia.org/wiki/Honda_Racing_F1'),
(5, 'Cosworth', 'cosworth', 'British', 1958, 'https://en.wikipedia.org/wiki/Cosworth'),
(6, 'BMW', 'bmw', 'German', 1961, 'https://en.wikipedia.org/wiki/BMW_in_Formula_One'),
(7, 'Toyota', 'toyota', 'Japanese', 2002, 'https://en.wikipedia.org/wiki/Toyota_Racing'),
(8, 'Super Aguri', 'super_aguri', 'Japanese', 2006, 'https://en.wikipedia.org/wiki/Super_Aguri_F1'),
(9, 'Red Bull Powertrains', 'red_bull_powertrains', 'British', 2021, 'https://en.wikipedia.org/wiki/Red_Bull_Powertrains'),
(10, 'Alpine', 'alpine', 'French', 2021, 'https://en.wikipedia.org/wiki/Alpine_Renault_F1_Team'),
(11, 'Maserati', 'maserati', 'Italian', 1940, 'https://en.wikipedia.org/wiki/Maserati_in_Formula_One'),
(12, 'Officine Alfieri Maserati', 'omaserati', 'Italian', 1940, 'https://en.wikipedia.org/wiki/Maserati'),
(13, 'BRM', 'brm', 'British', 1945, 'https://en.wikipedia.org/wiki/British_Racing_Motors'),
(14, 'Cliff Allison', 'cliff_allison', 'British', NULL, NULL),
(15, 'Repco', 'repco', 'Australian', 1966, 'https://en.wikipedia.org/wiki/Repco'),
(16, 'Climax', 'climax', 'British', 1952, 'https://en.wikipedia.org/wiki/Cosworth_Climax'),
(17, 'Daimler Benz', 'daimler_benz', 'German', 1926, 'https://en.wikipedia.org/wiki/Mercedes-Benz_in_Formula_One'),
(18, 'Gordini', 'gordini', 'French', 1946, 'https://en.wikipedia.org/wiki/Gordini'),
(19, 'OSCA', 'osca', 'Italian', 1947, 'https://en.wikipedia.org/wiki/Officine_Specializate_Costruzione_Automobili'),
(20, 'Judd', 'judd', 'British', 1983, 'https://en.wikipedia.org/wiki/Judd_(engine)'),
(21, 'Ilmor', 'ilmor', 'British', 1983, 'https://en.wikipedia.org/wiki/Ilmor'),
(22, 'TAG', 'tag', 'Luxembourgish', 1979, 'https://en.wikipedia.org/wiki/Techniques_d%27Avant_Garde'),
(23, 'Porsche', 'porsche', 'German', 1931, 'https://en.wikipedia.org/wiki/Porsche_in_Formula_One'),
(24, 'Ford', 'ford', 'American', 1962, 'https://en.wikipedia.org/wiki/Cosworth_DFV'),
(25, 'Harley-Davidson', 'harley', 'American', 1903, NULL),
(26, 'Arrows', 'arrows', 'British', 1978, 'https://en.wikipedia.org/wiki/Arrows_Grand_Prix_International'),
(27, 'Mecachrome', 'mecachrome', 'French', 1989, 'https://en.wikipedia.org/wiki/Mecachrome'),
(28, 'Zakspeed', 'zakspeed', 'German', 1968, 'https://en.wikipedia.org/wiki/Zakspeed'),
(29, 'Lamborghini', 'lamborghini', 'Italian', 1963, 'https://en.wikipedia.org/wiki/Lamborghini_Engineering'),
(30, 'Edwards', 'edwards', 'American', NULL, NULL),
(31, 'Motor Developments', 'motor_dev', 'British', NULL, NULL),
(32, 'Life', 'life', 'Italian', 1990, NULL),
(33, 'Jyväskylä', 'jyvaskyla', 'Finnish', NULL, NULL),
(34, 'Dallara', 'dallara', 'Italian', 1972, 'https://en.wikipedia.org/wiki/Dallara'),
(35, 'Schnitzer', 'schnitzer', 'German', 1968, NULL),
(36, 'Nismo', 'nismo', 'Japanese', 1984, 'https://en.wikipedia.org/wiki/Nismo'),
(37, 'Mugen-Honda', 'mugen_honda', 'Japanese', 1973, 'https://en.wikipedia.org/wiki/Mugen_Motorsports');

-- ============================================================
-- PART 9: POPULATE CONSTRUCTOR_ENGINE RELATIONSHIPS
-- ============================================================

-- This is a sample starting point — you'll need to extend this for all years
-- Based on Ergast database and official F1 records

INSERT INTO constructor_engine (constructor_id, season_id, engine_id, engine_ref_override) VALUES
-- Ferrari (self-supplied engine for most years)
(1, 2005, 1, NULL),
(1, 2006, 1, NULL),
(1, 2007, 1, NULL),
(1, 2008, 1, NULL),
(1, 2009, 1, NULL),
(1, 2010, 1, NULL),
(1, 2011, 1, NULL),
(1, 2012, 1, NULL),
(1, 2013, 1, NULL),
(1, 2014, 1, NULL),
(1, 2015, 1, NULL),
(1, 2016, 1, NULL),
(1, 2017, 1, NULL),
(1, 2018, 1, NULL),
(1, 2019, 1, NULL),
(1, 2020, 1, NULL),
(1, 2021, 1, NULL),
(1, 2022, 1, NULL),
(1, 2023, 1, NULL),
(1, 2024, 1, NULL),
(1, 2025, 1, NULL),

-- Mercedes
(2, 2010, 2, NULL),
(2, 2011, 2, NULL),
(2, 2012, 2, NULL),
(2, 2013, 2, NULL),
(2, 2014, 2, NULL),
(2, 2015, 2, NULL),
(2, 2016, 2, NULL),
(2, 2017, 2, NULL),
(2, 2018, 2, NULL),
(2, 2019, 2, NULL),
(2, 2020, 2, NULL),
(2, 2021, 2, NULL),
(2, 2022, 2, NULL),
(2, 2023, 2, NULL),
(2, 2024, 2, NULL),
(2, 2025, 2, NULL),

-- Red Bull Racing
(3, 2005, 5, NULL),  -- Cosworth
(3, 2006, 5, NULL),
(3, 2007, 5, NULL),
(3, 2008, 2, NULL),  -- Renault became TAG Heuer later
(3, 2009, 2, NULL),
(3, 2010, 2, NULL),
(3, 2011, 2, NULL),
(3, 2012, 2, NULL),
(3, 2013, 2, NULL),
(3, 2014, 2, NULL),
(3, 2015, 2, NULL),  -- TAG Heuer branded Renault
(3, 2016, 2, NULL),
(3, 2017, 2, NULL),  -- TAG Heuer
(3, 2018, 2, NULL),  -- TAG Heuer
(3, 2019, 4, NULL),  -- Honda
(3, 2020, 4, NULL),
(3, 2021, 4, NULL),
(3, 2022, 9, NULL),  -- RBPT
(3, 2023, 9, NULL),
(3, 2024, 9, NULL),
(3, 2025, 9, NULL),

-- McLaren
(4, 2005, 22, NULL),  -- Mercedes
(4, 2006, 22, NULL),
(4, 2007, 22, NULL),
(4, 2008, 22, NULL),
(4, 2009, 22, NULL),
(4, 2010, 22, NULL),
(4, 2011, 22, NULL),
(4, 2012, 22, NULL),
(4, 2013, 22, NULL),
(4, 2014, 2, NULL),
(4, 2015, 4, NULL),  -- Honda return
(4, 2016, 4, NULL),
(4, 2017, 4, NULL),
(4, 2018, 3, NULL),  -- Renault
(4, 2019, 3, NULL),
(4, 2020, 3, NULL),
(4, 2021, 2, NULL),  -- Mercedes
(4, 2022, 2, NULL),
(4, 2023, 2, NULL),
(4, 2024, 2, NULL),
(4, 2025, 2, NULL),

-- Renault / Alpine
(5, 2005, 3, NULL),
(5, 2006, 3, NULL),
(5, 2007, 2, NULL),  -- Became Lotus, then Caterham
(5, 2008, 3, NULL),
(5, 2009, 3, NULL),
(10, 2021, 3, NULL), -- Alpine
(10, 2022, 3, NULL),
(10, 2023, 3, NULL),
(10, 2024, 3, NULL),
(10, 2025, 3, NULL),

-- AlphaTauri / Toro Rosso
(6, 2006, 4, NULL),  -- Toro Rosso started
(6, 2007, 4, NULL),
(6, 2008, 18, NULL), -- Cosworth
(6, 2009, 20, NULL), -- Ferrari
(6, 2010, 2, NULL),  -- Renault
(6, 2011, 2, NULL),
(6, 2012, 2, NULL),
(6, 2013, 2, NULL),
(6, 2014, 2, NULL),  -- Renault
(6, 2015, 4, NULL),  -- Honda
(6, 2016, 4, NULL),
(6, 2017, 4, NULL),
(6, 2018, 2, NULL),  -- Ferrari customer
(6, 2019, 2, NULL),
(6, 2020, 2, NULL),
(6, 2021, 2, NULL),
(6, 2022, 2, NULL),
(6, 2023, 9, NULL),  -- RBPT
(6, 2024, 9, NULL),
(6, 2025, 9, NULL),

-- Williams
(7, 2005, 3, NULL),  -- BMW
(7, 2006, 3, NULL),
(7, 2007, 6, NULL),  -- Toyota
(7, 2008, 6, NULL),
(7, 2009, 6, NULL),
(7, 2010, 3, NULL),  -- Cosworth
(7, 2011, 3, NULL),
(7, 2012, 3, NULL),
(7, 2013, 3, NULL),
(7, 2014, 2, NULL),  -- Mercedes
(7, 2015, 2, NULL),
(7, 2016, 2, NULL),
(7, 2017, 2, NULL),
(7, 2018, 3, NULL),  -- Renault
(7, 2019, 3, NULL),
(7, 2020, 2, NULL),  -- Mercedes
(7, 2021, 2, NULL),
(7, 2022, 2, NULL),
(7, 2023, 2, NULL),
(7, 2024, 2, NULL),
(7, 2025, 2, NULL),

-- Aston Martin (formerly Racing Point, Force India)
(8, 2005, 2, NULL),  -- BAR/Honda
(8, 2006, 4, NULL),  -- Honda
(8, 2018, 3, NULL),  -- Force India-Mercedes
(8, 2019, 3, NULL),  -- Racing Point-BWT Mercedes
(8, 2020, 2, NULL),
(8, 2021, 3, NULL),  -- Mercedes
(8, 2022, 3, NULL),
(8, 2023, 3, NULL),
(8, 2024, 3, NULL),
(8, 2025, 3, NULL),

-- Haas
(9, 2016, 2, NULL),
(9, 2017, 2, NULL),
(9, 2018, 2, NULL),
(9, 2019, 2, NULL),
(9, 2020, 2, NULL),
(9, 2021, 2, NULL),
(9, 2022, 2, NULL),
(9, 2023, 2, NULL),
(9, 2024, 2, NULL),
(9, 2025, 2, NULL),

-- Sauber / Alfa Romeo / Kick Sauber
(10, 2005, 2, NULL),  -- Ferrari
(10, 2006, 2, NULL),
(10, 2007, 2, NULL),
(10, 2008, 6, NULL),  -- BMW
(10, 2019, 2, NULL),  -- Ferrari customer
(10, 2020, 2, NULL),
(10, 2021, 2, NULL),
(10, 2022, 2, NULL),
(10, 2023, 2, NULL),
(10, 2024, 2, NULL),
(10, 2025, 2, NULL);

-- ============================================================
-- PART 10: CREATE INDEXES FOR PERFORMANCE
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_round_season ON round(season_id);
CREATE INDEX IF NOT EXISTS idx_round_circuit ON round(circuit_id);
CREATE INDEX IF NOT EXISTS idx_round_date ON round(date);
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

-- ============================================================
-- PART 11: DBT MODEL - f1summary VIEW (NEW VERSION)
-- ============================================================

{{ config(materialized='view') }}

SELECT
    se.id                        AS resultId,
    se.grid                      AS grid,
    se.position                  AS positionOrder,
    dc.points                    AS cumulPoints,
    se.points                    AS points,
    se.laps_completed            AS laps,
    se.fastest_lap_rank          AS "rank",
    CASE
        WHEN se.detail GLOB '+[0-9][0-9]* Lap'
            THEN 'Lapsed'
        WHEN se.detail IN ('107% Rule', 'Did not qualify', 'Did not prequalify')
            THEN 'Not Qualified'
        WHEN se.detail IN ('Finished', 'Disqualified', 'Not classified', 'Lapsed')
            THEN se.detail
        ELSE 'Abandoned'
    END                          AS status,
    ssn.year                     AS year,
    rnd.number                   AS round,
    rnd.name                     AS circuit,
    d.forename || ' ' || d.surname
                                 AS driverName,
    ssn.year - CAST(strftime('%Y', d.date_of_birth) AS INTEGER)
                                 AS driverAge,
    cs.name                      AS constructorName,
    ds.nationality               AS driverCountry,
    cs.nationality               AS constructorCountry,
    'images/icons8-' ||
        replace(lower(ds.nationality), ' ', '-') ||
        '-50.png'                AS driverImage,
    'images/icons8-' ||
        replace(lower(cs.nationality), ' ', '-') ||
        '-50.png'                AS constructorImage,
    ce.engine_id                 AS engineId,
    e.reference                  AS engineReference,
    e.name                       AS engineName,
    e.nationality                AS engineNationality
FROM {{ source('main', 'session_entry') }} se
INNER JOIN {{ source('main', 'session') }} ssn
    ON se.session_id = ssn.id
INNER JOIN {{ source('main', 'round') }} rnd
    ON ssn.round_id = rnd.id
INNER JOIN {{ source('main', 'round_entry') }} re
    ON se.round_entry_id = re.id
INNER JOIN {{ source('main', 'constructor_driver') }} cd
    ON re.constructor_driver_id = cd.id
INNER JOIN {{ source('main', 'driver') }} d
    ON cd.driver_id = d.id
INNER JOIN {{ source('main', 'constructor') }} c
    ON cd.constructor_id = c.id
INNER JOIN {{ source('main', 'season') }} ssn
    ON cd.season_id = ssn.id
INNER JOIN {{ source('main', 'driver_season') }} ds
    ON d.id = ds.driver_id
   AND ssn.id = ds.season_id
INNER JOIN {{ source('main', 'constructor_season') }} cs
    ON c.id = cs.constructor_id
   AND ssn.id = cs.season_id
LEFT JOIN {{ source('main', 'constructor_engine') }} ce
    ON c.id = ce.constructor_id
   AND ssn.id = ce.season_id
LEFT JOIN {{ source('main', 'engine') }} e
    ON ce.engine_id = e.id
LEFT JOIN {{ source('main', 'driver_championship') }} dc
    ON dc.driver_id = d.id
   AND dc.session_id = ssn.id
WHERE ssn.type = 'R'
  AND ssn.year < strftime('%Y', 'now')
