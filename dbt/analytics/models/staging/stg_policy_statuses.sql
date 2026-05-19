with source as (
    select * from {{ source('raw', 'tbl_policystatus') }}
),

renamed as (
    select
        id              as policy_status_id,
        name            as policy_status_name,
        cast(isDelete as bool)      as is_deleted,
        timestamp_seconds(created_at) as created_at
        

    from source
    where isDelete = 0
)

select * from renamed