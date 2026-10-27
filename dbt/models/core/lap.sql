{{ config(materialized='table') }}

SELECT
    id,
    session_entry_id,
    number,
    position,
    time,
    average_speed,
    is_entry_fastest_lap,
    is_deleted
FROM {{ source('jolpica', 'lap') }}
