{{ config(materialized='table') }}

-- One row per team per season, carrying the nationality (country_id) and the
-- team name as it appeared that season. Corrections from the seed override
-- both the source country_code and the source name for the affected seasons.
WITH base AS (
    SELECT DISTINCT
        season_id,
        team_id
    FROM {{ ref('team_driver') }}
    WHERE season_id IS NOT NULL
      AND team_id IS NOT NULL
),

resolved AS (
    SELECT
        b.season_id,
        b.team_id,
        COALESCE(corr_country.id, src_country.id) AS country_id,
        -- Blank name in the seed means "keep the source name".
        COALESCE(NULLIF(corr.name, ''), t.name) AS name
    FROM base b
    LEFT JOIN {{ ref('team') }} t
        ON b.team_id = t.id
    LEFT JOIN {{ ref('countries') }} src_country
        ON t.country_code = src_country.country_code
    LEFT JOIN {{ ref('team_nationality_corrections') }} corr
        ON corr.team_id = b.team_id
       AND b.season_id BETWEEN corr.season_id_start AND corr.season_id_end
    LEFT JOIN {{ ref('countries') }} corr_country
        ON corr.country_code = corr_country.country_code
)

SELECT
    ROW_NUMBER() OVER (ORDER BY season_id, team_id) AS id,
    season_id,
    team_id,
    country_id,
    name
FROM resolved
