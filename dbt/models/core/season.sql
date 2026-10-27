{{ config(materialized='table') }}

SELECT
    id,
    year,
    championship_system_id,
    wikipedia
FROM {{ source('jolpica', 'season') }}
