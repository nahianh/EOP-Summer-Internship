* AK cleaning v2
* nahian 8/6

* set pathways
	clear all
	
	glob state AK 
	
	if "`c(username)'" ==  "nahian" {
		glob data "/home/nahian/EOP/absenteeism/raw data"
		glob path "/home/nahian/EOP/absenteeism/"
		glob clean "/home/nahian/EOP/absenteeism/clean data"
* load data
	import delimited "${data}/raw_AK_allyears.csv", varnames(1) 
	*This file is 
	save "${data}/raw_AK_allyears.dta", replace
	use "${data}/raw_AK_allyears.dta", clear
* clean
	rename *, lower // SHR add bc looks like variables come in w/uppercases (might be using wrong file)
	rename school_name schoolname
	rename studentgroups subgroup
	rename carate ca_rate
	rename datalevel data_level
	rename id state_id
	
	gen year = 2019 if ïschoolyear == "2018-2019" 
	replace year = 2020 if ïschoolyear == "2019-2020"
	replace year = 2021 if ïschoolyear == "2020-2021"
	replace year = 2022 if ïschoolyear == "2021-2022"
	replace year = 2023 if ïschoolyear == "2022-2023"
	
	replace district_name = "State of Alaska" if data_level == "State"
	
	replace ca_rate = ca_rate / 100
	
	replace subgroup = trim(subgroup)
	replace subgroup = "all" if subgroup == "All Students"
	replace subgroup = "asn" if subgroup == "Asian/Pacific Islander"
	replace subgroup = "blk" if subgroup == "African American"
	replace subgroup = "hsp" if subgroup == "Hispanic"
	replace subgroup = "mtr" if subgroup == "Two or More Races"
	replace subgroup = "nam" if subgroup == "Alaska Native/American Indian"
	replace subgroup = "wht" if subgroup == "Caucasian"
	replace subgroup = "ell" if subgroup == "English Learners"
	replace subgroup = "iep" if subgroup == "Students With Disabilities" 
	replace subgroup = "frl" if subgroup == "Economically Disadvantaged"  
	
	save "${clean}/clean_AK.dta", replace
