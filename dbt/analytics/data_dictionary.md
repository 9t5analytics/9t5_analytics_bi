# Data Dictionary — Insurance Claims Platform

## Overview

This document describes every table in the source MySQL database (`cams_db`).
It covers the table's business purpose, category, columns, relationships,
PII status, and ingestion strategy.

---

## Table Categories

| Category | Description |
|---|---|
| **Core Entity** | Primary business objects — customers, vehicles, policies, claims |
| **Claim Detail** | Tables that store detailed information linked to a specific claim |
| **Dimension / Lookup** | Small reference tables used to decode IDs into human-readable values |
| **Financial** | Payment, subscription, and settlement tables |
| **Log / Audit** | Append-only tables recording system and user activity |
| **Notification** | Tables managing system notifications to staff |
| **Operational** | System tables used by the application but with low analytical value |
| **Staff / Admin** | Tables managing internal staff and platform administrators |

---

## Category Summary

| Category | Tables | Ingestion |
|---|---|---|
| Core Entity | tbl_organization, tbl_customer, tbl_customer_vehicle, tbl_customer_vehicle_insurance, tbl_customer_vehicle_driver | Full refresh |
| Claim Detail | tbl_claim, tbl_claim_driver, tbl_claim_files, tbl_claim_tasks, tbl_claim_status_log, tbl_thirdparty_car, tbl_thirdparty_owner, tbl_thirdparty_driver, tbl_police_detail, tbl_witness, tbl_vehicle_after_accident, tbl_settlement | Full refresh / Incremental |
| Dimension / Lookup | tbl_accidenttype, tbl_claimfault, tbl_claimstatus, tbl_insurance, tbl_membership_package, tbl_policy, tbl_policystatus, tbl_premiumperiod, tbl_valuationtype, tbl_vehicletype | Full refresh |
| Financial | tbl_payments, tbl_payment_links, tbl_payment_log, tbl_subscriptions, tbl_refunds, tbl_stripe_customers | Full refresh / Incremental |
| Log / Audit | tbl_audit_trail, tbl_activity_log, tbl_claim_status_log, tbl_payment_log | Incremental |
| Notification | tbl_notifications, tbl_notification_reads | Incremental |
| Operational | tbl_upload_tokens, tbl_vehicle_transfer, tbl_customer_documents, tbl_customer_notes | Full refresh |
| Staff / Admin | tbl_admin, tbl_platform_admin, tbl_staff_permissions | Full refresh (PII excluded) |

---

## Tables — Core Entity

---

### `tbl_organization`
**Category:** Core Entity — Dimension
**Description:** Top-level entity. Every customer, vehicle, policy, claim, and staff member
belongs to an organisation. This is the multi-tenant root of the entire data model.
**Rows:** ~4 | **Ingestion:** Full refresh | **PII:** ⚠️ Contains email, API keys, Stripe secrets

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Organisation ID |
| name | varchar | | Organisation name |
| logo | varchar | | Logo file path |
| email | varchar | UNI | ⚠️ PII — Organisation contact email |
| web_address | varchar | | Website URL |
| phone | varchar | | ⚠️ PII — Contact phone number |
| abn | varchar | | Australian Business Number — unique identifier |
| claim_prefix | varchar | UNI | Prefix used for claim numbers (e.g. CAM-) |
| policy_prefix | varchar | UNI | Prefix used for policy numbers |
| last_claim_seq | int | | Last claim sequence number — used for auto-numbering |
| last_policy_seq | int | | Last policy sequence number |
| resend_api_key | text | | ⚠️ SENSITIVE — Email API key. Exclude from analytics |
| stripe_publishable_key | varchar | | ⚠️ SENSITIVE — Stripe key. Exclude from analytics |
| stripe_secret_key | text | | ⚠️ SENSITIVE — Stripe secret. Exclude from analytics |
| stripe_webhook_secret | text | | ⚠️ SENSITIVE — Webhook secret. Exclude from analytics |
| isActive | tinyint | | 1 = active organisation |
| isDelete | tinyint | | Soft delete flag |
| address | varchar | | Organisation address |
| created_at | datetime | | Record creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | FK→tbl_admin | Admin who created this record |
| updated_by | int | | Admin who last updated |

**Analytics notes:** Exclude all API keys and Stripe credentials. Keep id, name, abn, isActive.

---

### `tbl_customer`
**Category:** Core Entity
**Description:** Stores all customer (policyholder) details. One customer can have
multiple vehicles. Linked to an organisation via organization_id.
**Rows:** ~1,537 | **Ingestion:** Full refresh | **PII:** ⚠️ Heavy PII

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Customer ID |
| organization_id | int | FK→tbl_organization | Which organisation this customer belongs to |
| firstName | varchar | | ⚠️ PII |
| lastName | varchar | | ⚠️ PII |
| email | varchar | UNI | ⚠️ PII |
| password | varchar | | ⚠️ Auth — exclude always |
| hashPassword | text | | ⚠️ Auth — exclude always |
| image | varchar | | Profile image path |
| phoneNumber | varchar | | ⚠️ PII |
| address | text | | ⚠️ PII |
| companyName | varchar | | Company name if applicable |
| postcode | varchar | | ⚠️ PII |
| state | varchar | | State |
| suburb | text | | ⚠️ PII |
| dob | varchar | | ⚠️ PII — Date of birth |
| licence | varchar | | ⚠️ PII — Licence number |
| licenceExpiry | varchar | | Licence expiry date |
| accreditationNo | varchar | | Accreditation number |
| licenceFrontImage | varchar | | Licence image path |
| licenceBackImage | varchar | | Licence image path |
| isLead | tinyint | | 1 = lead (not yet converted to customer) |
| isRead | tinyint | | Whether lead has been read |
| leadSource | varchar | | Where the lead came from |
| isActive | tinyint | | 1 = active customer |
| isLoginDetailSent | tinyint | | Whether login details were sent |
| statusReason | text | | Reason for current status |
| passwordRestToken | text | | ⚠️ Auth — exclude always |
| passwordRestTokenExpire_at | datetime | | Token expiry |
| type | tinyint | | 0 = member, 1 = rental |
| birthday_status | tinyint | | Birthday notification flag |
| stripe_customer_id | varchar | | Stripe customer reference |
| created_at | datetime | | Record creation timestamp |
| updated_at | datetime | | Last update timestamp |
| isDelete | tinyint | | Soft delete flag |
| created_by | int | FK→tbl_admin | Admin who created record |
| updated_by | int | | Admin who last updated |

