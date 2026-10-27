{{ config(materialized='table') }}

SELECT
    id,
    earned_id,
    served_id,
    position,
    license_points,
    is_time_served_in_pit,
    time
FROM {{ source('jolpica', 'penalty') }}
