with source as (
    select * from {{ source('raw', 'tbl_claim_status_log') }}
),

renamed as (
    select
        id                                          as status_log_id,
        cast(claim_id as string)                    as claim_id,
        status                                      as status_name,
        description                                 as status_note,
        cast(created_by as int64)                   as created_by,
        safe.timestamp_seconds(created_at)          as created_at,
        cast(isDelete as bool)                      as is_deleted

    from source
    where isDelete = 0
)

select * from renamed