{{ config(
    materialized='table',
    tags=['event', 'core']
) }}

SELECT
    id,
    season_id,
    team_id AS constructor_id,
    driver_id,
    role
FROM {{ source('jolpica', 'team_driver') }}
