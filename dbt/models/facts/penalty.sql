{{ config(
    materialized='table',
    tags=['event', 'detail']
) }}

SELECT
    id,
    earned_id AS earned_session_entry_id,
    served_id AS served_session_entry_id,
    position,
    license_points,
    is_time_served_in_pit,
    time
FROM {{ source('jolpica', 'penalty') }}
