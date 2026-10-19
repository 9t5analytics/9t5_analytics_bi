with source as (
    select * from {{ source('analytics', 'tbl_lawyer') }}
),
 
renamed as (
    select
        id              as lawyer_id,
        organization_id,
        name            as lawyer_name,
        created_at,
        updated_at
    from source
    where isDelete = 0
)
 
select * from renamed