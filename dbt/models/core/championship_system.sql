{{ config(materialized='table') }}

SELECT
    id,
    name,
    reference,
    driver_best_results,
    team_best_results,
    driver_season_split,
    team_season_split,
    team_points_per_session,
    eligibility
FROM {{ source('jolpica', 'championship_system') }}
