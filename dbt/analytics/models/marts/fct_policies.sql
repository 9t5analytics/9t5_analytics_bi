with policies as (
    select * from {{ ref('stg_policies') }}
),

policy_statuses as (
    select * from {{ ref('stg_policy_statuses') }}
),

insurance_types as (
    select * from {{ ref('stg_insurance_types') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

final as (
    select
        p.policy_id,
        p.customer_id,
        p.vehicle_id,
        p.policy_number,
        p.start_date,
        p.end_date,
        p.next_due_date,
        p.premium,
        p.excess,
        p.insurance_package,
        p.status_reason,
        p.is_expired,
        p.created_at,

        -- Organisation (critical for row-level security)
        c.organization_id,

        -- Lookup values
        ps.policy_status_name,
        it.insurance_type_name

    from policies p
    left join customers c
        on p.customer_id = c.customer_id
    left join policy_statuses ps
        on p.policy_status_id = ps.policy_status_id
    left join insurance_types it
        on p.insurance_type_id = it.insurance_type_id
)

select * from final