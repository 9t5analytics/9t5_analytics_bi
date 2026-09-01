with source as (
    select * from {{ source('raw', 'tbl_claim') }}
),

renamed as (
    select
        id                                          as claim_id,
        cast(vehicle_id as int64)                   as vehicle_id,
        cast(customer_id as int64)                  as customer_id,
        cast(organization_id as int64)              as organization_id,
        cast(accidentType_id as int64)              as accident_type_id,
        cast(claim_faultId as int64)                as claim_fault_id,
        cast(claimstatus_id as int64)               as claim_status_id,
        claimNumber                                 as claim_number,
        cast(claim_date as date)                    as claim_date,
        claim_source,
        claim_whatHappen                            as claim_description,
        claim_accidentPlace                         as accident_place,
        claim_vehicleLocation                       as vehicle_location,
        claim_street                                as accident_street,
        cast(claim_accidentDate as date)            as accident_date,
        claim_accidentTime                          as accident_time,
        claim_vehiclePreExitingDamage               as pre_existing_damage,
        claim_roadSurface                           as road_surface,
        claim_numberOfCarsInvolved                  as cars_involved,
        claim_inAccidentTheInsuredVehicleWas        as vehicle_was,
        statusReason                                as status_reason,
        cast(isDelete as bool)                      as is_deleted,
        safe.timestamp_seconds(created_at)          as created_at,
        safe.timestamp_seconds(updated_at)          as updated_at,
        cast(created_by as int64)                   as created_by,
        cast(updated_by as int64)                   as updated_by

    from source
    where isDelete = 0
)

select * from renamed