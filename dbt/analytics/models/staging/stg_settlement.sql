with source as (
    select * from {{ source('raw', 'tbl_settlement') }}
),
 
renamed as (
    select
        id                          as settlement_id,
        organization_id,
        claim_id,
        liability_status_id,
        settlementstatus_id         as settlement_status_id,
        lawyer_id,
 
        -- Owner details
        owner_first_name,
        owner_last_name,
 
        -- Car statuses
        our_car_status,
        other_car_status,
        cars_involved,
 
        -- Excess payment
        excess_payment_status,
        excess_payment_amount,
        excess_installment_months,
 
        -- Lawyer
        lawyer_payment_status,
        lawyer_amount,
        lawyer_installment_months,
 
        -- Settlement financials
        settled_amount,
 
        -- Court proceedings
        cast(court_proceeding as bool)  as court_proceeding,
        court_name,
        court_case_number,
        court_lodge_date,
        court_due_date,
        court_approved_by,
 
        -- Offer flag
        cast(has_proposed_offer as bool) as has_proposed_offer,
 
        -- Finalisation
        cast(is_finalized as bool)      as is_finalized,
        finalized_at,
 
        additional_comment,
        created_at,
        updated_at
    from source
    where isDelete = 0
)
 
select * from renamed