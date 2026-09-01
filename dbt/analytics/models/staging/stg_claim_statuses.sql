with source as (
    select * from {{ source('raw', 'tbl_claimstatus') }}
),

renamed as (
    select
        id                                      as claim_status_id,
        organization_id,
        name                                    as claim_status_name,
        color                                   as status_color,
        cast(isDelete as bool)                  as is_deleted,
        safe.timestamp_seconds(created_at)      as created_at,
        safe.timestamp_seconds(updated_at)      as updated_at

    from source
    where isDelete = 0
)

select * from renamed