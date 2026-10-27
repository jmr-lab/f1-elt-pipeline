{{ config(materialized='table') }}

SELECT
    id,
    adjustment,
    driver_id,
    points,
    season_id,
    team_id
FROM {{ source('jolpica', 'championship_adjustment') }}
