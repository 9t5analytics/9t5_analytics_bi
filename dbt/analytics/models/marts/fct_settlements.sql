{{ config(
    materialized='table',
    partition_by={
        'field': 'settlement_created_at',
        'data_type': 'timestamp'
    }
) }}

with settlements as (
    select * from {{ ref('stg_settlement') }}
),

parties as (
    select * from {{ ref('stg_settlement_party') }}
),

settlement_status as (
    select settlement_status_id, organization_id, settlement_status_name
    from {{ ref('stg_settlementstatus') }}
),

liability_status as (
    select liability_status_id, organization_id, liability_status_name
    from {{ ref('stg_liabilitystatus') }}
),

lawyers as (
    select lawyer_id, organization_id, lawyer_name
    from {{ ref('stg_lawyer') }}
),

organizations as (
    select organization_id, organization_name
    from {{ ref('stg_organizations') }}
),

-- Total costs per settlement
settlement_costs as (
    select
        settlement_id,
        sum(amount)     as total_costs,
        count(*)        as cost_line_items
    from {{ ref('stg_settlement_cost') }}
    group by settlement_id
),

-- Latest accepted offer per party
latest_offer as (
    select
        settlement_id,
        party_id,
        max(offer_amount) as highest_offer_amount,
        countif(is_accepted) as accepted_offers,
        count(*)            as total_offers
    from {{ ref('stg_settlement_offer') }}
    group by settlement_id, party_id
),

-- One row per settlement party (the grain of this table)
final as (
    select
        -- Identifiers
        p.party_id,
        p.settlement_id,
        s.claim_id,
        p.organization_id,
        o.organization_name,

        -- Party details
        p.party_type,
        p.party_number,
        p.party_label,
        p.car_status,

        -- Settlement header info
        s.our_car_status,
        s.other_car_status,
        s.cars_involved,
        s.is_finalized,
        s.finalized_at,
        s.has_proposed_offer,
        s.court_proceeding,
        s.court_name,
        s.court_case_number,
        s.court_lodge_date,
        s.court_due_date,

        -- Statuses
        ss.settlement_status_name,
        ls.liability_status_name,

        -- Lawyer
        p.lawyer_involved,
        lw.lawyer_name,
        p.lawyer_payment_status,
        p.lawyer_amount,
        p.lawyer_installment_months,

        -- Excess
        p.excess_payment_status,
        p.excess_amount,
        p.excess_installment_months,

        -- Financials
        p.payout_amount,
        p.settled_amount                        as party_settled_amount,
        s.settled_amount                        as total_settled_amount,
        sc.total_costs,
        sc.cost_line_items,

        -- Offers
        lo.total_offers,
        lo.accepted_offers,
        lo.highest_offer_amount,

        -- Aging
        date_diff(current_date(), date(s.created_at), day) as days_since_settlement_opened,
        case
            when s.is_finalized then 'Finalised'
            else 'Open'
        end                                     as settlement_stage,

        -- Timestamps
        s.created_at                            as settlement_created_at,
        s.updated_at                            as settlement_updated_at

    from parties p

    inner join settlements s
        on p.settlement_id = s.settlement_id

    left join settlement_status ss
        on p.settlement_status_id = ss.settlement_status_id
        and p.organization_id = ss.organization_id

    left join liability_status ls
        on s.liability_status_id = ls.liability_status_id
        and s.organization_id = ls.organization_id

    left join lawyers lw
        on p.lawyer_id = lw.lawyer_id
        and p.organization_id = lw.organization_id

    left join organizations o
        on p.organization_id = o.organization_id

    left join settlement_costs sc
        on p.settlement_id = sc.settlement_id

    left join latest_offer lo
        on p.settlement_id = lo.settlement_id
        and p.party_id = lo.party_id
)

select * from final