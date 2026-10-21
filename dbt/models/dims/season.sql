{{ config(
    materialized='table',
    tags=['dimension', 'core']
) }}

SELECT
    id,
    year,
    championship_system_id,
    wikipedia
FROM {{ source('jolpica', 'season') }}
