{{ config(materialized='table') }}

SELECT
    id,
    round_id,
    type,
    number,
    -- STRING -> TIMESTAMP. datetime() converts to UTC and normalises the
    -- format; values it cannot parse come back as NULL.
    datetime(timestamp) AS timestamp,
    timezone,
    scheduled_laps,
    point_system_id,
    is_cancelled,
    has_time_data
FROM {{ source('jolpica', 'session') }}
