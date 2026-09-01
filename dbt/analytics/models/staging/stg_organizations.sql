with source as (
    select * from {{ source('raw', 'tbl_organization') }}
),

renamed as (
    select
        id                                      as organization_id,
        name                                    as organization_name,
        abn                                     as abn,
        claim_prefix,
        policy_prefix,
        cast(isActive as bool)                  as is_active,
        cast(isDelete as bool)                  as is_deleted,
        safe.timestamp_seconds(created_at)      as created_at,
        safe.timestamp_seconds(updated_at)      as updated_at

    from source
    where isDelete = 0
)

select * from renamed