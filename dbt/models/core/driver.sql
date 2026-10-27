{{ config(materialized='table') }}

SELECT
    id,
    reference,
    abbreviation,
    forename,
    surname,
    country_code,
    -- STRING -> DATE. SQLite's date() normalises ISO-8601 text and
    -- returns NULL for anything it cannot parse.
    date(date_of_birth) AS date_of_birth,
    permanent_car_number,
    wikipedia
FROM {{ source('jolpica', 'driver') }}
