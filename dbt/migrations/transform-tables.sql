-- ============================================================
-- F1 SCHEMA MIGRATION TO NEW MODEL (WITH PREFIX)
-- Keeps OLD tables intact, creates NEW v2_ prefixed tables
--
-- ALL FIXES APPLIED:
--   1. driver: source uses 'nationality', mapped to 'birth_country'
--   2. v2_round.number: NULL fallback using ROW_NUMBER() per season
--   3. v2_driver_championship: derive season_id from year; skip NULL round_id
--   4. v2_constructor_championship: derive season_id from year; skip NULL round_id
--   5. v2_lap.number: NULL fallback using ROW_NUMBER() per session_entry
--   6. _countries_lookup: source only has (country_code, country);
--      use rowid as PK, NULL for iso_alpha3/continent
--   7. v2_driver_season.nationality: COALESCE to 'Unknown'
--   8. v2_constructor_season.nationality: COALESCE to 'Unknown'
--   9. v2_constructor_engine: resolve season_id via year join (was using
--      calendar years as season IDs, breaking the FK relationship test)
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

-- FIX 1: Driver — source table has 'nationality', not 'country'. Map to birth_country.
INSERT INTO v2_driver (id, reference, abbreviation, forename, surname,
                       permanent_car_number, date_of_birth, birth_country, wikipedia)
SELECT id, reference, abbreviation, forename, surname,
       permanent_car_number, date_of_birth, nationality, wikipedia FROM driver;

-- Migrate Constructor (renamed from team, no api_id)
INSERT INTO v2_constructor (id, name, reference, base_constructor_id, primary_color, wikipedia)
SELECT id, name, reference, base_team_id, primary_color, wikipedia FROM team;

-- FIX 2: Round — NULL 'number' fallback using ROW_NUMBER() per season ordered by date.
INSERT INTO v2_round (id, season_id, circuit_id, number, name, date, is_cancelled, wikipedia)
SELECT r.id, r.season_id, r.circuit_id,
       CASE
         WHEN r.number IS NOT NULL THEN r.number
         ELSE (SELECT COALESCE(MAX(r2.number), 0) FROM round r2 WHERE r2.season_id = r.season_id)
              + ROW_NUMBER() OVER (PARTITION BY r.season_id ORDER BY r.date, r.id)
       END AS number,
       COALESCE(r.name, 'Unknown round'),
       r.date,
       COALESCE(r.is_cancelled, 0),
       r.wikipedia
FROM round r;

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

-- FIX 3: Driver Championship — derive season_id from year when NULL; skip NULL round_id.
INSERT INTO v2_driver_championship (id, season_id, year, driver_id, round_id, position,
                                     points, win_count, highest_finish, is_eligible,
                                     adjustment_type, session_id, session_number, round_number)
SELECT dc.id,
       COALESCE(dc.season_id, (SELECT s.id FROM season s WHERE s.year = dc.year)),
       dc.year, dc.driver_id, dc.round_id, dc.position, dc.points,
       dc.win_count, dc.highest_finish, dc.is_eligible, dc.adjustment_type,
       dc.session_id, dc.session_number, dc.round_number
FROM driver_championship dc
WHERE dc.round_id IS NOT NULL
  AND COALESCE(dc.season_id, (SELECT s.id FROM season s WHERE s.year = dc.year)) IS NOT NULL;

-- FIX 4: Constructor Championship — derive season_id from year when NULL; skip NULL round_id.
INSERT INTO v2_constructor_championship (id, season_id, year, constructor_id, round_id, position,
                                          points, win_count, highest_finish, is_eligible,
                                          adjustment_type, session_id, session_number, round_number)
SELECT tc.id,
       COALESCE(tc.season_id, (SELECT s.id FROM season s WHERE s.year = tc.year)),
       tc.year, tc.team_id, tc.round_id, tc.position, tc.points,
       tc.win_count, tc.highest_finish, tc.is_eligible, tc.adjustment_type,
       tc.session_id, tc.session_number, tc.round_number
FROM team_championship tc
WHERE tc.round_id IS NOT NULL
  AND COALESCE(tc.season_id, (SELECT s.id FROM season s WHERE s.year = tc.year)) IS NOT NULL;

-- FIX 5: Lap — NULL 'number' fallback using ROW_NUMBER() per session_entry ordered by id.
INSERT INTO v2_lap (id, session_entry_id, number, position, time, average_speed,
                    is_fastest_lap, is_deleted)
