{{ config(
    materialized='table',
    tags=['dimension', 'core']
) }}

SELECT
    id,
    name,
    reference,
    locality,
    country,
    country_code,
    latitude,
    longitude,
    altitude,
    wikipedia
FROM {{ source('jolpica', 'circuit') }}
