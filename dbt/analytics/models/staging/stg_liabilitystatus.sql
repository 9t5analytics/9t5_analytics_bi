with source as (
    select * from {{ source('analytics', 'tbl_liabilitystatus') }}
),
 
renamed as (
    select
        id              as liability_status_id,
        organization_id,
        name            as liability_status_name,
        created_at,
        updated_at
    from source
    where isDelete = 0
)
 
select * from renamed