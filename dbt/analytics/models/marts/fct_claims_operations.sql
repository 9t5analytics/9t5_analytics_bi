{{ config(
    materialized='table',
    partition_by={
        'field': 'claim_date',
        'data_type': 'date'
    }
) }}

with claims as (
    select * from {{ ref('stg_claims') }}
),

vehicles as (
    select
        vehicle_id,
        territory,
        rego_number,
        vehicle_maker,
        vehicle_model,
        vehicle_year
    from {{ ref('stg_vehicles') }}
),

claim_statuses as (
    select
        claim_status_id,
        organization_id,
        claim_status_name,
        status_color
    from {{ ref('stg_claim_statuses') }}
),

claim_faults as (
    select
        claim_fault_id,
        organization_id,
        claim_fault_name
    from {{ ref('stg_claimfault') }}
),

organizations as (
    select
        organization_id,
        organization_name
    from {{ ref('stg_organizations') }}
),

-- Latest status log entry per claim (for last activity date)
latest_activity as (
    select
        claim_id,
        status_name                                 as last_activity_status,
        created_at                                  as last_activity_at,
        total_changes                               as total_status_changes
    from (
        select
            claim_id,
            status_name,
            created_at,
            count(*) over (partition by claim_id)   as total_changes,
            row_number() over (
                partition by claim_id
                order by created_at desc
            )                                       as rn
        from {{ ref('stg_claim_status_log') }}
    )
    where rn = 1
),

-- When the current status first started (for days stuck calculation)
current_status_start as (
    select
        sl.claim_id,
        sl.current_status_name,
        min(log.created_at)                         as status_started_at
    from (
        -- Get current status per claim
        select
            claim_id,
            status_name                             as current_status_name
        from (
            select
                claim_id,
                status_name,
                row_number() over (
                    partition by claim_id
                    order by created_at desc
                )                                   as rn
            from {{ ref('stg_claim_status_log') }}
        )
        where rn = 1
    ) sl
    inner join {{ ref('stg_claim_status_log') }} log
        on sl.claim_id = log.claim_id
        and sl.current_status_name = log.status_name
    group by sl.claim_id, sl.current_status_name
),

-- Date when DOCUMENT SENT TO LAWER/INSURANCE was first logged per claim
document_sent as (
    select
        claim_id,
        min(created_at)                             as document_sent_date
    from {{ ref('stg_claim_status_log') }}
    where status_name = 'DOCUMENT SENT TO LAWER/INSURANCE'
    group by claim_id
),

final as (
    select
        -- Claim identifiers
        c.claim_id,
        c.claim_number,
        c.organization_id,
        o.organization_name,

        -- Territory
        v.territory,
        v.rego_number,
        v.vehicle_maker,
        v.vehicle_model,
        v.vehicle_year,

        -- Claim details
        c.claim_date,
        c.claim_source,
        c.accident_place,
        c.accident_date,
        c.road_surface,
        c.cars_involved,
        c.vehicle_was,
        c.pre_existing_damage,

        -- Primary status dimension (Active / Closed)
        case
            when cs.claim_status_name = 'CLOSED' then 'Closed'
            else 'Active'
        end                                         as primary_status,

        -- Sub status (operational detail)
        cs.claim_status_name                        as sub_status,
        cs.status_color,

        -- Fault determination
        cf.claim_fault_name,

        -- Last logged status from status log
        la.last_activity_status                     as last_logged_status,
        la.last_activity_at,
        la.total_status_changes,

        -- Current status started
        css.status_started_at,

        -- Aging Calculations

        -- 1. Days since last activity (last ANY entry in status log)
        date_diff(
            current_date(),
            date(la.last_activity_at),
            day
        )                                           as days_since_last_activity,

        -- 2. Days stuck in current status (since current status first started)
        date_diff(
            current_date(),
            date(css.status_started_at),
            day
        )                                           as days_stuck_in_status,

        -- 3. Days since opened
        case
            when c.claim_date >= '2020-01-01'
            then date_diff(current_date(), c.claim_date, day)
            else null
        end                                         as days_since_opened,

        -- 4. Days since document sent to lawyer
        coalesce(
            cast(
                date_diff(current_date(), date(ds.document_sent_date), day)
                as string
            ),
            'Not Sent to Lawyer'
        )                                           as days_since_document_sent_to_lawyer,

        -- Timestamps
        c.created_at,
        c.updated_at

    from claims c

    left join vehicles v
        on c.vehicle_id = v.vehicle_id

    left join claim_statuses cs
        on c.claim_status_id = cs.claim_status_id
        and c.organization_id = cs.organization_id

    left join claim_faults cf
        on c.claim_fault_id = cf.claim_fault_id
        and c.organization_id = cf.organization_id

    left join organizations o
        on c.organization_id = o.organization_id

    left join latest_activity la
        on cast(c.claim_id as string) = la.claim_id

    left join current_status_start css
        on cast(c.claim_id as string) = css.claim_id

    left join document_sent ds
        on cast(c.claim_id as string) = ds.claim_id
)

select * from final