**Analytics notes:** Keep only: id, organization_id, companyName, type, isLead,
isActive, leadSource, created_at, updated_at. Exclude all PII and auth columns.

---

### `tbl_customer_vehicle`
**Category:** Core Entity
**Description:** Stores vehicle details belonging to a customer. One customer can have
multiple vehicles. Vehicles are identified by registration number (regoNumber).
**Rows:** ~4,202 | **Ingestion:** Full refresh | **PII:** Low

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Vehicle ID |
| customer_id | int | FK→tbl_customer | Owner of this vehicle |
| organization_id | int | FK→tbl_organization | Organisation context |
| regoNumber | varchar | UNI | Vehicle registration number |
| maker | varchar | | Vehicle manufacturer |
| model | varchar | | Vehicle model |
| year | varchar | | Manufacturing year |
| bodyType | int | FK→tbl_vehicletype | Body type (sedan, SUV, etc.) |
| color | varchar | | Vehicle colour |
| state | varchar | | Registration state |
| vin | varchar | | Vehicle Identification Number |
| engineNo | varchar | | Engine number |
| vehiclePriceMore | tinyint | | Vehicle price flag |
| token_sign | varchar | | Signature token |
| signature | varchar | | Acceptance signature |
| acceptance_firstname | varchar | | Acceptance form first name |
| acceptance_lastname | varchar | | Acceptance form last name |
| acceptance_email | varchar | | ⚠️ PII — Acceptance form email |
| acceptance_date | datetime | | Date acceptance was signed |
| signed | enum | | Signature status |
| agreement_pdf | varchar | | Agreement document path |
| frontView | varchar | | Vehicle image — front |
| topView | varchar | | Vehicle image — top |
| leftView | varchar | | Vehicle image — left |
| rightView | varchar | | Vehicle image — right |
| rearView | varchar | | Vehicle image — rear |
| damagePicture | varchar | | Damage image path |
| vehicle_image_status | enum | | Status of vehicle image upload |
| statusReason | text | | Reason for current status |
| token_payment | varchar | | Payment token |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Record creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | FK→tbl_admin | Admin who created |
| created_by_member_id | int | FK→tbl_customer | Customer who created (self-service) |
| updated_by | int | | Admin who last updated |

---

### `tbl_customer_vehicle_insurance`
**Category:** Core Entity
**Description:** The policy table. Stores insurance policy details for each vehicle.
One vehicle has one active policy at a time. Central to the financial and claims analysis.
**Rows:** ~4,311 | **Ingestion:** Full refresh | **PII:** Low

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Policy ID |
| customer_id | int | FK→tbl_customer | Policy holder |
| organization_id | int | FK→tbl_organization | Organisation |
| vehicle_id | int | FK→tbl_customer_vehicle | Insured vehicle |
| startDate | date | | Policy start date |
| endDate | date | | Policy end date |
| nextDueDate | date | | Next payment due date |
| policyNumber | varchar | MUL | Policy number (human-readable) |
| policy_id | int | FK→tbl_policy | Policy type (comprehensive / third party) |
| insurancetype_id | int | FK→tbl_insurance | Insurance cover type |
| premium | float | | Premium amount |
| premiumperiod_id | int | FK→tbl_premiumperiod | Payment frequency |
| excess | float | | Excess amount |
| valuationtype_id | int | FK→tbl_valuationtype | Valuation method (agreed / market) |
| valueInsured | varchar | | Insured value |
| pdf | varchar | | Policy document path (mostly empty) |
| policystatus_id | int | FK→tbl_policystatus | Current policy status |
| insurance_package | int | | Insurance package reference |
| statusReason | text | | Reason for status change |
| notes | text | | Additional notes |
| expiry_status | int | | 1 = expired |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Record creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | FK→tbl_admin | Admin who created |
| created_by_member_id | int | | Customer self-service reference |
| updated_by | int | | Admin who last updated |

---

### `tbl_customer_vehicle_driver`
**Category:** Core Entity
**Description:** Stores approved driver details for a vehicle. One vehicle can have
multiple approved drivers. Contains PII — treat like tbl_customer.
**Rows:** ~5,522 | **Ingestion:** Full refresh | **PII:** ⚠️ Heavy PII

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Driver record ID |
| customer_id | int | FK→tbl_customer | Customer this driver belongs to |
| vehicle_id | int | FK→tbl_customer_vehicle | Vehicle this driver is approved for |
| firstName | varchar | | ⚠️ PII |
| lastName | varchar | | ⚠️ PII |
| email | varchar | | ⚠️ PII |
| phoneNumber | varchar | | ⚠️ PII |
| address | text | | ⚠️ PII |
| suburb | text | | ⚠️ PII |
| postcode | varchar | | ⚠️ PII |
| state | varchar | | State |
| dob | varchar | | ⚠️ PII — Date of birth |
| licence | varchar | | ⚠️ PII — Licence number |
| licenceExpiry | varchar | | Licence expiry |
| licenceFrontImage | varchar | | Image path |
| licenceBackImage | varchar | | Image path |
| statusReason | text | | Status reason |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Record creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | FK→tbl_admin | Admin who created |
| created_by_member_id | int | | Customer self-service reference |
| updated_by | int | | Admin who last updated |

