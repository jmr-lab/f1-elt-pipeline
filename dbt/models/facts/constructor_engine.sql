{{ config(
    materialized='table',
    tags=['history']
) }}

WITH mapping AS (
    SELECT 'ferrari'  AS constructor_ref, 'ferrari'  AS engine_ref, 2005 AS first_year, 2025 AS last_year
    UNION ALL
    SELECT 'mercedes', 'mercedes', 2010, 2025
),

joined AS (
    SELECT
        c.id AS constructor_id,
        s.id AS season_id,
        e.id AS engine_id,
        CAST(NULL AS TEXT) AS engine_ref_override
    FROM mapping m
    JOIN {{ ref('constructor') }} c ON c.reference = m.constructor_ref
    JOIN {{ ref('engine') }}       e ON e.reference = m.engine_ref
    JOIN {{ ref('season') }}       s ON s.year BETWEEN m.first_year AND m.last_year
)

SELECT
    ROW_NUMBER() OVER (ORDER BY constructor_id, season_id) AS id,
    constructor_id,
    season_id,
    engine_id,
    engine_ref_override
FROM joined
