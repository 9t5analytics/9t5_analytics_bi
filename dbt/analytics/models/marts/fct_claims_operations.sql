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

latest_status as (
    select
        claim_id,
        status_name                                 as current_status_name,
        created_at                                  as last_status_change_at,
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

organizations as (
    select
        organization_id,
        organization_name
    from {{ ref('stg_organizations') }}
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

        -- Official status from tbl_claimstatus
        cs.claim_status_name                        as official_status,
        cs.status_color,

        -- Fault determination
        cf.claim_fault_name,

        -- Last logged status from status log
        ls.current_status_name                      as last_logged_status,
        ls.last_status_change_at,
        ls.total_status_changes,

        -- Last activity = last status log entry
        ls.last_status_change_at                    as last_activity_at,
        ls.total_status_changes                     as total_activities,

        -- Calculated metrics
        case
            when c.claim_date >= '2020-01-01'
            then date_diff(current_date(), c.claim_date, day)
            else null
        end                                         as days_since_opened,

        date_diff(
            current_date(),
            date(ls.last_status_change_at),
            day
        )                                           as days_in_current_status,

        date_diff(
            current_date(),
            date(ls.last_status_change_at),
            day
        )                                           as days_since_last_activity,

        -- Timestamps
        c.created_at,
        c.updated_at

    from claims c

    left join vehicles v
        on c.vehicle_id = v.vehicle_id

    left join claim_statuses cs
        on c.claim_status_id = cs.claim_status_id
        and c.organization_id = cs.organization_id

    left join latest_status ls
        on cast(c.claim_id as string) = ls.claim_id

    left join organizations o
        on c.organization_id = o.organization_id

    left join claim_faults cf
        on c.claim_fault_id = cf.claim_fault_id
        and c.organization_id = cf.organization_id
)

select * from final