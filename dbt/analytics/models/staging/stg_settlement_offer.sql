with source as (
    select * from {{ source('raw', 'tbl_settlement') }}
),
 
renamed as (
    select
        id                          as offer_id,
        settlement_id,
        party_id,
        organization_id,
        offer_number,
        amount                      as offer_amount,
        cast(has_gst as bool)       as has_gst,
        gst_rate,
        cast(is_accepted as bool)   as is_accepted,
        accepted_at,
        created_at
    from source
    where isDelete = 0
)
 
select * from renamed