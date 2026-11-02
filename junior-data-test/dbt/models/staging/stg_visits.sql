-- cleaning visits table.

with source as (

    select * from {{ ref('raw_visits') }}

),

cleaned as (

    select
        -- Transform all ids to int
        cast(visit_id as integer)                                  as visit_id,
        cast(intervention_point_id as integer)                     as intervention_point_id,
        cast(route_id as integer)                                  as route_id,
        cast(campaign_id as integer)                               as campaign_id,

        -- Clean visit_status column. Trim spaces, text in uppercase, change null or empty values to 'UNKNOWN'
        coalesce(nullif(upper(trim(visit_status)), ''), 'UNKNOWN') as initial_visit_status,

        -- Transform all dates to date type
        cast(visit_date as date)                                   as visit_date,
        cast(created_at as date)                                   as created_at,
        cast(updated_at as date)                                   as updated_at



    from source

)

select
    visit_id,
    intervention_point_id,
    route_id,
    campaign_id,

    -- Check if status is in the list ['OK', 'INCID', 'INFO', 'NOVIS', 'UNKNOWN']. Else, change the value to 'UNKNOWN'.
    case
        when initial_visit_status not in ('OK', 'INCID', 'INFO', 'NOVIS', 'UNKNOWN') then 'UNKNOWN'
        else initial_visit_status
    end as visit_status,
        
    visit_date,
    created_at,
    updated_at

from cleaned
