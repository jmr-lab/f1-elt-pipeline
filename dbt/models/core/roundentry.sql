{{ config(materialized='table') }}

SELECT
    re.id,
    re.round_id,
    re.team_driver_id,
    re.car_number,
    CASE WHEN fl.roundentry_id IS NOT NULL THEN TRUE END AS is_fastest_lap
FROM {{ source('jolpica', 'roundentry') }} re
LEFT JOIN (
    SELECT DISTINCT re2.id AS roundentry_id
    FROM {{ ref('fastestlaps_lookup') }} fl
    JOIN {{ source('jolpica', 'season') }} s
      ON s.year = fl.year
    JOIN {{ source('jolpica', 'round') }} r
      ON r.season_id = s.id
     AND r.number = fl.round
    JOIN {{ source('jolpica', 'roundentry') }} re2
      ON re2.round_id = r.id
     AND (fl.car_number IS NULL OR re2.car_number = fl.car_number)
    JOIN {{ source('jolpica', 'team_driver') }} td
      ON td.id = re2.team_driver_id
    JOIN {{ source('jolpica', 'driver') }} d
      ON d.id = td.driver_id
     AND d.forename || ' ' || d.surname = fl.driver_name
) fl
  ON fl.roundentry_id = re.id
