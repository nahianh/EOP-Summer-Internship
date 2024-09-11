* Michigan Data Cleaning
* nahian 8/21

*set pathways
	clear all
	
	glob state MI
	
	if "`c(username)'" ==  "nahian" {
		glob data "/home/nahian/EOP/absenteeism/raw data"
		glob clean "/home/nahian/EOP/absenteeism/clean data"
		glob ccd_data "/home/nahian/EOP/absenteeism/ccd data"
	}

* import data & save into 1 file
tempfile MI_allyrs
save `MI_allyrs', emptyok
foreach yr in 2019 2020 2021 2022 2023{
	clear all
	import delimited "${data}/`yr'_MI_absenteeism.csv", varnames(1)
	append using `MI_allyrs'
	save `MI_allyrs', replace
}

*drop and rename columns
	drop countycode countyname schoollevel locale mistem_name mistem_code totalstudents chronicallyabsentcount notchronicallyabsentcount notchronicallyabsentpercent ar_allstudents ar_chronicallyabsent ar_notchronicallyabsent

save "${data}/MI_allyrs.dta", replace

use "${data}/MI_allyrs.dta", clear

*set rules for data level
	gen data_level = ""
	replace data_level = "state" if isdname == "Statewide"
	replace data_level = "district" if entitytype == "ISD"
	replace data_level = "district" if entitytype == "ISD District"
	replace data_level = "district" if entitytype == "LEA District"
	replace data_level = "district" if entitytype == "PSA District"
	replace data_level = "district" if entitytype == "State District"
	replace data_level = "school" if entitytype == "ISD School"
	replace data_level = "school" if entitytype == "ISD Unique Education Provider"
	replace data_level = "school" if entitytype == "LEA Non-Instructional Ancillary Facility"
	replace data_level = "school" if entitytype == "LEA School"
	replace data_level = "school" if entitytype == "LEA Unique Education Provider"
	replace data_level = "school" if entitytype == "PSA School"
	replace data_level = "school" if entitytype == "PSA Unique Education Provider"
	replace data_level = "school" if entitytype == "State School"
	
*clean years
	ren schoolyear year
	replace year = "2019" if year == "18 - 19 School Year"
	replace year = "2020" if year == "19 - 20 School Year"
	replace year = "2021" if year == "20 - 21 School Year"
	replace year = "2022" if year == "21 - 22 School Year"
	replace year = "2023" if year == "22 - 23 School Year"
	destring year, replace

*grades
	ren reportsubgroup subgroup
	gen grade = ""
	replace grade = subgroup if reportcategory == "Grade"
	order grade, b(subgroup)
	replace grade = "all" if reportcategory != "Grade"
	replace subgroup = "all" if reportcategory == "Grade"
	replace grade = trim(lower(grade))
	drop reportcategory

*subgroups
	replace subgroup = trim(lower(subgroup))
	replace subgroup = "asn" if subgroup == "asian"
	replace subgroup = "nam" if subgroup == "american indian or alaska native"
	replace subgroup = "blk" if subgroup == "black, not of hispanic origin"
	replace subgroup = "ecd" if subgroup == "economically disadvantaged" 
	replace subgroup = "ell" if subgroup == "english learners"
	replace subgroup = "fem" if subgroup == "female"
	replace subgroup = "hsp" if subgroup == "hispanic"
	replace subgroup = "hls" if subgroup == "homeless"
	replace subgroup = "mal" if subgroup == "male"
	replace subgroup = "mig" if subgroup == "migrant"
	replace subgroup = "nhp" if subgroup == "native hawaiian or other pacific islander"
	replace subgroup = "nec" if subgroup == "not economically disadvantaged"
	replace subgroup = "nel" if subgroup == "not english learners"
	replace subgroup = "nhl" if subgroup == "not homeless"
	replace subgroup = "nmg" if subgroup == "not migrant"
	replace subgroup = "iep" if subgroup == "students with disabilities"
	replace subgroup = "nep" if subgroup == "students without iep"
	replace subgroup = "mtr" if subgroup == "two or more races"
	replace subgroup = "wht" if subgroup == "white, not of hispanic origin"

	
* prep for id merge
	ren districtcode state_district_id
	ren districtname district_name
	ren buildingcode state_school_id
	ren buildingname school_name
	ren chronicallyabsentpercent rate
	order entitytype, last

	tostring state_district_id, replace
	tostring state_school_id, replace
	
	replace state_district_id = substr("00000" + state_district_id, -5, 5)
	replace state_school_id = substr("00000" + state_school_id, -5, 5)
	replace state_school_id = "" if data_level != "school"
	
save "${data}/MI_allyrs.dta", replace
	
	
*merge in nces ids
u "${ccd_data}/ccd_id_xwalk_v2.dta", clear
	tempfile ${state}_id_xwalk
	keep if state == "${state}"
	replace state_district_id = subinstr(state_district_id, "${state}-", "", .)	
	replace state_school_id = substr(state_school_id, 10, .)
save ${state}_id_xwalk, replace

u "${data}/MI_allyrs.dta", clear
	merge m:m state_district_id state_school_id data_level year using ${state}_id_xwalk
	drop if _merge == 2

	ren state state_abb
	replace state_abb = "MI" if missing(state_abb)
	replace fips = 26 if missing(fips)
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
	
	
	
	
	
	
