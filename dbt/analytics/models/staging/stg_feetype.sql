with source as (
    select * from {{ source('raw', 'tbl_feetype') }}
),
 
renamed as (
    select
        id          as fee_type_id,
        organization_id,
        name        as fee_type_name,
        created_at,
        updated_at
    from source
    where isDelete = 0
)
 
select * from renamed