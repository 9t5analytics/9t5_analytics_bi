with source as (
    select * from {{ source('raw', 'tbl_audit_trail') }}
),

renamed as (
    select
        id                                      as audit_id,
        actor_type,
        cast(actor_id as int64)                 as actor_id,
        action,
        entity_type,
        cast(entity_id as int64)                as entity_id,
        entity_label,
        changes,
        cast(customer_id as int64)              as customer_id,
        safe.timestamp_seconds(created_at)      as created_at

    from source
)

select * from renamed