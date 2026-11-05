CREATE TABLE IF NOT EXISTS "driver_nationality_corrections" (driver_id INT,season_id_start INT,season_id_end INT,country_code TEXT);
CREATE TABLE IF NOT EXISTS "team_nationality_corrections" (team_id INT,season_id_start INT,season_id_end INT,country_code TEXT,name TEXT);
CREATE TABLE base_team(id INT,name TEXT);
CREATE TABLE championship_adjustment(
  id INT,
  adjustment INT,
  driver_id INT,
  points REAL,
  season_id INT,
  team_id INT
);
CREATE TABLE championship_system(
  id INT,
  name TEXT,
  reference TEXT,
  driver_best_results INT,
  team_best_results INT,
  driver_season_split INT,
  team_season_split INT,
  team_points_per_session INT,
  eligibility TEXT
);
CREATE TABLE circuit(
  id INT,
  name TEXT,
  reference TEXT,
  locality TEXT,
  country TEXT,
  country_code TEXT,
  latitude REAL,
  longitude REAL,
  altitude INT,
  wikipedia TEXT
);
CREATE TABLE countries(
  id,
  country_code TEXT,
  country TEXT
);
CREATE TABLE driver(
  id INT,
  reference TEXT,
  abbreviation TEXT,
  forename TEXT,
  surname TEXT,
  country_code TEXT,
  date_of_birth,
  permanent_car_number INT,
  wikipedia TEXT
);
CREATE TABLE driver_championship(
  id INT,
  season_id INT,
  year INT,
  driver_id INT,
  round_id INT,
  position INT,
  points REAL,
  win_count INT,
  highest_finish INT,
  is_eligible INT,
  adjustment_type TEXT,
  session_id INT,
  session_number INT,
  round_number INT
);
CREATE TABLE lap(
  id INT,
  session_entry_id INT,
  number INT,
  position INT,
  time TEXT,
  average_speed TEXT,
  is_entry_fastest_lap INT,
  is_deleted INT
);
CREATE TABLE penalty(
  id INT,
  earned_id INT,
  served_id INT,
  position INT,
  license_points INT,
  is_time_served_in_pit INT,
  time TEXT
);
CREATE TABLE pit_stop(
  id INT,
  session_entry_id INT,
  lap_id INT,
  number INT,
  duration TEXT,
  local_timestamp TEXT
);
CREATE TABLE points_system(
  id INT,
  name TEXT,
  reference TEXT,
  partial INT,
  driver_position_points INT,
  driver_fastest_lap INT,
  team_position_points INT,
  team_fastest_lap INT,
  shared_drive INT,
  is_double_points INT
);
CREATE TABLE round(
  id INT,
  season_id INT,
  circuit_id INT,
  number INT,
  race_number INT,
  name TEXT,
  date,
  is_cancelled INT,
  wikipedia TEXT
);
CREATE TABLE roundentry(
  id INT,
  round_id INT,
  team_driver_id INT,
  car_number INT
);
CREATE TABLE season(
  id INT,
  year INT,
  championship_system_id INT,
  wikipedia TEXT
);
CREATE TABLE session(
  id INT,
  round_id INT,
  type TEXT,
  number INT,
  timestamp,
  timezone TEXT,
  scheduled_laps INT,
  point_system_id INT,
  is_cancelled INT,
  has_time_data INT
);
CREATE TABLE session_entry(
  id INT,
  session_id INT,
  round_entry_id INT,
  grid INT,
  position INT,
  points REAL,
  laps_completed INT,
  fastest_lap_rank INT,
  time TEXT,
  detail TEXT,
  status TEXT,
  is_classified INT,
  is_eligible_for_points INT
);
CREATE TABLE team(
  id INT,
  name TEXT,
  reference TEXT,
  country_code TEXT,
  base_team_id INT,
  primary_color TEXT,
  wikipedia TEXT
);
CREATE TABLE team_championship(
  id INT,
  season_id INT,
  year INT,
  team_id INT,
  round_id INT,
  position INT,
  points REAL,
  win_count INT,
  highest_finish INT,
  is_eligible INT,
  adjustment_type TEXT,
  session_id INT,
  session_number INT,
  round_number INT
);
CREATE TABLE team_driver(
  id INT,
  season_id INT,
  team_id INT,
  driver_id INT,
  role TEXT
);
CREATE TABLE season_driver(
  id,
  season_id INT,
  driver_id INT,
  country_id
);
CREATE TABLE season_team(
  id,
  season_id INT,
  team_id INT,
  country_id,
  name
);
CREATE VIEW "f1summary" as
    

