{{ config(
    materialized='table',
    tags=['history']
) }}

WITH aggregated AS (
    SELECT
        td.driver_id,
        td.season_id,
        COALESCE(d.nationality, 'Unknown') AS nationality,
        d.country_code
    FROM {{ source('jolpica', 'team_driver') }} td
    JOIN {{ source('jolpica', 'driver') }} d ON td.driver_id = d.id
    GROUP BY td.driver_id, td.season_id
),

numbered AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY driver_id, season_id) AS id,
        driver_id,
        season_id,
        nationality,
        country_code
    FROM aggregated
)

SELECT * FROM numbered
