{{ config(materialized='view') }}

-- One row per driver: career aggregates plus world-title statistics.
-- Titles: the driver with the highest cumulative championship points
-- (driver_championship) at the end of each season, ties broken by name.
-- Ratios and period buckets replicate the original R f1_summary logic.

WITH res AS (
    -- Race-session results with championship standings points
    SELECT
        sn.year                                   AS year,
        d.id                                      AS driver_id,
        d.forename || ' ' || d.surname            AS driverName,
        se.position                               AS position_raw,
        se.points                                 AS points,
        dc.points                                 AS cumulPoints,
        sess.id                                   AS session_id
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

career AS (
    -- Per-driver career aggregates
    SELECT
        driver_id,
        driverName,
        MIN(year)                                 AS career_start,
        MAX(year)                                 AS career_end,
        COUNT(DISTINCT year)                      AS seasons,
        COUNT(DISTINCT session_id)                AS races,
        SUM(points)                               AS points,
        SUM(CASE WHEN CAST(position_raw AS INTEGER) = 1
                 THEN 1 ELSE 0 END)               AS wins
    FROM res
    GROUP BY driver_id, driverName
),

season_final AS (
    -- Final cumulative championship points per driver per season
    SELECT
        year,
        driver_id,
        driverName,
        MAX(cumulPoints)                          AS final_points
    FROM res
    GROUP BY year, driver_id, driverName
),

champions AS (
    -- Season champion: highest final cumulative points
    SELECT
        year,
        driver_id,
        driverName,
        final_points
    FROM (
        SELECT
            year,
            driver_id,
            driverName,
            final_points,
            ROW_NUMBER() OVER (
                PARTITION BY year
                ORDER BY final_points DESC, driverName
            ) AS rn
        FROM season_final
    )
    WHERE rn = 1
),

titles AS (
    SELECT
        driver_id,
        driverName,
        COUNT(*)                                  AS titles,
        MIN(year)                                 AS title_first,
        MAX(year)                                 AS title_last
    FROM champions
    GROUP BY driver_id, driverName
)

SELECT
    COALESCE(dn.country, 'unknown')               AS driverCountry,
    c.driverName,
    COALESCE(t.titles, 0)                         AS titles,
    t.title_first,
    t.title_last,
    c.wins,
    c.races,
    c.seasons                                     AS seasons,
    c.seasons                                     AS career_length,
    c.points,
    c.career_start,
    c.career_end,
    'images/flags/icons8-' ||
        replace(lower(COALESCE(dn.country, 'unknown')), ' ', '-') ||
        '-50.png'                                 AS countryImage,
    ROUND(COALESCE(t.titles, 0) * 1.0 / c.seasons, 3)
                                                  AS ratio_titles,
    ROUND(c.wins * 1.0 / c.races, 3)              AS ratio_wins,
    CASE
        WHEN t.title_first BETWEEN 1950 AND 1968 THEN '1950-1968'
        WHEN t.title_first BETWEEN 1969 AND 1993 THEN '1969-1993'
        WHEN t.title_first BETWEEN 1994 AND 2025 THEN '1994-2025'
        ELSE NULL
    END                                           AS period_start
FROM career c
LEFT JOIN titles t
    ON t.driver_id = c.driver_id
LEFT JOIN driver_nat dn
    ON dn.driver_id = c.driver_id
