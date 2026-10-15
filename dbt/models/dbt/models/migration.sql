-- ============================================================
-- F1 SCHEMA MIGRATION TO NEW MODEL (WITH PREFIX)
-- Keeps OLD tables intact, creates NEW v2_ prefixed tables
-- ============================================================

-- ============================================================
-- PART 1: DROP EXISTING VIEW IF EXISTS
-- ============================================================
DROP VIEW IF EXISTS f1summary;

-- ============================================================
-- PART 2: CREATE NEW DIMENSION TABLES (WITH v2_ PREFIX)
-- ============================================================

CREATE TABLE IF NOT EXISTS v2_season (
    id INTEGER PRIMARY KEY,
    year INTEGER UNIQUE NOT NULL,
    championship_system_id INTEGER,
    wikipedia TEXT
);

CREATE TABLE IF NOT EXISTS v2_circuit (
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

CREATE TABLE IF NOT EXISTS v2_driver (
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

CREATE TABLE IF NOT EXISTS v2_constructor (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    reference TEXT UNIQUE NOT NULL,
    base_constructor_id INTEGER,
    primary_color TEXT,
    wikipedia TEXT
);

CREATE TABLE IF NOT EXISTS v2_engine (
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

CREATE TABLE IF NOT EXISTS v2_driver_season (
    driver_id INTEGER NOT NULL,
    season_id INTEGER NOT NULL,
    nationality TEXT NOT NULL,
    country_code TEXT,
    PRIMARY KEY (driver_id, season_id),
    FOREIGN KEY (driver_id) REFERENCES v2_driver(id),
    FOREIGN KEY (season_id) REFERENCES v2_season(id)
);

CREATE TABLE IF NOT EXISTS v2_constructor_season (
    constructor_id INTEGER NOT NULL,
    season_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    nationality TEXT NOT NULL,
    country_code TEXT,
    base_constructor_id INTEGER,
    PRIMARY KEY (constructor_id, season_id),
    FOREIGN KEY (constructor_id) REFERENCES v2_constructor(id),
    FOREIGN KEY (season_id) REFERENCES v2_season(id)
);

CREATE TABLE IF NOT EXISTS v2_constructor_engine (
    constructor_id INTEGER NOT NULL,
    season_id INTEGER NOT NULL,
    engine_id INTEGER NOT NULL,
    engine_ref_override TEXT,
    PRIMARY KEY (constructor_id, season_id),
    FOREIGN KEY (constructor_id) REFERENCES v2_constructor(id),
    FOREIGN KEY (season_id) REFERENCES v2_season(id),
    FOREIGN KEY (engine_id) REFERENCES v2_engine(id)
);

-- ============================================================
-- PART 4: CREATE EVENT & RESULTS TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS v2_round (
    id INTEGER PRIMARY KEY,
    season_id INTEGER NOT NULL,
    circuit_id INTEGER NOT NULL,
    number INTEGER NOT NULL,
    name TEXT NOT NULL,
    date TEXT,
    is_cancelled INTEGER DEFAULT 0,
    wikipedia TEXT,
    FOREIGN KEY (season_id) REFERENCES v2_season(id),
    FOREIGN KEY (circuit_id) REFERENCES v2_circuit(id),
    UNIQUE(season_id, number)
);

CREATE TABLE IF NOT EXISTS v2_constructor_driver (
    id INTEGER PRIMARY KEY,
    season_id INTEGER NOT NULL,
    constructor_id INTEGER NOT NULL,
    driver_id INTEGER NOT NULL,
    role TEXT,
    FOREIGN KEY (season_id) REFERENCES v2_season(id),
    FOREIGN KEY (constructor_id) REFERENCES v2_constructor(id),
    FOREIGN KEY (driver_id) REFERENCES v2_driver(id),
    UNIQUE(season_id, constructor_id, driver_id, role)
);

CREATE TABLE IF NOT EXISTS v2_round_entry (
    id INTEGER PRIMARY KEY,
    round_id INTEGER NOT NULL,
    constructor_driver_id INTEGER NOT NULL,
    car_number INTEGER,
    FOREIGN KEY (round_id) REFERENCES v2_round(id),
    FOREIGN KEY (constructor_driver_id) REFERENCES v2_constructor_driver(id)
);

CREATE TABLE IF NOT EXISTS v2_session (
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
    FOREIGN KEY (round_id) REFERENCES v2_round(id)
);

CREATE TABLE IF NOT EXISTS v2_session_entry (
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
    FOREIGN KEY (session_id) REFERENCES v2_session(id),
    FOREIGN KEY (round_entry_id) REFERENCES v2_round_entry(id)
);

-- ============================================================
-- PART 5: CHAMPIONSHIP TRACKING TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS v2_driver_championship (
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
    FOREIGN KEY (season_id) REFERENCES v2_season(id),
    FOREIGN KEY (driver_id) REFERENCES v2_driver(id),
    FOREIGN KEY (round_id) REFERENCES v2_round(id),
    UNIQUE(season_id, round_id, driver_id)
);

CREATE TABLE IF NOT EXISTS v2_constructor_championship (
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
    FOREIGN KEY (season_id) REFERENCES v2_season(id),
    FOREIGN KEY (constructor_id) REFERENCES v2_constructor(id),
    FOREIGN KEY (round_id) REFERENCES v2_round(id),
    UNIQUE(season_id, round_id, constructor_id)
);

-- ============================================================
-- PART 6: DETAIL DATA TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS v2_lap (
    id INTEGER PRIMARY KEY,
    session_entry_id INTEGER NOT NULL,
    number INTEGER NOT NULL,
    position INTEGER,
    time TEXT,
    average_speed TEXT,
    is_fastest_lap INTEGER,
    is_deleted INTEGER DEFAULT 0,
    FOREIGN KEY (session_entry_id) REFERENCES v2_session_entry(id)
);

CREATE TABLE IF NOT EXISTS v2_pit_stop (
    id INTEGER PRIMARY KEY,
    session_entry_id INTEGER NOT NULL,
    lap_id INTEGER,
    number INTEGER,
    duration TEXT,
    local_timestamp TEXT,
    FOREIGN KEY (session_entry_id) REFERENCES v2_session_entry(id),
    FOREIGN KEY (lap_id) REFERENCES v2_lap(id)
);

CREATE TABLE IF NOT EXISTS v2_penalty (
    id INTEGER PRIMARY KEY,
    earned_session_entry_id INTEGER,
    served_session_entry_id INTEGER,
    position INTEGER,
    license_points INTEGER,
    is_time_served_in_pit INTEGER,
    time TEXT,
    FOREIGN KEY (earned_session_entry_id) REFERENCES v2_session_entry(id),
    FOREIGN KEY (served_session_entry_id) REFERENCES v2_session_entry(id)
);

-- ============================================================
-- PART 7: LOOKUP TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS v2_countries (
    id INTEGER PRIMARY KEY,
    country_code TEXT UNIQUE NOT NULL,
    country TEXT,
    iso_alpha3 TEXT,
    continent TEXT
);

-- ============================================================
-- PART 8: COPY DATA FROM OLD TO NEW TABLES (KEEPING BOTH SETS)
-- ============================================================

-- Migrate Season (no api_id)
INSERT INTO v2_season (id, year, championship_system_id, wikipedia)
SELECT id, year, championship_system_id, wikipedia FROM season;

-- Migrate Circuit (no api_id)
INSERT INTO v2_circuit (id, name, reference, locality, country, country_code,
                        latitude, longitude, altitude, wikipedia)
SELECT id, name, reference, locality, country, country_code,
       latitude, longitude, altitude, wikipedia FROM circuit;

-- Migrate Driver (no api_id, map country to birth_country)
INSERT INTO v2_driver (id, reference, abbreviation, forename, surname,
                       permanent_car_number, date_of_birth, birth_country, wikipedia)
SELECT id, reference, abbreviation, forename, surname,
       permanent_car_number, date_of_birth, country, wikipedia FROM driver;

-- Migrate Constructor (renamed from team, no api_id)
INSERT INTO v2_constructor (id, name, reference, base_constructor_id, primary_color, wikipedia)
SELECT id, name, reference, base_team_id, primary_color, wikipedia FROM team;

-- Migrate Round (no api_id)
INSERT INTO v2_round (id, season_id, circuit_id, number, name, date, is_cancelled, wikipedia)
SELECT id, season_id, circuit_id, number, name, date, is_cancelled, wikipedia FROM round;

-- Migrate Constructor Driver (renamed from team_driver, no api_id)
INSERT INTO v2_constructor_driver (id, season_id, constructor_id, driver_id, role)
SELECT id, season_id, team_id, driver_id, role FROM team_driver;

-- Migrate Round Entry (rename FK, no api_id)
INSERT INTO v2_round_entry (id, round_id, constructor_driver_id, car_number)
SELECT id, round_id, team_driver_id, car_number FROM roundentry;

-- Migrate Session (no api_id)
INSERT INTO v2_session (id, round_id, type, number, timestamp, timezone,
                        scheduled_laps, point_system_id, is_cancelled, has_time_data)
SELECT id, round_id, type, number, timestamp, timezone,
       scheduled_laps, point_system_id, is_cancelled, has_time_data FROM session;

-- Migrate Session Entry (no api_id)
INSERT INTO v2_session_entry (id, session_id, round_entry_id, grid, position,
                              points, laps_completed, fastest_lap_rank, time,
                              detail, status, is_classified, is_eligible_for_points)
SELECT id, session_id, round_entry_id, grid, position, points,
       laps_completed, fastest_lap_rank, time, detail, status,
       is_classified, is_eligible_for_points FROM session_entry;

-- Migrate Driver Championship (no api_id)
INSERT INTO v2_driver_championship (id, season_id, year, driver_id, round_id, position,
                                     points, win_count, highest_finish, is_eligible,
                                     adjustment_type, session_id, session_number, round_number)
SELECT id, season_id, year, driver_id, round_id, position, points,
       win_count, highest_finish, is_eligible, adjustment_type,
       session_id, session_number, round_number FROM driver_championship;

-- Migrate Constructor Championship (rename team_id → constructor_id, no api_id)
INSERT INTO v2_constructor_championship (id, season_id, year, constructor_id, round_id, position,
                                          points, win_count, highest_finish, is_eligible,
                                          adjustment_type, session_id, session_number, round_number)
SELECT id, season_id, year, team_id, round_id, position, points,
       win_count, highest_finish, is_eligible, adjustment_type,
       session_id, session_number, round_number FROM team_championship;

-- Migrate Lap (no api_id)
INSERT INTO v2_lap (id, session_entry_id, number, position, time, average_speed,
                    is_fastest_lap, is_deleted)
SELECT id, session_entry_id, number, position, time, average_speed,
       is_entry_fastest_lap, is_deleted FROM lap;

-- Migrate Pit Stop (no api_id)
INSERT INTO v2_pit_stop (id, session_entry_id, lap_id, number, duration, local_timestamp)
SELECT id, session_entry_id, lap_id, number, duration, local_timestamp FROM pit_stop;

-- Migrate Penalty (no api_id)
INSERT INTO v2_penalty (id, earned_session_entry_id, served_session_entry_id,
                        position, license_points, is_time_served_in_pit, time)
SELECT id, earned_id, served_id, position, license_points,
       is_time_served_in_pit, time FROM penalty;

-- Migrate Countries Lookup
INSERT INTO v2_countries (id, country_code, country, iso_alpha3, continent)
SELECT id, country_code, country, iso_alpha3, continent FROM _countries_lookup;

-- ============================================================
-- PART 9: CREATE YEAR-GRAIN ATTRIBUTE TABLES FROM EXISTING DATA
-- ============================================================

-- Driver Nationality Per Season (from old team_driver + driver)
INSERT INTO v2_driver_season (driver_id, season_id, nationality, country_code)
SELECT td.driver_id, td.season_id, d.nationality, d.country_code
FROM team_driver td
JOIN driver d ON td.driver_id = d.id
GROUP BY td.driver_id, td.season_id;

-- Constructor Season (from old team_driver + team)
INSERT INTO v2_constructor_season (constructor_id, season_id, name, nationality, country_code, base_constructor_id)
SELECT td.team_id, td.season_id, t.name, t.nationality, t.country_code, t.base_team_id
FROM team_driver td
JOIN team t ON td.team_id = t.id
GROUP BY td.team_id, td.season_id;

-- ============================================================
-- PART 10: POPULATE ENGINE TABLE
-- ============================================================

INSERT INTO v2_engine (id, name, reference, nationality, founded_year, wikipedia) VALUES
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

-- Sample constructor-engine relationships (extend as needed)
INSERT INTO v2_constructor_engine (constructor_id, season_id, engine_id, engine_ref_override) VALUES
-- Ferrari (self-supplied)
(1, 2005, 1, NULL), (1, 2006, 1, NULL), (1, 2007, 1, NULL), (1, 2008, 1, NULL),
(1, 2009, 1, NULL), (1, 2010, 1, NULL), (1, 2011, 1, NULL), (1, 2012, 1, NULL),
(1, 2013, 1, NULL), (1, 2014, 1, NULL), (1, 2015, 1, NULL), (1, 2016, 1, NULL),
(1, 2017, 1, NULL), (1, 2018, 1, NULL), (1, 2019, 1, NULL), (1, 2020, 1, NULL),
(1, 2021, 1, NULL), (1, 2022, 1, NULL), (1, 2023, 1, NULL), (1, 2024, 1, NULL),
(1, 2025, 1, NULL),
-- Mercedes
(2, 2010, 2, NULL), (2, 2011, 2, NULL), (2, 2012, 2, NULL), (2, 2013, 2, NULL),
(2, 2014, 2, NULL), (2, 2015, 2, NULL), (2, 2016, 2, NULL), (2, 2017, 2, NULL),
(2, 2018, 2, NULL), (2, 2019, 2, NULL), (2, 2020, 2, NULL), (2, 2021, 2, NULL),
(2, 2022, 2, NULL), (2, 2023, 2, NULL), (2, 2024, 2, NULL), (2, 2025, 2, NULL);

-- ============================================================
-- PART 11: CREATE INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_v2_round_season ON v2_round(season_id);
CREATE INDEX IF NOT EXISTS idx_v2_round_circuit ON v2_round(circuit_id);
CREATE INDEX IF NOT EXISTS idx_v2_session_round ON v2_session(round_id);
CREATE INDEX IF NOT EXISTS idx_v2_session_type ON v2_session(type);
CREATE INDEX IF NOT EXISTS idx_v2_session_entry_session ON v2_session_entry(session_id);
CREATE INDEX IF NOT EXISTS idx_v2_session_entry_position ON v2_session_entry(position);
CREATE INDEX IF NOT EXISTS idx_v2_driver_season_driver ON v2_driver_season(driver_id);
CREATE INDEX IF NOT EXISTS idx_v2_driver_season_year ON v2_driver_season(season_id);
CREATE INDEX IF NOT EXISTS idx_v2_constructor_season_constructor ON v2_constructor_season(constructor_id);
CREATE INDEX IF NOT EXISTS idx_v2_constructor_season_year ON v2_constructor_season(season_id);
CREATE INDEX IF NOT EXISTS idx_v2_constructor_engine_constructor ON v2_constructor_engine(constructor_id);
CREATE INDEX IF NOT EXISTS idx_v2_constructor_driver_season ON v2_constructor_driver(season_id);
CREATE INDEX IF NOT EXISTS idx_v2_constructor_driver_driver ON v2_constructor_driver(driver_id);
CREATE INDEX IF NOT EXISTS idx_v2_driver_champ_driver ON v2_driver_championship(driver_id);
CREATE INDEX IF NOT EXISTS idx_v2_driver_champ_season ON v2_driver_championship(season_id);
CREATE INDEX IF NOT EXISTS idx_v2_constructor_champ_constructor ON v2_constructor_championship(constructor_id);
CREATE INDEX IF NOT EXISTS idx_v2_lap_session_entry ON v2_lap(session_entry_id, number);
CREATE INDEX IF NOT EXISTS idx_v2_pitstop_session_entry ON v2_pit_stop(session_entry_id);
