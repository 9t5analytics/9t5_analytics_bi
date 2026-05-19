with source as (
    select * from {{ source('raw', 'tbl_customer_vehicle_insurance') }}
),

renamed as (
    select
        id                                      as policy_id,
        customer_id,
        vehicle_id                              as vehicle_id,
        policy_id                               as policy_type_id,
        insurancetype_id                        as insurance_type_id,
        premiumperiod_id                        as premium_period_id,
        valuationtype_id                        as valuation_type_id,
        policystatus_id                         as policy_status_id,
        policyNumber                            as policy_number,
        cast(startDate as date)                 as start_date,
        cast(endDate as date)                   as end_date,
        cast(nextDueDate as date)               as next_due_date,
        cast(premium as numeric)                as premium,
        cast(excess as numeric)                 as excess,
        insurance_package,
        statusReason                            as status_reason,
        cast(expiry_status as bool)             as is_expired,
        cast(isDelete as bool)                  as is_deleted,
        created_by,
        safe.timestamp_seconds(created_at) as created_at

    from source
    where isDelete = 0
)

select * from renamed