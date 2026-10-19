
with source as (
    select * from {{ source('analytics', 'tbl_note') }}
),
 
renamed as (
    select
        id              as note_id,
        organization_id,
        entity_type,
        entity_id,
        body            as note_body,
        created_at,
        updated_at
    from source
    where isDelete = 0
)
 
select * from renamed