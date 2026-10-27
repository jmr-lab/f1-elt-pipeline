{{ config(materialized='table') }}

SELECT
    id,
    season_id,
    team_id,
    driver_id,
    role
FROM {{ source('jolpica', 'team_driver') }}