**Analytics notes:** For analytics keep only: id, customer_id, vehicle_id, state,
isDelete, created_at, updated_at. Exclude all PII.

---

## Tables — Claim Detail

---

### `tbl_claim`
**Category:** Claim Detail — Central Fact
**Description:** The central claim table. Every claim event is stored here with full
accident details. This is the most important analytical table in the platform.
Connected to organisation and customer directly.
**Rows:** ~847 | **Ingestion:** Full refresh | **PII:** Low (accident details, no personal info)

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Claim ID |
| vehicle_id | int | FK→tbl_customer_vehicle | Vehicle involved in claim |
| customer_id | int | FK→tbl_customer | Customer making the claim |
| organization_id | int | FK→tbl_organization | Organisation |
| accidentType_id | int | FK→tbl_accidenttype | Type of accident |
| claim_faultId | int | FK→tbl_claimfault | Fault determination |
| claim_date | date | | Date claim was lodged |
| claim_source | varchar | | How claim was submitted (Admin/Customer/Website) |
| claim_whatHappen | text | | Description of what happened |
| claim_accidentPlace | varchar | | Where accident occurred |
| claim_vehicleLocation | varchar | | Vehicle location at time of accident |
| claim_street | varchar | | Street address of accident |
| claim_accidentDate | date | | Date of actual accident |
| claim_accidentTime | varchar | | Time of accident |
| claim_vehiclePreExitingDamage | varchar | | Pre-existing damage description |
| claim_roadSurface | varchar | | Road surface (Dry/Wet/Loose) |
| claim_numberOfCarsInvolved | varchar | | Number of vehicles involved |
| claim_inAccidentTheInsuredVehicleWas | varchar | | Vehicle state (Stationary/Moving/Speeding) |
| claim_damageMyCarImage | text | | Damage image paths |
| claim_damageOtherCarImage | text | | Other car damage images |
| claim_signImage | varchar | | Signature image |
| fileFolder | varchar | | File storage folder path |
| claimNumber | varchar | UNI | Human-readable claim number (e.g. CAM-001) |
| oldClaimNumber | varchar | | Previous claim number if migrated |
| claimstatus_id | int | FK→tbl_claimstatus | Current claim status (1 = Open) |
| statusReason | text | | Reason for current status |
| claim_certificate | varchar | | Certificate document path |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Claim creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | FK→tbl_admin | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_claim_driver`
**Category:** Claim Detail
**Description:** Details of the insured driver at the time of the accident (our driver,
not the third party). Contains PII — exclude personal details from analytics.
**Rows:** ~807 | **Ingestion:** Full refresh | **PII:** ⚠️ Heavy PII

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Record ID |
| claim_id | int | FK→tbl_claim | Associated claim |
| driver_firstName | varchar | | ⚠️ PII |
| driver_lastName | varchar | | ⚠️ PII |
| driver_email | varchar | | ⚠️ PII |
| driver_phoneNumber | varchar | | ⚠️ PII |
| driver_address | varchar | | ⚠️ PII |
| driver_suburb | varchar | | ⚠️ PII |
| driver_state | varchar | | State |
| driver_dob | varchar | | ⚠️ PII — Date of birth |
| driver_postcode | varchar | | ⚠️ PII |
| driver_licenceNo | varchar | | ⚠️ PII — Licence number |
| driver_licenceExpiry | varchar | | Licence expiry |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

**Analytics notes:** Keep only: id, claim_id, driver_state, isDelete, created_at.

---

### `tbl_claim_status_log`
**Category:** Log / Audit
**Description:** Records every status change and comment on a claim. This is the
primary activity log for claim workflow — extremely valuable for analytics.
Append-only — status entries are never edited after creation.
**Rows:** ~20,823 | **Ingestion:** Incremental (created_at) | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Log entry ID |
| claim_id | varchar | FK→tbl_claim | Associated claim |
| status | varchar | | Status value at time of entry |
| description | text | | Staff comment or note |
| created_at | datetime | | When this status entry was created |
| created_by | int | FK→tbl_admin | Staff who created |
| isDelete | tinyint | | Soft delete flag |

---

### `tbl_claim_tasks`
**Category:** Claim Detail
**Description:** Tasks assigned to staff members related to a specific claim.
New table — tracks task assignment, due dates, and completion.
**Rows:** ~6 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Task ID |
| claim_id | int | FK→tbl_claim | Claim this task relates to |
| assigned_to | int | FK→tbl_admin | Staff member assigned the task |
| assigned_by | int | FK→tbl_admin | Staff member who assigned the task |
| note | text | | Task description |
| due_date | datetime | | Task due date |
| status | varchar | | Task status |
| completed_at | datetime | | When task was completed |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| updated_by | int | | Staff who last updated |

---

### `tbl_claim_files`
**Category:** Claim Detail
**Description:** Tracks files uploaded against a claim (damage images, documents,
sketches, signatures). Stores file URLs — actual files are in cloud storage.
**Rows:** ~1,218 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | File record ID |
| claim_id | int | FK→tbl_claim | Associated claim |
| file_type | enum | | Type of file uploaded |
| file_url | text | | URL of the stored file |
| created_at | timestamp | | Upload timestamp |

---

### `tbl_thirdparty_car`
**Category:** Claim Detail
**Description:** Vehicle details of the third party involved in an accident.
One claim can have one third party vehicle record.
**Rows:** ~798 | **Ingestion:** Full refresh | **PII:** None (vehicle details only)

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Record ID |
| claim_id | int | FK→tbl_claim | Associated claim |
| thirdparty_maker | varchar | | Vehicle manufacturer |
| thirdparty_model | varchar | | Vehicle model |
| thirdparty_year | varchar | | Vehicle year |
| thirdparty_isInsured | varchar | | Whether third party vehicle is insured |
| thirdparty_rego | varchar | | Registration number |
| thirdparty_insuranceCompany | varchar | | Third party insurer name |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_thirdparty_owner`
**Category:** Claim Detail
**Description:** Owner details of the third party vehicle. Contains PII.
**Rows:** ~740 | **Ingestion:** Full refresh | **PII:** ⚠️ PII

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Record ID |
| claim_id | int | FK→tbl_claim | Associated claim |
| thirdparty_carId | int | FK→tbl_thirdparty_car | The third party vehicle |
| owner_firstName | varchar | | ⚠️ PII |
| owner_lastName | varchar | | ⚠️ PII |
| owner_phoneNumber | varchar | | ⚠️ PII |
| owner_address | text | | ⚠️ PII |
| owner_suburb | text | | ⚠️ PII |
| owner_state | varchar | | State |
| owner_postcode | varchar | | ⚠️ PII |
| owner_dob | varchar | | ⚠️ PII |
| owner_licenceNo | varchar | | ⚠️ PII |
| owner_email | varchar | | ⚠️ PII |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_thirdparty_driver`
**Category:** Claim Detail
**Description:** Driver details of the third party vehicle at time of accident. Contains PII.
**Rows:** ~641 | **Ingestion:** Full refresh | **PII:** ⚠️ PII

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Record ID |
| claim_id | int | FK→tbl_claim | Associated claim |
| thirdparty_carId | int | FK→tbl_thirdparty_car | The third party vehicle |
| driver_firstName | varchar | | ⚠️ PII |
| driver_lastName | varchar | | ⚠️ PII |
| driver_phoneNumber | varchar | | ⚠️ PII |
| driver_address | text | | ⚠️ PII |
| driver_suburb | text | | ⚠️ PII |
| driver_state | varchar | | State |
| driver_dob | varchar | | ⚠️ PII |
| driver_postcode | varchar | | ⚠️ PII |
| driver_licenceNo | varchar | | ⚠️ PII |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_police_detail`
**Category:** Claim Detail
**Description:** Police report details if the customer lodged a police complaint.
**Rows:** ~506 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Record ID |
| claim_id | int | FK→tbl_claim | Associated claim |
| police_reported | varchar | | Whether police were reported to |
| police_officerFirstName | varchar | | Officer first name |
| police_officerLastName | varchar | | Officer last name |
| police_station | varchar | | Police station name |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_witness`
**Category:** Claim Detail
**Description:** Witness details for a claim accident. Minimal PII — only name and phone.
**Rows:** ~440 | **Ingestion:** Full refresh | **PII:** Low

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Record ID |
| claim_id | int | FK→tbl_claim | Associated claim |
| witness_name | varchar | | ⚠️ PII — Witness full name |
| witness_phoneNumber | varchar | | ⚠️ PII — Witness phone |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_vehicle_after_accident`
**Category:** Claim Detail
**Description:** Post-accident vehicle disposition — whether the vehicle was towed,
where it was towed, and whether it's repairable. Used for settlement analysis.
**Rows:** ~493 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Record ID |
| claim_id | int | FK→tbl_claim | Associated claim |
| accident_vehicleTowed | varchar | | Whether vehicle was towed (Yes/No) |
| accident_whereTowed | varchar | | Where vehicle was towed to |
| accident_vehicleTowedBy | varchar | | Who towed the vehicle |
| accident_vehicleRepairable | varchar | | Whether vehicle is repairable |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_settlement`
**Category:** Claim Detail — Financial
**Description:** Financial settlement details for a claim. Tracks demand, offer,
accepted amount, and breakdown of costs. Critical for financial analytics.
**Rows:** ~1 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Settlement ID |
| claim_id | int | FK→tbl_claim | Associated claim |
| demand | decimal | | Amount demanded |
| offered | decimal | | Amount offered |
| accepted | decimal | | Amount accepted |
| towing_cost | decimal | | Towing cost |
| rental_cost | decimal | | Rental car cost |
| assessment_fees | decimal | | Assessment fees |
| lawyers_fees | decimal | | Legal fees |
| interest_rate | decimal | | Interest rate applied |
| other_amount | decimal | | Other costs |
| paid_settlement | decimal | | Amount actually paid |
| description | varchar | | Settlement notes |
| total_amount | decimal | | Total settlement amount |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

## Tables — Dimension / Lookup

---

### `tbl_accidenttype`
**Category:** Dimension / Lookup
**Description:** Defines accident types available for a claim. Each organisation can
configure their own accident types. Also controls which form fields are shown.
**Rows:** ~7 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Accident type ID |
| organization_id | int | FK→tbl_organization | Organisation-specific |
| name | varchar | | Accident type name |
| image | varchar | | Display image |
| accident | tinyint | | Show accident section flag |
| thirdParty | tinyint | | Show third party section flag |
| myCarImages | tinyint | | Show my car images flag |
| otherCarImages | tinyint | | Show other car images flag |
| documents | tinyint | | Show documents flag |
| whatHappen | tinyint | | Show what happened flag |
| damageYourCar | tinyint | | Show damage flag |
| policeDetails | tinyint | | Show police details flag |
| vehicleAfterAccident | tinyint | | Show post-accident flag |
| witness | tinyint | | Show witness flag |
| isDelete | tinyint | | Soft delete flag |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_claimfault`
**Category:** Dimension / Lookup
**Description:** Defines fault determination options for a claim (e.g. At Fault, Not At Fault, Disputed).
**Rows:** ~5 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Fault type ID |
| organization_id | int | FK→tbl_organization | Organisation-specific |
| name | varchar | | Fault type name |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_claimstatus`
**Category:** Dimension / Lookup
**Description:** Defines available claim status values per organisation (e.g. Open, Closed,
Under Review). Each status has a colour for UI display.
**Rows:** ~21 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Status ID |
| organization_id | int | FK→tbl_organization | Organisation-specific |
| name | varchar | | Status name |
| color | varchar | | UI display colour (hex code) |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_insurance`
**Category:** Dimension / Lookup
**Description:** Defines insurance cover types available per organisation (e.g. Rideshare,
Taxi Cover, VAN & TRUCK, Uber Eats).
**Rows:** ~7 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Insurance type ID |
| organization_id | int | FK→tbl_organization | Organisation-specific |
| name | varchar | | Insurance type name |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_membership_package`
**Category:** Dimension / Lookup
**Description:** Defines membership/insurance packages per organisation. Links an
insurance type to a policy type with pricing (amount, excess, premium period).
This is effectively a product catalogue.
**Rows:** ~13 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Package ID |
| organization_id | int | FK→tbl_organization | Organisation-specific |
| insurance_id | int | FK→tbl_insurance | Insurance cover type |
| insurance_package | varchar | | Package identifier |
| policyType | int | FK→tbl_policy | Policy type |
| name | varchar | | Package name |
| amount | float | | Package price |
| min_premium | float | | Minimum premium amount |
| excess | float | | Excess amount |
| permiumperiod_id | int | FK→tbl_premiumperiod | Payment frequency |
| description | text | | Package description |
| card_image | varchar | | Card front image |
| card_image_back | varchar | | Card back image |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_policy`
**Category:** Dimension / Lookup
**Description:** Defines policy types (e.g. Comprehensive, Third Party).
**Rows:** ~3 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Policy type ID |
| organization_id | int | FK→tbl_organization | Organisation-specific |
| name | varchar | | Policy type name |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_policystatus`
**Category:** Dimension / Lookup
**Description:** Defines policy status values (e.g. Active, Cancelled, OnHold).
**Rows:** ~3 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Policy status ID |
| organization_id | int | FK→tbl_organization | Organisation-specific |
| name | varchar | | Status name |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_premiumperiod`
**Category:** Dimension / Lookup
**Description:** Defines premium payment frequencies (e.g. Monthly, Quarterly, Yearly).
Includes number of days and months for each period.
**Rows:** ~5 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Period ID |
| organization_id | int | FK→tbl_organization | Organisation-specific |
| name | varchar | | Period name |
| days | varchar | | Number of days in period |
| months | int | | Number of months in period |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_valuationtype`
**Category:** Dimension / Lookup
**Description:** Defines vehicle valuation methods (e.g. Agreed Value, Market Value).
**Rows:** ~3 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Valuation type ID |
| organization_id | int | FK→tbl_organization | Organisation-specific |
| name | varchar | | Valuation type name |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_vehicletype`
**Category:** Dimension / Lookup
**Description:** Defines vehicle body types (e.g. Sedan, SUV, Hatchback).
**Rows:** ~8 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Vehicle type ID |
| organization_id | int | FK→tbl_organization | Organisation-specific |
| name | varchar | | Body type name |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

