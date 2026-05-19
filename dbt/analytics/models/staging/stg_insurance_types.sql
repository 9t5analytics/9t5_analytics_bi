with source as (
    select * from {{ source('raw', 'tbl_insurance') }}
),

renamed as (
    select
        id              as insurance_type_id,
        trim(name)      as insurance_type_name,
        cast(isDelete as bool)      as is_deleted,
        timestamp_seconds(created_at) as created_at
        

    from source
    where isDelete = 0
)

select * from renamed