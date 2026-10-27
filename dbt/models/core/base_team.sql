{{ config(materialized='table') }}

SELECT
    id,
    name
FROM {{ source('jolpica', 'base_team') }}
