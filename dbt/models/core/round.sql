{{ config(materialized='table') }}

SELECT
    id,
    season_id,
    circuit_id,
    number,
    race_number,
    name,
    -- STRING -> DATE
    date(date) AS date,
    is_cancelled,
    wikipedia
FROM {{ source('jolpica', 'round') }}
