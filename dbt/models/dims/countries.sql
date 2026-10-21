{{ config(
    materialized='table',
    tags=['dimension', 'lookup']
) }}

SELECT
    rowid              AS id,
    country_code,
    country,
    CAST(NULL AS TEXT) AS iso_alpha3,
    CAST(NULL AS TEXT) AS continent
FROM {{ source('jolpica', '_countries_lookup') }}
