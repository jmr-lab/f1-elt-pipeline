SELECT
    se.id                        AS resultId,
    se.grid                      AS grid,
    se.position                  AS positionOrder,
    dc.points                    AS cumulPoints,
    se.points                    AS points,
    se.laps_completed            AS laps,
    se.fastest_lap_rank          AS `rank`,
    CASE
        WHEN se.detail RLIKE '^\\+[0-9][0-9].* Lap$'
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
    concat(d.forename, ' ', d.surname)
                                 AS driverName,
    sn.year - CAST(year(to_date(d.date_of_birth)) AS INT)
                                 AS driverAge,
    cs.name                      AS constructorName,
    ds.nationality               AS driverCountry,
    cs.nationality               AS constructorCountry,
    concat('images/icons8-',
           lower(replace(ds.nationality, ' ', '-')),
           '-50.png')            AS driverImage,
    concat('images/icons8-',
           lower(replace(cs.nationality, ' ', '-')),
           '-50.png')            AS constructorImage,
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
  AND sn.year < year(current_date())