## Tables — Financial

---

### `tbl_payments`
**Category:** Financial
**Description:** Records individual payment transactions processed through Stripe.
Includes payment method, status, and receipt URL.
**Rows:** ~240 | **Ingestion:** Full refresh | **PII:** None (no card details stored)

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Payment ID |
| customer_id | int | FK→tbl_customer | Customer who paid |
| organization_id | int | FK→tbl_organization | Organisation |
| vehicle_id | int | FK→tbl_customer_vehicle | Vehicle payment relates to |
| policy_id | int | FK→tbl_policy | Policy type |
| subscription_id | int | FK→tbl_subscriptions | Associated subscription |
| stripe_payment_intent_id | varchar | | Stripe payment reference |
| stripe_invoice_id | varchar | | Stripe invoice reference |
| amount | decimal | | Payment amount |
| currency | varchar | | Currency (AUD) |
| payment_method | enum | | How payment was made |
| status | enum | | Payment status (succeeded/failed/pending) |
| receipt_url | text | | Stripe receipt URL |
| created_at | datetime | | Payment timestamp |
| updated_at | datetime | | Last update timestamp |
| updated_by | int | | Staff who last updated |

---

### `tbl_payment_links`
**Category:** Financial
**Description:** Payment links sent to customers via Stripe. Tracks the link lifecycle
from creation through to payment completion.
**Rows:** ~129 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Payment link ID |
| customer_id | int | FK→tbl_customer | Customer the link was sent to |
| organization_id | int | FK→tbl_organization | Organisation |
| vehicle_id | int | FK→tbl_customer_vehicle | Vehicle |
| insurance_id | int | FK→tbl_insurance | Insurance type |
| token | varchar | UNI | Unique link token |
| stripe_session_id | varchar | | Stripe checkout session |
| payment_url | text | | The actual payment URL |
| amount | decimal | | Amount to be paid |
| currency | varchar | | Currency |
| status | enum | | Link status (pending/paid/expired) |
| expires_at | datetime | | Link expiry time |
| paid_at | datetime | | When payment was completed |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | FK→tbl_admin | Staff who sent the link |
| updated_by | int | | Staff who last updated |

