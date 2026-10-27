{{ config(materialized='view') }}

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
    FROM {{ ref('season_driver') }}
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
    'images/icons8-' ||
        replace(lower(COALESCE(dn.country, 'unknown')), ' ', '-') ||
        '-50.png'                               AS driverImage,
    'images/icons8-' ||
        replace(lower(COALESCE(tn.country, 'unknown')), ' ', '-') ||
        '-50.png'                               AS constructorImage
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
LEFT JOIN driver_nat dn
    ON d.id = dn.driver_id
LEFT JOIN team_nat tn
    ON td.team_id = tn.team_id
WHERE sess.type = 'R'
  AND sn.year < CAST(strftime('%Y', 'now') AS INTEGER)
