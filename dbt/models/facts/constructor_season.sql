{{ config(
    materialized='table',
    tags=['history']
) }}

WITH aggregated AS (
    SELECT
        td.team_id   AS constructor_id,
        td.season_id,
        COALESCE(t.name, 'Unknown') AS name,
        COALESCE(t.nationality, 'Unknown') AS nationality,
        t.country_code,
        t.base_team_id AS constructor_base_id
    FROM {{ source('jolpica', 'team_driver') }} td
    JOIN {{ source('jolpica', 'team') }} t ON td.team_id = t.id
    GROUP BY td.team_id, td.season_id
),

numbered AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY constructor_id, season_id) AS id,
        constructor_id,
        season_id,
        name,
        nationality,
        country_code,
        constructor_base_id
    FROM aggregated
)

SELECT * FROM numbered
