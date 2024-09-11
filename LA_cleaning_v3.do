* LA cleaning v3
* nahian 8/12

* set pathways
	clear all
	
	glob state LA 
	
	*log using "/home/nahian/EOP/absenteeism/log_LA_cleaning.smcl", replace
	if "`c(username)'" ==  "nahian" {
		glob data "/home/nahian/EOP/absenteeism/raw data"
		glob path "/home/nahian/EOP/absenteeism/"
		glob clean "/home/nahian/EOP/absenteeism/clean data"
		glob ccd_data "/home/nahian/EOP/absenteeism/ccd data"
	}
	
* load data (2020 must be treated differently)
**  state data first
foreach yr in 2019 2022 2023{
	clear all
	import delimited "${data}/raw_LA_state_`yr'.csv", varnames(1)
	generate data_level = "state"
	generate year = `yr'
	
	rename ïlevel district_name
	cap rename subcategory subgroup
	save "${data}/raw_LA_state_`yr'.dta", replace 

}

** district data
foreach yr in 2019 2022 2023{
	clear all
	import delimited "${data}/raw_LA_district_`yr'.csv", varnames(1)
	generate data_level = "district"
	generate year = `yr'
	
	cap rename sponsorname district_name
	cap rename leaname district_name
	cap rename schoolsystemname district_name
	
	cap rename subcategory subgroup
	
	cap rename ïsponsorcd state_district_id
	cap rename leacode state_district_id
	cap rename ïleacode state_district_id
	cap rename ïschoolsystemcode state_district_id
	
	save "${data}/raw_LA_district_`yr'.dta", replace 

}

** school data
foreach yr in 2019 2022 2023{
	clear all
	import delimited "${data}/raw_LA_schools_`yr'.csv", varnames(1)
	generate data_level = "school"
	generate year = `yr'
	
	cap rename sponsorname district_name
	cap rename leaname district_name
	cap rename schoolsystemname district_name
	
	cap rename subcategory subgroup
	
	cap rename ïsponsorcd state_district_id
	cap rename leacode state_district_id
	cap rename ïleacode state_district_id
	cap rename ïschoolsystemcode state_district_id
	
	rename sitename schoolname
	cap rename sitecd state_school_id
	cap rename sitecode state_school_id
	
	save "${data}/raw_LA_schools_`yr'.dta", replace 

}

* 2020
	clear all
	import delimited "${data}/raw_LA_2020.csv", varnames(1)
	rename leacode state_district_id
	rename sitecode state_school_id
	rename leaname district_name
	rename sitename schoolname
	gen year = 2020
	
	gen data_level = ""
	
	replace data_level = "state" if district_name == "State of Louisiana"
	replace data_level = "district" if missing(schoolname) & district_name != "State of Louisiana"
	replace data_level = "school" if !missing(schoolname)
	
	save "${data}/raw_LA_2020.dta", replace
	
	use  "${data}/raw_LA_2020.dta", clear
	*tostring rate, generate(rate_str) format("%12.0g") // to merge with other years
	gen rate_str = ""
	replace rate_str = string(rate, "%12.0g")
	drop rate
	rename rate_str rate
	save "${data}/raw_LA_2020.dta", replace
	
** merge together
clear all

foreach yr in 2019 2022 2023{
    use "${data}/raw_LA_state_`yr'.dta", clear
    append using "${data}/raw_LA_district_`yr'.dta"
    append using "${data}/raw_LA_schools_`yr'.dta"
    
    save "${data}/raw_LA_`yr'.dta", replace 
}

use "${data}/raw_LA_2019.dta", clear
append using "${data}/raw_LA_2020.dta"
append using "${data}/raw_LA_2022.dta"
append using "${data}/raw_LA_2023.dta"
save "${data}/raw_LA.dta", replace

* clean merged file
	use "${data}/raw_LA.dta", clear

	gen grade = ""
	replace grade = regexs(1) if regexm(category, "Grades ([^,]+)")
	replace subgroup = "all" if regexm(category, "Grades")
	replace grade = subinstr(grade, "Grades ", "", .)
	replace grade = "all" if missing(grade)
	
	replace subgroup = "all" if strpos(lower(category), "overall") == 1
	
	drop category
	
	*convert pers
	replace rate = subinstr(rate, "%", "", .)
	destring rate, replace
	replace rate = rate / 100
	
	*rename subgroups
	replace subgroup = trim(subgroup)
	
	replace subgroup = "asn" if subgroup == "Asian"
	replace subgroup = "blk" if subgroup == "Black"
	replace subgroup = "hsp" if subgroup == "Hispanic"
	replace subgroup = "mtr" if subgroup == "Multiple Race"
	replace subgroup = "mtr" if subgroup == "Multi Race"
	replace subgroup = "nam" if subgroup == "Native American"
	replace subgroup = "hpi" if subgroup == "Pacific Islander"
	replace subgroup = "wht" if subgroup == "White"
	replace subgroup = "mal" if subgroup == "Male"
	replace subgroup = "fem" if subgroup == "Female"
	replace subgroup = "ell" if subgroup == "English Learner"
	replace subgroup = "ell" if subgroup == "English Learners"
	replace subgroup = "nel" if subgroup == "English Proficient" 
	replace subgroup = "nep" if subgroup == "Regular Ed Students"
	replace subgroup = "nep" if subgroup == "Regular Ed Student"
	replace subgroup = "iep" if subgroup == "Students with Disabilities" 
	replace subgroup = "ecd" if subgroup == "Economically Disadvantaged" 
	replace subgroup = "nec" if subgroup == "Non Economically Disadvantaged" 
	replace subgroup = "ftr" if subgroup == "Foster" 	 
	replace subgroup = "nfr" if subgroup == "Non Foster" 
	replace subgroup = "hls" if subgroup == "Homeless" 
	replace subgroup = "nhl" if subgroup == "Non Homeless"
	replace subgroup = "mig" if subgroup == "Migrant" 
	replace subgroup = "nmg" if subgroup == "Non Migrant"

	save "${clean}/clean_LA.dta", replace
* 8/12 updates
	u "${clean}/clean_LA.dta", clear
	replace subgroup = "nhp" if subgroup == "hpi"
	
* add: state_abb, fips, 
	gen state_abb = ""
	replace state_abb = "LA"
	
	gen fips = .
	replace fips = 22
	save "${clean}/clean_LA.dta", replace

*merge in nces ids
	tempfile ${state}_id_xwalk
	u "${ccd_data}/ccd_id_xwalk_v2.dta", clear
	keep if state == "${state}"
	
	*state ids look like "LA-028" & "LA-028-028006"	(str)
	replace state_district_id = subinstr(state_district_id, "${state}-", "", .)
	replace state_school_id = substr(state_school_id, 8, .)
	
	save ${state}_id_xwalk, replace
	
	
	u "${clean}/clean_LA.dta", clear
	merge m:m state_district_id state_school_id data_level year using ${state}_id_xwalk
	
	drop state
	drop if _merge == 2

	order state_abb fips data_level district_name schoolname subgroup grade rate year state_district_id nces_district_id state_school_id nces_school_id _merge
	
	drop _merge
	
	save "${clean}/clean_LA.dta", replace

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




