{{ config(materialized='table') }}

SELECT
    id,
    session_entry_id,
    lap_id,
    number,
    duration,
    local_timestamp
FROM {{ source('jolpica', 'pit_stop') }}
