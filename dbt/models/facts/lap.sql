{{ config(
    materialized='table',
    tags=['event', 'detail']
) }}

WITH src AS (
    SELECT * FROM {{ source('jolpica', 'lap') }}
),

numbered AS (
    SELECT
        l.id,
        l.session_entry_id,
        CASE
            WHEN l.number IS NOT NULL THEN l.number
            ELSE (SELECT COALESCE(MAX(l2.number), 0) FROM src l2 WHERE l2.session_entry_id = l.session_entry_id)
                 + ROW_NUMBER() OVER (PARTITION BY l.session_entry_id ORDER BY l.id)
        END AS number,
        l.position,
        l.time,
        l.average_speed,
        l.is_entry_fastest_lap AS is_fastest_lap,
        l.is_deleted
    FROM src l
)

SELECT * FROM numbered
