with source as (
    select * from {{ source('raw', 'tbl_settlementstatus') }}
),
 
renamed as (
    select
        id              as settlement_status_id,
        organization_id,
        name            as settlement_status_name,
        created_at,
        updated_at
    from source
    where isDelete = 0
)
 
select * from renamed