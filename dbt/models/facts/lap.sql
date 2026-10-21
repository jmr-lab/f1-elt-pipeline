{{ config(materialized='table', tags=['event', 'detail']) }}

SELECT
    id,
    session_entry_id,
    number,
    position,
    time,
    average_speed,
    is_entry_fastest_lap AS is_fastest_lap,
    is_deleted
FROM {{ source('jolpica', 'lap') }}
