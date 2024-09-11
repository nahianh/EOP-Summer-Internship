* NC Data Cleaning
* nahian 8/13, updated 8/19

* set pathways
	clear all
	
	glob state NC 
	
	*log using "/home/nahian/EOP/absenteeism/log_LA_cleaning.smcl", replace
	if "`c(username)'" ==  "nahian" {
		glob data "/home/nahian/EOP/absenteeism/raw data"
		glob clean "/home/nahian/EOP/absenteeism/clean data"
		glob ccd_data "/home/nahian/EOP/absenteeism/ccd data"
	}
	
* load data
import excel using "${data}/NC_rcd_chronic_absent", firstrow clear

* cleaning
	*rename agency_code state_school_id
	gen state_school_id = ""
	gen state_district_id = ""
	replace state_district_id = substr(agency_code, 1, 3) 
	replace state_school_id = agency_code if !regexm(agency_code, ".*(LEA|SEA)$")
	
	gen data_level = ""
	replace data_level = "state" if regexm(agency_code, ".*SEA$")
	replace data_level = "district" if regexm(agency_code, ".*LEA$")
	replace data_level = "school" if !missing(state_school_id)
	 
	gen rate = ""
	replace rate = string(pct, "%12.0g")	
	replace rate = ">.95" if masking == 1
	replace rate = "<.05" if masking == 2
	
	drop count den pct masking agency_code 

save "${clean}/clean_${state}.dta", replace

* merge in district and school names
import delimited "${data}/NC_names_ids.csv", varnames(1) clear
tempfile ${state}_state_ids
	drop schoolname
	rename officialschoolname school_name
	rename leaname district_name
	rename leanumber state_district_id
	rename schoolnumber state_school_id
save ${state}_state_ids, replace

u "${clean}/clean_${state}.dta", clear	

merge m:m state_school_id state_district_id using ${state}_state_ids

*fill in remaining district names
levelsof state_district_id, local(district_ids)	

foreach id of local district_ids{
	qui{
		preserve
		keep if state_district_id == "`id'" & !missing(district_name)
		if _N > 0 {
			local target_value = district_name[1]
			restore
			replace district_name = "`target_value'" if state_district_id == "`id'" & missing(district_name)
		}
		else {
			restore
		}
	}

}
drop if _merge == 2	
drop _merge

* identifiers
	gen state_abb = "${state}"
	gen fips = 37
save "${clean}/clean_${state}.dta", replace
	
* merge in NCES IDs
u "${ccd_data}/ccd_id_xwalk_v2.dta", clear
	tempfile ${state}_id_xwalk
	keep if state == "${state}"	
	replace state_district_id = subinstr(state_district_id, "${state}-", "", .)
	replace state_school_id = subinstr(state_school_id, "${state}-", "", .)
	replace state_school_id = subinstr(state_school_id, "-", "", .)
	replace state_district_id = trim(state_district_id)
	replace state_school_id = trim(state_school_id)
	rename state state_abb

save ${state}_id_xwalk, replace	

u "${clean}/clean_${state}.dta", clear
replace state_district_id = trim(state_district_id)
replace state_school_id = trim(state_school_id)

merge m:m state_district_id state_school_id data_level year fips state_abb using ${state}_id_xwalk

drop if _merge == 2	
drop _merge	
	
* rename subgroups
	replace subgroup = trim(subgroup)
	
	replace subgroup = "all" if subgroup == "ALL"
	replace subgroup = "asn" if subgroup == "AS7"
	replace subgroup = "blk" if subgroup == "BL7"
	replace subgroup = "hsp" if subgroup == "HI7"
	replace subgroup = "mtr" if subgroup == "MU7"
	replace subgroup = "nam" if subgroup == "AM7"
	replace subgroup = "nhp" if subgroup == "PI7"
	replace subgroup = "wht" if subgroup == "WH7"
	replace subgroup = "ell" if subgroup == "ELS"
	replace subgroup = "ecd" if subgroup == "EDS" 	
	replace subgroup = "mal" if subgroup == "MALE"
	replace subgroup = "fem" if subgroup == "FEM"
	replace subgroup = "iep" if subgroup == "SWD"

save "${clean}/clean_${state}.dta", replace

*add definitions (8/19)
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


	
