{{ config(
    materialized='table',
    tags=['event', 'core']
) }}

WITH src AS (
    SELECT * FROM {{ source('jolpica', 'round') }}
),

numbered AS (
    SELECT
        r.id,
        r.season_id,
        r.circuit_id,
        CASE
            WHEN r.number IS NOT NULL THEN r.number
            ELSE (SELECT COALESCE(MAX(r2.number), 0) FROM src r2 WHERE r2.season_id = r.season_id)
                 + ROW_NUMBER() OVER (PARTITION BY r.season_id ORDER BY r.date, r.id)
        END AS number,
        COALESCE(r.name, 'Unknown round') AS name,
        r.date,
        COALESCE(r.is_cancelled, 0) AS is_cancelled,
        r.wikipedia
    FROM src r
)

SELECT * FROM numbered
