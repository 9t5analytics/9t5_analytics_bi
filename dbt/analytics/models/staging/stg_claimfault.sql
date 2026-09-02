with source as (
    select * from {{ source('raw', 'tbl_claimfault') }}
),

renamed as (
    select
        id                                      as claim_fault_id,
        organization_id,
        name                                    as claim_fault_name,
        cast(isDelete as bool)                  as is_deleted,
        safe.timestamp_seconds(created_at)      as created_at,
        safe.timestamp_seconds(updated_at)      as updated_at

    from source
    where isDelete = 0
    and id not in (4, 5)
)

select * from renamed