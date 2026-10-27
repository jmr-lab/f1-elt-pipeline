{{ config(materialized='table') }}

-- One row per driver per season, carrying the nationality (country_id) that
-- applied during that season. Corrections from the seed override the source
-- country_code for the affected season ranges.
WITH base AS (
    SELECT DISTINCT
        season_id,
        driver_id
    FROM {{ ref('team_driver') }}
    WHERE season_id IS NOT NULL
      AND driver_id IS NOT NULL
),

resolved AS (
    SELECT
        b.season_id,
        b.driver_id,
        -- Correction wins; otherwise fall back to the driver's own country_code.
        COALESCE(corr_country.id, src_country.id) AS country_id
    FROM base b
    LEFT JOIN {{ ref('driver') }} d
        ON b.driver_id = d.id
    LEFT JOIN {{ ref('countries') }} src_country
        ON d.country_code = src_country.country_code
    LEFT JOIN {{ ref('driver_nationality_corrections') }} corr
        ON corr.driver_id = b.driver_id
       AND b.season_id BETWEEN corr.season_id_start AND corr.season_id_end
    LEFT JOIN {{ ref('countries') }} corr_country
        ON corr.country_code = corr_country.country_code
)

SELECT
    ROW_NUMBER() OVER (ORDER BY season_id, driver_id) AS id,
    season_id,
    driver_id,
    country_id
FROM resolved
