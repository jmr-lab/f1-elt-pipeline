{{ config(
    materialized='table',
    tags=['dimension', 'core']
) }}

SELECT
    id,
    reference,
    abbreviation,
    forename,
    surname,
    permanent_car_number,
    date_of_birth,
    nationality AS birth_country,
    wikipedia
FROM {{ source('jolpica', 'driver') }}
