{{ config(materialized='view') }}

-- VIEW: f1_season_summary (one row per driver-season)
--   Full standings per season: every driver with their constructor,
--   countries, age, season points, max cumulative championship
--   points, standings position (by max cumul points), and titles
--   won strictly before that season.
--   Constructor = the team where the driver scored most points
--   that season.
--   Note: sqlite sorts NULLs last for DESC, so NULLS LAST is implicit.

WITH res AS (
    -- Race-session results with championship standings points
    SELECT
        sn.year                     AS year,
        d.id                        AS driver_id,
        d.forename || ' ' || d.surname
                                    AS driverName,
        d.date_of_birth             AS date_of_birth,
        td.team_id                  AS team_id,
        se.points                   AS points,
        dc.points                   AS cumulPoints
    FROM {{ ref('session_entry') }} se
    INNER JOIN {{ ref('session') }} sess
        ON se.session_id = sess.id
    INNER JOIN {{ ref('round') }} rnd
        ON sess.round_id = rnd.id
    INNER JOIN {{ ref('roundentry') }} re
        ON se.round_entry_id = re.id
    INNER JOIN {{ ref('team_driver') }} td
        ON re.team_driver_id = td.id
    INNER JOIN {{ ref('driver') }} d
        ON td.driver_id = d.id
    INNER JOIN {{ ref('season') }} sn
        ON td.season_id = sn.id
    LEFT JOIN {{ ref('driver_championship') }} dc
        ON dc.driver_id = d.id
       AND dc.session_id = sess.id
    WHERE sess.type = 'R'
      AND sn.year < CAST(strftime('%Y', 'now') AS INTEGER)
),

driver_nat_counts AS (
    SELECT
        driver_id,
        country_id,
        COUNT(*) AS season_count
    FROM {{ ref('season_driver') }}
    GROUP BY driver_id, country_id
),

driver_nat AS (
    -- Most common nationality per driver across all seasons
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
        LEFT JOIN {{ ref('countries') }} c
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
    FROM {{ ref('season_team') }}
    GROUP BY team_id, country_id, name
),

team_nat AS (
    -- Most common nationality and name per team across all seasons
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
        LEFT JOIN {{ ref('countries') }} c
            ON tnc.country_id = c.id
    )
    WHERE rn = 1
),

season_agg AS (
    -- Per-driver season totals and best championship cumulative points
    SELECT
        year,
        driver_id,
        driverName,
        MIN(date_of_birth)          AS date_of_birth,
        SUM(points)                 AS total_points,
        MAX(cumulPoints)            AS max_cumul_points
    FROM res
    GROUP BY year, driver_id, driverName
),

team_standings AS (
    -- Season points per driver per team
    SELECT
        year,
        driver_id,
        team_id,
        SUM(points) AS team_points
    FROM res
    GROUP BY year, driver_id, team_id
),

main_teams AS (
    -- The team where each driver scored most of his points that season
    SELECT
        year,
        driver_id,
        team_id
    FROM (
        SELECT
            ts.year,
            ts.driver_id,
            ts.team_id,
            ROW_NUMBER() OVER (
                PARTITION BY ts.year, ts.driver_id
                ORDER BY ts.team_points DESC, ts.team_id
            ) AS rn
        FROM team_standings ts
    )
    WHERE rn = 1
),

season_rank AS (
    -- Standings position based on max cumulative championship points
    SELECT
        a.*,
        ROW_NUMBER() OVER (
            PARTITION BY a.year
            ORDER BY a.max_cumul_points DESC,
                     a.total_points DESC,
                     a.driverName
        ) AS position
    FROM season_agg a
),

champions AS (
    -- Season champion: position 1
    SELECT
        year,
        driver_id
    FROM season_rank
    WHERE position = 1
),

champions_hist AS (
    -- Titles each ever-champion driver had won strictly before every season
    SELECT
        s.year,
        c.driver_id,
        COUNT(c2.year) AS previous_titles
    FROM (SELECT DISTINCT year FROM season_agg) s
    CROSS JOIN (SELECT DISTINCT driver_id FROM champions) c
    LEFT JOIN champions c2
        ON c2.driver_id = c.driver_id
       AND c2.year < s.year
    GROUP BY s.year, c.driver_id
)

SELECT
    r.year                                        AS season,
    r.driverName                                  AS driverName,
    dn.country                                    AS driverCountry,
    r.year - CAST(strftime('%Y', r.date_of_birth) AS INTEGER)
                                                  AS driverAge,
    tn.name                                       AS constructorName,
    tn.country                                    AS constructorCountry,
    r.total_points                                AS total_points,
    r.max_cumul_points                            AS max_cumul_points,
    r.position                                    AS position,
    COALESCE(ph.previous_titles, 0)               AS previous_titles
FROM season_rank r
LEFT JOIN main_teams mt
    ON mt.year = r.year AND mt.driver_id = r.driver_id
LEFT JOIN driver_nat dn
    ON dn.driver_id = r.driver_id
LEFT JOIN team_nat tn
    ON tn.team_id = mt.team_id
LEFT JOIN champions_hist ph
    ON ph.year = r.year AND ph.driver_id = r.driver_id
