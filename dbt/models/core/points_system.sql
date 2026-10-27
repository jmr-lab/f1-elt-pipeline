{{ config(materialized='table') }}

SELECT
    id,
    name,
    reference,
    partial,
    driver_position_points,
    driver_fastest_lap,
    team_position_points,
    team_fastest_lap,
    shared_drive,
    is_double_points
FROM {{ source('jolpica', 'points_system') }}
