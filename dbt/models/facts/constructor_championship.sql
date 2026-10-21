{{ config(
    materialized='table',
    tags=['championship', 'standings']
) }}

SELECT
    tc.id,
    COALESCE(
        tc.season_id,
        (SELECT s.id FROM {{ source('jolpica', 'season') }} s WHERE s.year = tc.year)
    ) AS season_id,
    tc.year,
    tc.team_id AS constructor_id,
    tc.round_id,
    tc.position,
    tc.points,
    tc.win_count,
    tc.highest_finish,
    tc.is_eligible,
    tc.adjustment_type,
    tc.session_id,
    tc.session_number,
    tc.round_number
FROM {{ source('jolpica', 'team_championship') }} tc
WHERE tc.round_id IS NOT NULL
  AND COALESCE(
          tc.season_id,
          (SELECT s.id FROM {{ source('jolpica', 'season') }} s WHERE s.year = tc.year)
      ) IS NOT NULL