---

### `tbl_payment_log`
**Category:** Financial — Log
**Description:** Logs all payment-related actions performed by admin and system
(e.g. subscription cancelled, payment retried). Append-only.
**Rows:** ~475 | **Ingestion:** Incremental (created_at) | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Log entry ID |
| admin_id | int | FK→tbl_admin | Staff who performed action |
| customer_id | int | FK→tbl_customer | Affected customer |
| subscription_id | int | FK→tbl_subscriptions | Affected subscription |
| payment_id | int | FK→tbl_payments | Affected payment |
| action | varchar | | Action performed |
| description | text | | Action description |
| amount | decimal | | Amount involved |
| created_at | datetime | | Action timestamp |

---

### `tbl_subscriptions`
**Category:** Financial
**Description:** Active and historical subscriptions per vehicle. Tracks Stripe
subscription lifecycle including current period and cancellation status.
**Rows:** ~122 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Subscription ID |
| customer_id | int | FK→tbl_customer | Customer |
| organization_id | int | FK→tbl_organization | Organisation |
| vehicle_id | int | FK→tbl_customer_vehicle | Vehicle |
| insurance_id | int | FK→tbl_insurance | Insurance type |
| stripe_subscription_id | varchar | UNI | Stripe reference |
| stripe_customer_id | varchar | | Stripe customer reference |
| stripe_price_id | varchar | | Stripe price/plan reference |
| stripe_session_id | varchar | | Stripe session reference |
| status | enum | | Subscription status |
| current_period_start | datetime | | Current billing period start |
| current_period_end | datetime | | Current billing period end |
| cancel_at_period_end | tinyint | | 1 = cancels at end of period |
| pause_resume_at | datetime | | Scheduled pause/resume date |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| updated_by | int | | Staff who last updated |

