{{ config(materialized='table') }}

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