SELECT l.id, l.session_entry_id,
       CASE
         WHEN l.number IS NOT NULL THEN l.number
         ELSE (SELECT COALESCE(MAX(l2.number), 0) FROM lap l2 WHERE l2.session_entry_id = l.session_entry_id)
              + ROW_NUMBER() OVER (PARTITION BY l.session_entry_id ORDER BY l.id)
       END AS number,
       l.position, l.time, l.average_speed,
       l.is_entry_fastest_lap, l.is_deleted
FROM lap l;

-- Migrate Pit Stop (no api_id)
INSERT INTO v2_pit_stop (id, session_entry_id, lap_id, number, duration, local_timestamp)
SELECT id, session_entry_id, lap_id, number, duration, local_timestamp FROM pit_stop;

-- Migrate Penalty (no api_id)
INSERT INTO v2_penalty (id, earned_session_entry_id, served_session_entry_id,
                        position, license_points, is_time_served_in_pit, time)
SELECT id, earned_id, served_id, position, license_points,
       is_time_served_in_pit, time FROM penalty;

-- FIX 6: Countries Lookup — source table only has (country_code, country).
-- Use rowid as surrogate PK; iso_alpha3 and continent don't exist in source,
-- so insert NULL for those columns (enrich later if desired).
INSERT INTO v2_countries (id, country_code, country, iso_alpha3, continent)
SELECT rowid, country_code, country, NULL, NULL
FROM _countries_lookup;

-- ============================================================
-- PART 9: CREATE YEAR-GRAIN ATTRIBUTE TABLES FROM EXISTING DATA
-- ============================================================

-- FIX 7: Driver Nationality Per Season — COALESCE NULL nationality to 'Unknown'.
INSERT INTO v2_driver_season (driver_id, season_id, nationality, country_code)
SELECT td.driver_id, td.season_id,
       COALESCE(d.nationality, 'Unknown') AS nationality,
       d.country_code
FROM team_driver td
JOIN driver d ON td.driver_id = d.id
GROUP BY td.driver_id, td.season_id;

-- FIX 8: Constructor Season — COALESCE NULL nationality and name to 'Unknown'.
INSERT INTO v2_constructor_season (constructor_id, season_id, name, nationality, country_code, base_constructor_id)
SELECT td.team_id, td.season_id,
       COALESCE(t.name, 'Unknown') AS name,
       COALESCE(t.nationality, 'Unknown') AS nationality,
       t.country_code, t.base_team_id
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

-- FIXED: resolve season_id via year join (was using calendar years as season IDs, breaking FK relationship)
-- Extend by adding another UNION ALL row to the mapping subquery.
INSERT INTO v2_constructor_engine (constructor_id, season_id, engine_id, engine_ref_override)
SELECT c.id, s.id, e.id, NULL
FROM (
    SELECT 'ferrari'  AS constructor_ref, 'ferrari'  AS engine_ref, 2005 AS first_year, 2025 AS last_year
    UNION ALL
    SELECT 'mercedes', 'mercedes', 2010, 2025
) AS m
JOIN v2_constructor c ON c.reference = m.constructor_ref
JOIN v2_engine      e ON e.reference = m.engine_ref
JOIN v2_season      s ON s.year BETWEEN m.first_year AND m.last_year;

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

-- ============================================================
-- PART 12: CREATE f1summary VIEW
-- ============================================================

CREATE VIEW IF NOT EXISTS f1summary AS
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
    sn.year                      AS year,
    rnd.number                   AS round,
    rnd.name                     AS circuit,
    d.forename || ' ' || d.surname
                                 AS driverName,
    sn.year - CAST(strftime('%Y', d.date_of_birth) AS INTEGER)
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
FROM v2_session_entry se
INNER JOIN v2_session sess ON se.session_id = sess.id
INNER JOIN v2_round rnd ON sess.round_id = rnd.id
INNER JOIN v2_round_entry re ON se.round_entry_id = re.id
INNER JOIN v2_constructor_driver cd ON re.constructor_driver_id = cd.id
INNER JOIN v2_driver d ON cd.driver_id = d.id
INNER JOIN v2_constructor c ON cd.constructor_id = c.id
INNER JOIN v2_season sn ON cd.season_id = sn.id
INNER JOIN v2_driver_season ds ON d.id = ds.driver_id AND sn.id = ds.season_id
INNER JOIN v2_constructor_season cs ON c.id = cs.constructor_id AND sn.id = cs.season_id
LEFT JOIN v2_constructor_engine ce ON c.id = ce.constructor_id AND sn.id = ce.season_id
LEFT JOIN v2_engine e ON ce.engine_id = e.id
LEFT JOIN v2_driver_championship dc ON dc.driver_id = d.id AND dc.session_id = sess.id
WHERE sess.type = 'R'
  AND sn.year < strftime('%Y', 'now');
