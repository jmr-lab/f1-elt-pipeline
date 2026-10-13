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
    t.name                       AS constructorName,
    dc_map.country               AS driverCountry,
    tc_map.country               AS constructorCountry,
    'images/icons8-' ||
        replace(lower(dc_map.country), ' ', '-') ||
        '-50.png'                AS driverImage,
    'images/icons8-' ||
        replace(lower(tc_map.country), ' ', '-') ||
        '-50.png'                AS constructorImage

FROM {{ ref('session_entry') }} se
INNER JOIN {{ ref('session') }} s
    ON se.session_id = s.id
INNER JOIN {{ ref('roundentry') }} re
    ON se.round_entry_id = re.id
INNER JOIN {{ ref('team_driver') }} td
    ON re.team_driver_id = td.id
INNER JOIN {{ ref('driver') }} d
    ON td.driver_id = d.id
INNER JOIN {{ ref('team') }} t
    ON td.team_id = t.id
INNER JOIN {{ ref('season') }} ssn
    ON td.season_id = ssn.id
INNER JOIN {{ ref('round') }} rnd
    ON re.round_id = rnd.id
LEFT JOIN {{ ref('driver_championship') }} dc
    ON dc.driver_id = d.id
   AND dc.session_id = s.id
LEFT JOIN _countries_lookup dc_map
    ON dc_map.country_code = d.country_code
LEFT JOIN _countries_lookup tc_map
    ON tc_map.country_code = t.country_code
WHERE s.type = 'R'
  AND ssn.year < strftime('%Y', 'now')