---

### `tbl_refunds`
**Category:** Financial
**Description:** Records refunds processed against payments.
**Rows:** ~2 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Refund ID |
| payment_id | int | FK→tbl_payments | Original payment |
| customer_id | int | FK→tbl_customer | Customer |
| organization_id | int | FK→tbl_organization | Organisation |
| stripe_refund_id | varchar | UNI | Stripe refund reference |
| amount | decimal | | Refund amount |
| reason | varchar | | Refund reason |
| status | enum | | Refund status |
| refunded_by | int | FK→tbl_admin | Staff who processed refund |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| updated_by | int | | Staff who last updated |

---

### `tbl_stripe_customers`
**Category:** Financial — Operational
**Description:** Maps internal customers to their Stripe customer IDs.
Used by the application for payment processing.
**Rows:** ~51 | **Ingestion:** Full refresh | **PII:** ⚠️ Contains email

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Record ID |
| organization_id | int | FK→tbl_organization | Organisation |
| customer_id | int | FK→tbl_customer | Internal customer |
| stripe_customer_id | varchar | UNI | Stripe customer ID |
| email | varchar | | ⚠️ PII — Customer email in Stripe |
| name | varchar | | Customer name in Stripe |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| updated_by | int | | Staff who last updated |

---

## Tables — Log / Audit

---

### `tbl_audit_trail`
**Category:** Log / Audit
**Description:** Comprehensive audit log recording every significant action performed
by any actor (admin, customer, system) on any entity. Stores before/after changes
as JSON. Critical for compliance and security analysis.
**Rows:** ~2,227 | **Ingestion:** Incremental (created_at) | **PII:** ⚠️ actor_name stored

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Audit entry ID |
| actor_type | enum | | Who performed the action (admin/customer/system) |
| actor_id | int | | ID of the actor |
| actor_name | varchar | | ⚠️ PII — Name of the actor |
| action | varchar | | Action performed (created/updated/deleted) |
| entity_type | varchar | | What type of record was affected |
| entity_id | int | | ID of the affected record |
| entity_label | varchar | | Human-readable label of affected record |
| changes | json | | JSON object showing before/after values |
| ip_address | varchar | | IP address of actor |
| created_at | datetime | | When action occurred |
| customer_id | int | FK→tbl_customer | Affected customer if applicable |

**Analytics notes:** Extremely valuable for understanding user behaviour and system
changes. The `changes` JSON column allows tracking what specifically changed.
For analytics exclude actor_name and ip_address.

---

### `tbl_activity_log`
**Category:** Log / Audit
**Description:** Records admin staff activity — who sent links, when, to whom.
Used for employee performance analytics. Append-only.
**Rows:** ~127 | **Ingestion:** Incremental (created_at) | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Log entry ID |
| admin_id | int | FK→tbl_admin | Staff member who performed action |
| customer_id | int | FK→tbl_customer | Customer involved |
| entity_type | varchar | | Type of entity involved |
| entity_id | int | | ID of the entity |
| action | varchar | | Action performed |
| description | text | | Action description |
| ip_address | varchar | | Staff IP address |
| created_at | datetime | | Action timestamp |

---

## Tables — Notification

---

### `tbl_notifications`
**Category:** Notification
**Description:** System notifications generated for staff (e.g. new claim submitted,
payment received). Linked to a related entity.
**Rows:** ~218 | **Ingestion:** Incremental (created_at) | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Notification ID |
| type | varchar | | Notification type |
| title | varchar | | Notification title |
| message | text | | Notification message body |
| link | varchar | | Deep link URL in the application |
| is_read | tinyint | | Whether notification has been read |
| read_at | datetime | | When notification was read |
| created_at | datetime | | Creation timestamp |
| related_id | int | | ID of the related entity |
| related_type | varchar | | Type of the related entity |

---

### `tbl_notification_reads`
**Category:** Notification
**Description:** Tracks which staff members have read which notifications.
Junction table between notifications and admins.
**Rows:** ~129 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Record ID |
| notification_id | int | FK→tbl_notifications | The notification |
| admin_id | int | FK→tbl_admin | Staff who read it |
| read_at | datetime | | When it was read |

