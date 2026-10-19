with source as (
    select * from {{ source('raw', 'tbl_settlement') }}
),
 
renamed as (
    select
        id                  as installment_id,
        settlement_id,
        organization_id,
        installment_no,
        amount,
        due_date,
        payment_status,
        paid_at,
        created_at,
        updated_at
    from source
    where isDelete = 0
)
 
select * from renamed