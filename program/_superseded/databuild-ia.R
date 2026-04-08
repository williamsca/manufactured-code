# Build analysis file for FEMA Individual Assistance registrations
#
# Inputs:  $DATA_PATH/derived/fema.duckdb
#          derived/ecfr-windzone.csv
# Outputs: derived/ia-registrations.parquet
#
# The IA registrations do not report construction year.  This file keeps a
# registration-level sample for primary-residence wind disasters, merges the
# HUD wind-zone treatment at the damaged county, and leaves the treatment
# effect to be estimated from MH x treated-county variation.

rm(list = ls())
library(here)
library(DBI)
library(duckdb)

data_path <- Sys.getenv("DATA_PATH")
if (nchar(data_path) == 0) stop("DATA_PATH environment variable is not set.")

db_path <- file.path(data_path, "derived", "fema.duckdb")
if (!file.exists(db_path)) stop("Could not find DuckDB database: ", db_path)

windzone_path <- here("derived", "ecfr-windzone.csv")
out_path      <- here("derived", "ia-registrations.parquet")

db <- dbConnect(duckdb::duckdb(), db_path, read_only = TRUE)
on.exit(dbDisconnect(db, shutdown = TRUE), add = TRUE)

q <- function(x) as.character(dbQuoteString(db, x))

# Some older IA records have missing fips/censusGeoid but still include state
# and county labels.  Recover county FIPS from rows where FEMA supplied a FIPS
# for the same state-county label.
dbExecute(db, "
    create or replace temporary table ia_county_xwalk as
    select
        damagedStateAbbreviation,
        county,
        min(fips) as countyfp
    from ihp_registrations
    where fips is not null
      and damagedStateAbbreviation is not null
      and county is not null
    group by 1, 2
    having count(distinct fips) = 1
")

dbExecute(db, sprintf("
    create or replace temporary table windzone as
    select
        countyfp,
        cast(wind_zone as integer) as wind_zone
    from read_csv_auto(%s, all_varchar = true)
", q(windzone_path)))

sql_build <- "
    select
        coalesce(ia.fips, x.countyfp) as countyfp,
        left(coalesce(ia.fips, x.countyfp), 2) as statefp,
        ia.damagedStateAbbreviation as state,
        ia.county,
        ia.disasterNumber as disaster_number,
        ia.incidentTypeCode as incident_type,
        ia.declarationDate as declaration_date,
        extract(year from ia.declarationDate)::integer as year_declared,
        ia.damagedZipCode as zip,
        ia.applicantAge as applicant_age,
        ia.householdComposition as household_composition,
        ia.grossIncome as gross_income,
        ia.ownRent as own_rent,
        ia.residenceType as residence_type,
        case when ia.residenceType = 'M' then 1 else 0 end as mh,
        ia.homeOwnersInsurance as homeowners_insurance,
        ia.floodInsurance as flood_insurance,
        ia.registrationMethod as registration_method,
        ia.ihpReferral as ihp_referral,
        ia.ihpEligible as ihp_eligible,
        cast(ia.ihpAmount as double) as ihp_amount,
        ia.ineligibleReason as ineligible_reason,
        cast(ia.fipAmount as double) as fip_amount,
        ia.haReferral as ha_referral,
        ia.haEligible as ha_eligible,
        cast(ia.haAmount as double) as ha_amount,
        ia.onaReferral as ona_referral,
        ia.onaEligible as ona_eligible,
        cast(ia.onaAmount as double) as ona_amount,
        ia.utilitiesOut as utilities_out,
        ia.homeDamage as home_damage,
        ia.autoDamage as auto_damage,
        ia.emergencyNeeds as emergency_needs,
        ia.foodNeed as food_need,
        ia.shelterNeed as shelter_need,
        ia.accessFunctionalNeeds as access_functional_needs,
        ia.sbaApproved as sba_approved,
        ia.inspnIssued as inspection_issued,
        ia.inspnReturned as inspection_returned,
        ia.habitabilityRepairsRequired as habitability_repairs_required,
        cast(ia.rpfvl as double) as rpfvl,
        cast(ia.ppfvl as double) as ppfvl,
        ia.renterDamageLevel as renter_damage_level,
        ia.destroyed as destroyed,
        ia.waterLevel as water_level,
        ia.highWaterLocation as high_water_location,
        ia.floodDamage as flood_damage,
        cast(ia.floodDamageAmount as double) as flood_damage_amount,
        ia.foundationDamage as foundation_damage,
        cast(ia.foundationDamageAmount as double) as foundation_damage_amount,
        ia.roofDamage as roof_damage,
        cast(ia.roofDamageAmount as double) as roof_damage_amount,
        ia.rentalAssistanceEligible as rental_assistance_eligible,
        cast(ia.rentalAssistanceAmount as double) as rental_assistance_amount,
        ia.repairAssistanceEligible as repair_assistance_eligible,
        cast(ia.repairAmount as double) as repair_amount,
        ia.replacementAssistanceEligible as replacement_assistance_eligible,
        cast(ia.replacementAmount as double) as replacement_amount,
        ia.personalPropertyEligible as personal_property_eligible,
        cast(ia.personalPropertyAmount as double) as personal_property_amount,
        ia.ihpMax as ihp_max,
        ia.haMax as ha_max,
        ia.onaMax as ona_max,
        cast(ia.unmetNeedRp as double) as unmet_need_rp,
        cast(ia.unmetNeedPp as double) as unmet_need_pp,
        ia.reportedDamage as reported_damage,
        ia.insufficientDamage as insufficient_damage,
        ia.ineligibleInsurance as ineligible_insurance,
        ia.verifiedOwnership as verified_ownership,
        ia.verifiedOccupancy as verified_occupancy,
        wz.wind_zone,
        case when wz.wind_zone >= 2 then 1 else 0 end as treated,
        case when wz.wind_zone = 3 then 1 else 0 end as treated_wz3
    from ihp_registrations ia
    left join ia_county_xwalk x
      on ia.damagedStateAbbreviation = x.damagedStateAbbreviation
     and ia.county = x.county
    inner join windzone wz
      on coalesce(ia.fips, x.countyfp) = wz.countyfp
    where ia.primaryResidence
      and ia.residenceType in ('M', 'H')
      and ia.incidentTypeCode in ('H', 'W', '4', 'T')
      and ia.damagedStateAbbreviation not in ('AS', 'GU', 'VI', 'PR', 'AK', 'HI')
"

dbExecute(db, sprintf("
    copy (%s)
    to %s
    (format parquet, compression zstd)
", sql_build, q(out_path)))

dt_summary <- dbGetQuery(db, sprintf("
    select
        count(*) as n,
        sum(mh) as n_mh,
        sum(treated) as n_treated,
        min(year_declared) as min_year,
        max(year_declared) as max_year,
        count(distinct countyfp) as counties,
        count(distinct disaster_number) as disasters
    from read_parquet(%s)
", q(out_path)))

print(dt_summary)
message("Saved IA registrations to ", out_path)
