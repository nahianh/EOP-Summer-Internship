* South Dakota Data Cleaning
* nahian 8/20

*set pathways
	clear all
	
	glob state SD
	
	if "`c(username)'" ==  "nahian" {
		glob data "/home/nahian/EOP/absenteeism/raw data"
		glob clean "/home/nahian/EOP/absenteeism/clean data"
		glob ccd_data "/home/nahian/EOP/absenteeism/ccd data"
	}

*Load non-EDE data (2021, 2022, 2023)
	import excel "${data}/SD_edited.xlsx", clear firstrow
*Reshape from wide to long
	keep year district_name state_district_id school_name state_school_id ca_*
	reshape long ca_Denominator_ ca_Numerator_ ca_Percentage_, i(year district_name state_district_id school_name state_school_id) j(subgroup) string

	drop ca_Denominator_ 
	drop ca_Numerator_
	ren ca_Percentage_ rate
*Add cols
	gen source = "state"
	
	gen data_level = ""
	replace data_level = "state" if district_name == "All Districts"
	replace data_level = "district" if district_name != "All Districts" & school_name == "All Schools"
	replace data_level = "school" if district_name != "All Districts" & school_name != "All Schools"

*Clean years
	replace year = substr(year, 6, .)
	destring year, replace
*Prep to merge NCES ids
	replace state_school_id = "" if data_level != "school"

	
save "${data}/SD_21-23.dta", replace

*Merge NCES ids, state_abb, fips
u "${ccd_data}/ccd_id_xwalk_v2.dta", clear
	tempfile ${state}_id_xwalk
	keep if state == "${state}"
	replace state_district_id = subinstr(state_district_id, "${state}-", "", .)	
	replace state_school_id = substr(state_school_id, 10, .)
	ren state state_abb
save ${state}_id_xwalk, replace

u "${data}/SD_21-23.dta", clear
	
	merge m:m state_district_id state_school_id data_level year using ${state}_id_xwalk
	drop if _merge == 2

	replace state_abb = "${state}" if missing(state_abb)
	replace fips = 46 if missing(fips)
	drop _merge	

save "${clean}/clean_${state}.dta", replace

*Merge in defs
clear all
tempfile ${state}_defs
import delim "${data}/absenteeism_defs.csv", varnames(1)
	keep if state == "${state}"
	ren state state_abb
save ${state}_defs, replace

u "${clean}/clean_${state}.dta", clear
	merge m:1 state_abb using ${state}_defs
	drop fulldefinition _merge

save "${clean}/clean_${state}.dta", replace



// *Load EDE data & keep 2019 & 2020
// import delim "${data}/SD_Data Download Tool.csv", clear varnames(1)
//
// 	ren schoolyear year
// 	replace year = trim(lower(year))
