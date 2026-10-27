{{ config(materialized='table') }}

SELECT
    id,
    season_id,
    year,
    team_id,
    round_id,
    position,
    points,
    win_count,
    highest_finish,
    is_eligible,
    adjustment_type,
    session_id,
    session_number,
    round_number
FROM {{ source('jolpica', 'team_championship') }}
