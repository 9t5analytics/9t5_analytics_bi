with source as (
    select * from {{ source('raw', 'tbl_customer') }}
),

renamed as (
    select
        id                                  as customer_id,
        organization_id,
        cast(isActive as bool)              as is_active,
        cast(isDelete as bool)              as is_deleted,
        cast(isLead as bool)                as is_lead,
        type                                as customer_type,
        created_by,
        safe.timestamp_seconds(created_at)  as created_at

    from source
    where isDelete = 0
)

select * from renamed