-- Race results enriched with driver/team nationality.
-- Each driver/team is represented by its most common nationality across all
-- seasons, with ties broken by the lowest country_id.
-- Engine tables (constructor_engine, engine) do not exist in jolpica, so the
-- corresponding columns are omitted.

WITH driver_nat_counts AS (
    SELECT
        driver_id,
        country_id,
        COUNT(*) AS season_count
    FROM main."season_driver"
    GROUP BY driver_id, country_id
),

driver_nat AS (
    SELECT
        driver_id,
        country
    FROM (
        SELECT
            dnc.driver_id,
            c.country,
            ROW_NUMBER() OVER (
                PARTITION BY dnc.driver_id
                ORDER BY dnc.season_count DESC, dnc.country_id
            ) AS rn
        FROM driver_nat_counts dnc
        LEFT JOIN main."countries" c
            ON dnc.country_id = c.id
    )
    WHERE rn = 1
),

team_nat_counts AS (
    SELECT
        team_id,
        country_id,
        name,
        COUNT(*) AS season_count
    FROM main."season_team"
    GROUP BY team_id, country_id, name
),

team_nat AS (
    SELECT
        team_id,
        country,
        name
    FROM (
        SELECT
            tnc.team_id,
            c.country,
            tnc.name,
            ROW_NUMBER() OVER (
                PARTITION BY tnc.team_id
                ORDER BY tnc.season_count DESC, tnc.country_id
            ) AS rn
        FROM team_nat_counts tnc
        LEFT JOIN main."countries" c
            ON tnc.country_id = c.id
    )
    WHERE rn = 1
)

SELECT
    se.id                                       AS resultId,
    se.grid                                     AS grid,
    se.position                                 AS positionOrder,
    dc.points                                   AS cumulPoints,
    se.points                                   AS points,
    se.laps_completed                           AS laps,
    se.fastest_lap_rank                         AS "rank",
    CASE
        -- Equivalent of the original RLIKE '^\+[0-9]+ Lap$':
        -- a leading '+', a space, and a positive integer before ' Lap'.
        WHEN se.detail LIKE '+% Lap'
             AND CAST(substr(se.detail, 2, instr(se.detail, ' ') - 2) AS INTEGER) > 0
            THEN 'Lapsed'
        WHEN se.detail IN ('107% Rule', 'Did not qualify', 'Did not prequalify')
            THEN 'Not Qualified'
        WHEN se.detail IN ('Finished', 'Disqualified', 'Not classified', 'Lapsed')
            THEN se.detail
        ELSE 'Abandoned'
    END                                         AS status,
    sn.year                                     AS year,
    rnd.number                                  AS round,
    rnd.name                                    AS circuit,
    d.forename || ' ' || d.surname              AS driverName,
    sn.year - CAST(strftime('%Y', d.date_of_birth) AS INTEGER)
                                                AS driverAge,
    tn.name                                     AS constructorName,
    dn.country                                  AS driverCountry,
    tn.country                                  AS constructorCountry,
    'images/flags/icons8-' ||
        replace(lower(COALESCE(dn.country, 'unknown')), ' ', '-') ||
        '-50.png'                               AS driverImage,
    'images/flags/icons8-' ||
        replace(lower(COALESCE(tn.country, 'unknown')), ' ', '-') ||
        '-50.png'                               AS constructorImage
FROM main."session_entry" se
INNER JOIN main."session" sess
    ON se.session_id = sess.id
INNER JOIN main."round" rnd
    ON sess.round_id = rnd.id
INNER JOIN main."roundentry" re
    ON se.round_entry_id = re.id
INNER JOIN main."team_driver" td
    ON re.team_driver_id = td.id
INNER JOIN main."driver" d
    ON td.driver_id = d.id
INNER JOIN main."season" sn
    ON td.season_id = sn.id
LEFT JOIN main."driver_championship" dc
    ON dc.driver_id = d.id
   AND dc.session_id = sess.id
LEFT JOIN driver_nat dn
    ON d.id = dn.driver_id
LEFT JOIN team_nat tn
    ON td.team_id = tn.team_id
WHERE sess.type = 'R'
  AND sn.year < CAST(strftime('%Y', 'now') AS INTEGER)
/* f1summary(resultId,grid,positionOrder,cumulPoints,points,laps,rank,status,year,round,circuit,driverName,driverAge,constructorName,driverCountry,constructorCountry,driverImage,constructorImage) */;
