{{ config(
    materialized='view',
    tags=['reporting']
) }}

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
FROM {{ ref('session_entry') }} se
INNER JOIN {{ ref('session') }} sess ON se.session_id = sess.id
INNER JOIN {{ ref('round') }} rnd ON sess.round_id = rnd.id
INNER JOIN {{ ref('round_entry') }} re ON se.round_entry_id = re.id
INNER JOIN {{ ref('constructor_driver') }} cd ON re.constructor_driver_id = cd.id
INNER JOIN {{ ref('driver') }} d ON cd.driver_id = d.id
INNER JOIN {{ ref('constructor') }} c ON cd.constructor_id = c.id
INNER JOIN {{ ref('season') }} sn ON cd.season_id = sn.id
INNER JOIN {{ ref('driver_season') }} ds
        ON d.id = ds.driver_id AND sn.id = ds.season_id
INNER JOIN {{ ref('constructor_season') }} cs
        ON c.id = cs.constructor_id AND sn.id = cs.season_id
LEFT JOIN {{ ref('constructor_engine') }} ce
        ON c.id = ce.constructor_id AND sn.id = ce.season_id
LEFT JOIN {{ ref('engine') }} e
        ON ce.engine_id = e.id
LEFT JOIN {{ ref('driver_championship') }} dc
        ON dc.driver_id = d.id AND dc.session_id = sess.id
WHERE sess.type = 'R'
  AND sn.year < strftime('%Y', 'now')
