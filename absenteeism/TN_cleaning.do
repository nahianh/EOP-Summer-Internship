* Tennessee Data Cleaning
* nahian 8/20

*set pathways
	clear all
	
	glob state TN
	
	if "`c(username)'" ==  "nahian" {
		glob data "/home/nahian/EOP/absenteeism/raw data"
		glob clean "/home/nahian/EOP/absenteeism/clean data"
		glob ccd_data "/home/nahian/EOP/absenteeism/ccd data"
	}
*import data and put it in 1 file
clear

local years 2019 2020 2021 2022 2023
local levels state district school

tempfile combined
save `combined', emptyok

foreach year in `years'{
	foreach level in `levels'{
		*construct filename
		local file "${data}/${state}_`year'_`level'"
		*file extension
		if `year' < 2022{
			local ext "csv"
		}
		else{
			local ext "xlsx"
		}
		*import file
		if "`ext'" == "csv"{
			import delim using "`file'.`ext'", clear varnames(1)
		}
		else if "`ext'" == "xlsx"{
			import excel "`file'.`ext'", clear firstrow
		}
		
		*convert all vars to string
		foreach var of varlist _all{
			capture confirm numeric variable `var'
			if _rc == 0{
				gen `var'_str = string(`var', "%20.12g")
				drop `var'
				rename `var'_str `var'
			}
		}
		
		cap ren student_group subgroup
		
		*add year and data_level cols
		gen year = `year'
		gen data_level = "`level'"
		
		//describe
		
		*append data to master
		append using `combined'
		save `combined', replace
	}
}
save "${data}/raw_${state}.dta", replace

*drop & rename cols
	drop n_chronically_absent n_students
	ren system_name district_name
	ren grade_band grade
	ren pct_chronically_absent rate
	ren system state_district_id
	ren school state_school_id
*clean grades
	replace grade = trim(lower(grade))
	replace grade = "9-12" if grade == "9th through 12th"
	replace grade = "all" if grade == "all grades"
	replace grade = "k-8" if grade == "k through 8th"
	
*clean subgroups
	replace subgroup = trim(lower(subgroup))
	replace subgroup = "all" if subgroup == "all students"
	replace subgroup = "nam" if subgroup == "american indian or alaska native"
	replace subgroup = "asn" if subgroup == "asian"
	replace subgroup = "blk" if subgroup == "black or african american"
	replace subgroup = "bhn" if subgroup == "black/hispanic/native american" //mtr?
	replace subgroup = "ecd" if subgroup == "economically disadvantaged"
	replace subgroup = "ell" if subgroup == "english learners with transitional 1-4"
	replace subgroup = "hsp" if subgroup == "hispanic"
	replace subgroup = "nhp" if subgroup == "native hawaiian or other pacific islander"
	replace subgroup = "iep" if subgroup == "students with disabilities"
	replace subgroup = "wht" if subgroup == "white"

*prep to merge ids
	replace state_district_id = substr("00000" + state_district_id, -5, 5)
	replace state_school_id = substr("0000" + state_school_id, -4, 4)
	replace state_school_id = "" if data_level != "school"

save "${clean}/clean_${state}.dta", replace

*merge in nces ids, state_abb, fips
//d = 1-3 digits, s = 1-4 digits
u "${ccd_data}/ccd_id_xwalk_v2.dta", clear
	tempfile ${state}_id_xwalk
	keep if state == "${state}"
	replace state_district_id = subinstr(state_district_id, "${state}-", "", .)	
	replace state_school_id = substr(state_school_id, 10, .)
save ${state}_id_xwalk, replace	

u "${clean}/clean_${state}.dta", clear
	merge m:m state_district_id state_school_id data_level year using ${state}_id_xwalk
	drop if _merge == 2

	ren state state_abb
	replace state_abb = "${state}" if missing(state_abb)
	replace fips = 47 if missing(fips)
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











