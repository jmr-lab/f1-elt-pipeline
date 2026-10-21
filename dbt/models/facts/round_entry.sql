{{ config(
    materialized='table',
    tags=['event', 'core']
) }}

SELECT
    id,
    round_id,
    team_driver_id AS constructor_driver_id,
    car_number
FROM {{ source('jolpica', 'roundentry') }}
