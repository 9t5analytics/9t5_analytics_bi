with source as (
    select * from {{ source('raw', 'tbl_customer_vehicle') }}
),

renamed as (
    select
        id                                      as vehicle_id,
        customer_id,
        organization_id,
        regoNumber                              as rego_number,
        maker                                  as vehicle_maker,
        model                                  as vehicle_model,
        year                                   as vehicle_year,
        bodyType                               as body_type_id,
        color                                  as vehicle_color,
        state                                  as territory,
        vin,
        cast(isDelete as bool)                 as is_deleted,
        safe.timestamp_seconds(created_at)     as created_at,
        safe.timestamp_seconds(updated_at)     as updated_at

    from source
    where isDelete = 0
)

select * from renamed