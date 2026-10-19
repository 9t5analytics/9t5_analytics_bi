with source as (
    select * from {{ source('raw', 'tbl_settlement') }}
),
 
renamed as (
    select
        id              as cost_id,
        settlement_id,
        party_id,
        organization_id,
        feetype_id      as fee_type_id,
        driver_number,
        amount,
        created_at,
        updated_at
    from source
)
 
select * from renamed