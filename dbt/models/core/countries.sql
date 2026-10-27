{{ config(materialized='table') }}

SELECT
    ROW_NUMBER() OVER (ORDER BY country_code) AS id,
    country_code,
    country
FROM {{ source('jolpica', '_countries_lookup') }}
