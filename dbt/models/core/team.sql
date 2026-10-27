{{ config(materialized='table') }}

SELECT
    id,
    name,
    reference,
    country_code,
    base_team_id,
    primary_color,
    wikipedia
FROM {{ source('jolpica', 'team') }}
