{{ config(
    materialized='table',
    tags=['dimension', 'core']
) }}

SELECT
    id,
    name,
    api_id
FROM {{ source('jolpica', 'base_team') }}
