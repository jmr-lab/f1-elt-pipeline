{{ config(
    materialized='table',
    tags=['championship', 'standings']
) }}

SELECT
    dc.id,
    COALESCE(
        dc.season_id,
        (SELECT s.id FROM {{ source('jolpica', 'season') }} s WHERE s.year = dc.year)
    ) AS season_id,
    dc.year,
    dc.driver_id,
    dc.round_id,
    dc.position,
    dc.points,
    dc.win_count,
    dc.highest_finish,
    dc.is_eligible,
    dc.adjustment_type,
    dc.session_id,
    dc.session_number,
    dc.round_number
FROM {{ source('jolpica', 'driver_championship') }} dc
WHERE dc.round_id IS NOT NULL
  AND COALESCE(
          dc.season_id,
          (SELECT s.id FROM {{ source('jolpica', 'season') }} s WHERE s.year = dc.year)
      ) IS NOT NULL
