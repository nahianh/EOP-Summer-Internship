* Nevada data cleaning
* nahian 8/12, updated 8/19

* set pathways
	clear all
	
	glob state NV 
	
	*log using "/home/nahian/EOP/absenteeism/log_LA_cleaning.smcl", replace
	if "`c(username)'" ==  "nahian" {
		glob data "/home/nahian/EOP/absenteeism/raw data"
		glob clean "/home/nahian/EOP/absenteeism/clean data"
		glob ccd_data "/home/nahian/EOP/absenteeism/ccd data"
	}
	
* load data
import delimited "${data}/NV_Schools.csv", varnames(2)

* cleaning
	gen year = real(substr(accountabilityyear, 6, .))
	drop accountabilityyear
	
	gen data_level = ""
	replace data_level = "state" if name == "State"
	replace data_level = "district" if districtauthorityname == "State"
	replace data_level = "school" if missing(data_level)
	
	replace districtauthorityname = name if districtauthorityname == "State"
	ren districtauthorityname district_name
	replace district_name = name if name == "State"
	
	ren name school_name
	replace school_name = "" if school_name == district_name
* reshape from wide to long
	gen id = _n
	reshape long chronicabsenteeism, i(id) j(subgroup) string
	
	rename chronicabsenteeism rate
* rename subgroups
	replace subgroup = trim(subgroup)
	
	replace subgroup = "all" if subgroup == "allstudents"
	replace subgroup = "asn" if subgroup == "asian"
	replace subgroup = "blk" if subgroup == "black"
	replace subgroup = "hsp" if subgroup == "hispanic"
	replace subgroup = "mtr" if subgroup == "twoormoreraces"
	replace subgroup = "nam" if subgroup == "americanindian"
	replace subgroup = "hpi" if subgroup == "pacificislande"
	replace subgroup = "wht" if subgroup == "white"
	replace subgroup = "ell" if subgroup == "el"
	replace subgroup = "ecd" if subgroup == "frl" 
	replace subgroup = "nhp" if subgroup == "hpi"
	
* convert str rate to float
// 	replace rate = subinstr(rate, "-", "", .)
// 	replace rate = subinstr(rate, "N/A", "", .)
// 	replace rate = subinstr(rate, "<5", "", .)
// 	replace rate = subinstr(rate, ">95", "", .)
//	
// 	destring rate, replace
// 	replace rate = rate / 100
* identifiers
	gen state_abb = "${state}"
	gen fips = 32
	
save "${clean}/clean_${state}.dta", replace

u "${clean}/clean_${state}.dta", clear
	
	gen state_district_id = .
	gen state_school_id = .
	
	replace state_district_id = organizationcode if data_level == "district"
	replace state_school_id = organizationcode if data_level == "school"
	
***fill in rest of district id column
levelsof district_name, local(names)	
foreach n of local names{
	qui su state_district_id if district_name == "`n'", meanonly
	local target_value = r(mean)   
	replace state_district_id = `target_value' if district_name == "`n'" & missing(state_district_id)
	
}

save "${clean}/clean_${state}.dta", replace
// state_district_id = 2, state_school_id = 2093

*merge in nces ids
u "${ccd_data}/ccd_id_xwalk_v2.dta", clear
	tempfile ${state}_id_xwalk
	keep if state == "${state}"	
	
	replace state_district_id = subinstr(state_district_id, "${state}-", "", .)	
	replace state_school_id = substr(state_school_id, 8, .)
	*remove leading 0s
	replace state_district_id = substr(state_district_id, strpos(state_district_id, "0") + 1, .) if state_district_id != ""
	
	destring state_district_id, replace
	destring state_school_id, replace
	
save ${state}_id_xwalk, replace	

u "${clean}/clean_${state}.dta", clear

	merge m:m state_district_id state_school_id data_level year fips using ${state}_id_xwalk

	drop state id
	drop if _merge == 2
	drop _merge
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
	
	
