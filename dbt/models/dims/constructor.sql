{{ config(
    materialized='table',
    tags=['dimension', 'core']
) }}

SELECT
    id,
    name,
    reference,
    base_team_id AS constructor_base_id,
    primary_color,
    wikipedia
FROM {{ source('jolpica', 'team') }}
