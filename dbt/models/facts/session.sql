{{ config(
    materialized='table',
    tags=['event', 'core']
) }}

SELECT
    id,
    round_id,
    type,
    number,
    timestamp,
    timezone,
    scheduled_laps,
    point_system_id,
    COALESCE(is_cancelled, 0) AS is_cancelled,
    has_time_data
FROM {{ source('jolpica', 'session') }}
