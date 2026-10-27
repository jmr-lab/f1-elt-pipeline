{{ config(materialized='table') }}

SELECT
    id,
    session_id,
    round_entry_id,
    grid,
    position,
    points,
    laps_completed,
    fastest_lap_rank,
    time,
    detail,
    status,
    is_classified,
    is_eligible_for_points
FROM {{ source('jolpica', 'session_entry') }}