---

## Tables — Operational

---

### `tbl_vehicle_transfer`
**Category:** Operational
**Description:** Records when a vehicle is transferred from one customer to another.
New table — tracks vehicle ownership changes.
**Rows:** ~39 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Transfer ID |
| vehicle_id | int | FK→tbl_customer_vehicle | Vehicle being transferred |
| from_customer_id | int | FK→tbl_customer | Previous owner |
| to_customer_id | int | FK→tbl_customer | New owner |
| insurance_id | int | FK→tbl_insurance | Insurance type transferred |
| rego_number | varchar | | Vehicle registration number |
| transfer_date | datetime | | Transfer date |
| transfer_reason | text | | Reason for transfer |
| transferred_by | int | FK→tbl_admin | Staff who processed transfer |
| notes | text | | Additional notes |
| created_at | datetime | | Record creation timestamp |

---

### `tbl_customer_documents`
**Category:** Operational
**Description:** Tracks documents uploaded for a customer or their vehicle
(not claim-related — general customer documents).
**Rows:** ~7 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Document ID |
| customer_id | int | FK→tbl_customer | Customer |
| vehicle_id | int | FK→tbl_customer_vehicle | Vehicle (optional) |
| doc_type | varchar | | Document type |
| file_url | varchar | | File URL |
| uploaded_by | varchar | | Who uploaded the document |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Upload timestamp |
| updated_at | datetime | | Last update timestamp |
| updated_by | int | | Staff who last updated |

---

### `tbl_customer_notes`
**Category:** Operational
**Description:** Internal notes added by staff about a customer. Currently empty.
**Rows:** 0 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Note ID |
| customer_id | int | FK→tbl_customer | Customer |
| title | varchar | | Note title |
| description | text | | Note content |
| isDelete | tinyint | | Soft delete flag |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| created_by | int | | Staff who created |
| updated_by | int | | Staff who last updated |

---

### `tbl_upload_tokens`
**Category:** Operational — Skip Ingestion
**Description:** Temporary tokens used for secure file uploads. These are short-lived
operational tokens with no analytical value. Do not ingest.
**Rows:** ~5 | **Ingestion:** ❌ Skip | **PII:** None

---

## Tables — Staff / Admin

---

### `tbl_admin`
**Category:** Staff / Admin
**Description:** Staff members (admins) who have access to the platform.
Each admin belongs to an organisation and has a role.
Contains heavy PII and auth credentials — exclude all sensitive columns.
**Rows:** ~21 | **Ingestion:** Full refresh (selected columns only) | **PII:** ⚠️ Heavy PII + Auth

| Column | Type | Key | Analytics? | Description |
|---|---|---|---|---|
| id | int | PK | ✅ Keep | Staff ID |
| organization_id | int | FK | ✅ Keep | Organisation |
| firstName | varchar | | ❌ Exclude | ⚠️ PII |
| lastName | varchar | | ❌ Exclude | ⚠️ PII |
| email | varchar | UNI | ❌ Exclude | ⚠️ PII |
| password | varchar | | ❌ Exclude | ⚠️ Auth |
| hashPassword | text | | ❌ Exclude | ⚠️ Auth |
| image | varchar | | ❌ Exclude | Profile image |
| phoneNumber | varchar | | ❌ Exclude | ⚠️ PII |
| address | text | | ❌ Exclude | ⚠️ PII |
| postcode | varchar | | ❌ Exclude | ⚠️ PII |
| state | varchar | | ❌ Exclude | ⚠️ PII |
| role | enum | | ✅ Keep | Staff role |
| permission | text | | ✅ Keep | Permission level |
| login_token | varchar | | ❌ Exclude | ⚠️ Auth token |
| authentication_code | varchar | | ❌ Exclude | ⚠️ Auth |
| fcm_token | text | | ❌ Exclude | ⚠️ Push notification token |
| isActive | tinyint | | ✅ Keep | Active status |
| isDelete | tinyint | | ✅ Keep | Soft delete |
| created_at | datetime | | ✅ Keep | Creation timestamp |
| last_login | datetime | | ✅ Keep | Last login time |
| updated_at | datetime | | ✅ Keep | Last update |
| updated_by | int | | ❌ Exclude | Low value |
| endTime | varchar | | ❌ Exclude | Low value |

---

### `tbl_platform_admin`
**Category:** Staff / Admin
**Description:** Super-admin users who manage the platform above the organisation level.
These are the platform owners/operators. Not organisation-specific.
Contains PII and auth credentials — exclude sensitive columns.
**Rows:** ~1 | **Ingestion:** Full refresh (selected columns only) | **PII:** ⚠️ PII + Auth

| Column | Type | Key | Analytics? | Description |
|---|---|---|---|---|
| id | int | PK | ✅ Keep | Platform admin ID |
| firstName | varchar | | ❌ Exclude | ⚠️ PII |
| lastName | varchar | | ❌ Exclude | ⚠️ PII |
| email | varchar | UNI | ❌ Exclude | ⚠️ PII |
| hashPassword | text | | ❌ Exclude | ⚠️ Auth |
| image | varchar | | ❌ Exclude | Profile image |
| phoneNumber | varchar | | ❌ Exclude | ⚠️ PII |
| login_token | varchar | | ❌ Exclude | ⚠️ Auth token |
| isActive | tinyint | | ✅ Keep | Active status |
| isDelete | tinyint | | ✅ Keep | Soft delete |
| last_login | datetime | | ✅ Keep | Last login |
| created_at | datetime | | ✅ Keep | Creation timestamp |
| updated_at | datetime | | ✅ Keep | Last update |
| updated_by | int | | ❌ Exclude | Low value |

