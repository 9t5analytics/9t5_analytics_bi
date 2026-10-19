with source as (
    select * from {{ source('raw', 'tbl_settlement') }}
),
 
renamed as (
    select
        id                          as party_id,
        settlement_id,
        organization_id,
        party_type,
        party_number,
        label                       as party_label,
        car_status,
        cast(lawyer_involved as bool) as lawyer_involved,
        lawyer_id,
        lawyer_payment_status,
        lawyer_amount,
        lawyer_installment_months,
        excess_payment_status,
        excess_amount,
        excess_installment_months,
        payout_amount,
        settled_amount,
        settlementstatus_id         as settlement_status_id,
        additional_comment,
        created_at,
        updated_at
    from source
    where isDelete = 0
)
 
select * from renamed