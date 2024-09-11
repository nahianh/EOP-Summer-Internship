* Wisconsin Data Cleaning
* nahian 8/19

*set pathways
	clear all
	
	glob state WI
	
	if "`c(username)'" ==  "nahian" {
		glob data "/home/nahian/EOP/absenteeism/raw data"
		glob clean "/home/nahian/EOP/absenteeism/clean data"
		glob ccd_data "/home/nahian/EOP/absenteeism/ccd data"
	}

*import data
tempfile WI_allyrs
save `WI_allyrs', emptyok
foreach yr in 2019 2020 2021 2022 2023{
	clear all
	import delimited "${data}/WI_absenteeism_`yr'.csv", varnames(1)
	append using `WI_allyrs'
	save `WI_allyrs', replace
}
save "${data}/WI_allyrs.dta", replace

use "${data}/WI_allyrs.dta", clear
*clean years
	ren school_year year
	replace year = "2023" if year == "2022-23"
	replace year = "2022" if year == "2021-22"
	replace year = "2021" if year == "2020-21"
	replace year = "2020" if year == "2019-20"
	replace year = "2019" if year == "2018-19"
	destring year, replace

*drop variables
	drop agency_type cesa county grade_group charter_ind absentee_measure student_count absence_count

*data levels
	gen data_level = ""
	replace data_level = "state" if school_name == "[Statewide]"
	replace data_level = "district" if school_name == "[Districtwide]"
	replace data_level = "school" if missing(data_level)
	
	replace school_name = "" if school_name == "[Statewide]"
	replace school_name = "" if school_name == "[Districtwide]"
	replace district_name = "" if district_name == "[Statewide]"

*grades
	gen grade = ""
	ren group_by_value subgroup
	order grade, a(subgroup)
	replace grade = subgroup if group_by == "Grade Level"
	replace grade = "all" if group_by != "Grade Level"
*subgroups
	replace subgroup = group_by + " unknown" if subgroup == "Unknown"
	*replace subgroup = group_by + " data suppressed" if subgroup == "[Data Suppressed]"
	drop if subgroup == "[Data Suppressed]"
	replace subgroup = "all" if grade != "all"
	drop group_by
	
	*rename the subgroups we can...
	replace subgroup = trim(lower(subgroup))
	
	replace subgroup = "all" if subgroup == "all students"
	replace subgroup = "asn" if subgroup == "asian"
	replace subgroup = "blk" if subgroup == "black"
	replace subgroup = "hsp" if subgroup == "hispanic"
	replace subgroup = "mtr" if subgroup == "two or more"
	replace subgroup = "nam" if subgroup == "amer indian"
	replace subgroup = "nhp" if subgroup == "pacific isle"
	replace subgroup = "wht" if subgroup == "white"
	replace subgroup = "ell" if subgroup == "el"
	replace subgroup = "nel" if subgroup == "eng prof"
	replace subgroup = "ecd" if subgroup == "econ disadv" 
	replace subgroup = "nec" if subgroup == "not econ disadv"
	replace subgroup = "fem" if subgroup == "female"
	replace subgroup = "mal" if subgroup == "male"
	replace subgroup = "mig" if subgroup == "migrant"
	replace subgroup = "nmg" if subgroup == "not migrant"
	replace subgroup = "iep" if subgroup == "swd"
	replace subgroup = "nep" if subgroup == "swod"
	replace subgroup = "grx" if subgroup == "non-binary"

	ren district_code state_district_id
	ren school_code state_school_id
	ren absence_rate rate
	
	tostring state_district_id, replace
	replace state_district_id = substr("0000" + state_district_id, -4, 4)
	
	tostring state_school_id, replace
	replace state_school_id = substr("0000" + state_school_id, -4, 4)
	replace state_school_id = "" if data_level != "school"
	
save "${clean}/clean_${state}.dta", replace
*use "${clean}/clean_${state}.dta", clear

// state_district_id = 147, state_school_id = 420

*merge in nces ids
u "${ccd_data}/ccd_id_xwalk_v2.dta", clear
	tempfile ${state}_id_xwalk
	keep if state == "${state}"
	replace state_district_id = subinstr(state_district_id, "${state}-", "", .)	
	replace state_school_id = substr(state_school_id, 9, .)
save ${state}_id_xwalk, replace	

u "${clean}/clean_${state}.dta", clear

	merge m:m state_district_id state_school_id data_level year using ${state}_id_xwalk
	drop if _merge == 2

	ren state state_abb
	replace state_abb = "WI" if missing(state_abb)
	replace fips = 55 if missing(fips)
	drop _merge
save "${clean}/clean_${state}.dta", replace

*merge in defs
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






		
	
	
	
