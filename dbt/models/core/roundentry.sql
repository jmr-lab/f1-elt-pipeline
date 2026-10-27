{{ config(materialized='table') }}

SELECT
    id,
    round_id,
    team_driver_id,
    car_number
FROM {{ source('jolpica', 'roundentry') }}