---

### `tbl_staff_permissions`
**Category:** Staff / Admin — Operational
**Description:** Stores granular permission settings for each staff member.
The permission field is a serialised JSON/text of permission flags.
Low direct analytical value — used to understand access patterns.
**Rows:** ~17 | **Ingestion:** Full refresh | **PII:** None

| Column | Type | Key | Description |
|---|---|---|---|
| id | int | PK | Record ID |
| admin_id | int | FK→tbl_admin UNI | Staff member (one record per admin) |
| permission | text | | Serialised permission flags |
| created_at | datetime | | Creation timestamp |
| updated_at | datetime | | Last update timestamp |
| updated_by | int | | Staff who last updated |

---

## Entity Relationship Summary

```
tbl_organization
    ├── tbl_admin (organization_id)
    ├── tbl_customer (organization_id)
    │       ├── tbl_customer_vehicle (customer_id)
    │       │       ├── tbl_customer_vehicle_insurance (vehicle_id)
    │       │       │       ├── tbl_subscriptions (vehicle_id)
    │       │       │       └── tbl_payments (vehicle_id)
    │       │       ├── tbl_customer_vehicle_driver (vehicle_id)
    │       │       ├── tbl_vehicle_transfer (vehicle_id)
    │       │       └── tbl_claim (vehicle_id)
    │       │               ├── tbl_claim_status_log (claim_id)
    │       │               ├── tbl_claim_driver (claim_id)
    │       │               ├── tbl_claim_files (claim_id)
    │       │               ├── tbl_claim_tasks (claim_id)
    │       │               ├── tbl_thirdparty_car (claim_id)
    │       │               │       ├── tbl_thirdparty_owner (thirdparty_carId)
    │       │               │       └── tbl_thirdparty_driver (thirdparty_carId)
    │       │               ├── tbl_police_detail (claim_id)
    │       │               ├── tbl_witness (claim_id)
    │       │               ├── tbl_vehicle_after_accident (claim_id)
    │       │               └── tbl_settlement (claim_id)
    │       └── tbl_customer_documents (customer_id)
    ├── tbl_accidenttype (organization_id)
    ├── tbl_claimfault (organization_id)
    ├── tbl_claimstatus (organization_id)
    ├── tbl_insurance (organization_id)
    │       └── tbl_membership_package (insurance_id)
    ├── tbl_policy (organization_id)
    ├── tbl_policystatus (organization_id)
    ├── tbl_premiumperiod (organization_id)
    ├── tbl_valuationtype (organization_id)
    └── tbl_vehicletype (organization_id)
```

---

## Ingestion Strategy Summary

| Table | Strategy | Watermark Column | Notes |
|---|---|---|---|
| tbl_organization | Full refresh | — | Small, changes infrequently |
| tbl_customer | Full refresh | updated_at | PII excluded |
| tbl_customer_vehicle | Full refresh | updated_at | |
| tbl_customer_vehicle_insurance | Full refresh | updated_at | |
| tbl_customer_vehicle_driver | Full refresh | updated_at | PII excluded |
| tbl_claim | Full refresh | updated_at | Central fact table |
| tbl_claim_driver | Full refresh | updated_at | PII excluded |
| tbl_claim_files | Full refresh | — | |
| tbl_claim_tasks | Full refresh | updated_at | New table |
| tbl_claim_status_log | Incremental | created_at | Append-only |
| tbl_thirdparty_car | Full refresh | updated_at | |
| tbl_thirdparty_owner | Full refresh | updated_at | PII excluded |
| tbl_thirdparty_driver | Full refresh | updated_at | PII excluded |
| tbl_police_detail | Full refresh | updated_at | |
| tbl_witness | Full refresh | updated_at | |
| tbl_vehicle_after_accident | Full refresh | updated_at | |
| tbl_settlement | Full refresh | updated_at | |
| tbl_payments | Full refresh | updated_at | |
| tbl_payment_links | Full refresh | updated_at | |
| tbl_payment_log | Incremental | created_at | Append-only |
| tbl_subscriptions | Full refresh | updated_at | |
| tbl_refunds | Full refresh | updated_at | |
| tbl_stripe_customers | Full refresh | updated_at | PII excluded |
| tbl_audit_trail | Incremental | created_at | Append-only, new table |
| tbl_activity_log | Incremental | created_at | Append-only |
| tbl_notifications | Incremental | created_at | New table |
| tbl_notification_reads | Full refresh | — | Small junction table |
| tbl_vehicle_transfer | Full refresh | — | New table |
| tbl_customer_documents | Full refresh | updated_at | New table |
| tbl_customer_notes | Full refresh | updated_at | New, currently empty |
| tbl_accidenttype | Full refresh | updated_at | Lookup |
| tbl_claimfault | Full refresh | updated_at | Lookup |
| tbl_claimstatus | Full refresh | updated_at | Lookup |
| tbl_insurance | Full refresh | updated_at | Lookup |
| tbl_membership_package | Full refresh | updated_at | Lookup — new table |
| tbl_policy | Full refresh | updated_at | Lookup |
| tbl_policystatus | Full refresh | updated_at | Lookup |
| tbl_premiumperiod | Full refresh | updated_at | Lookup |
| tbl_valuationtype | Full refresh | updated_at | Lookup |
| tbl_vehicletype | Full refresh | updated_at | Lookup |
| tbl_admin | Full refresh | — | PII + auth excluded |
| tbl_platform_admin | Full refresh | — | PII + auth excluded |
| tbl_staff_permissions | Full refresh | — | |
| tbl_upload_tokens | ❌ Skip | — | Operational only |
