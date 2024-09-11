* create crosswalk of district state id and district nces id
* created 8/9/2024
* adapted from kra xwalk code
* nahian edits 8/12 - adding school level ids

*** set up ---------------------------------------------------------------------

clear all
	
if "`c(username)'" == "sadierichardson" {
	glob ccd_data "/Users/sadierichardson/Dropbox/seda_2024/intern tasks/absenteeism/supplemental data/ccd data"
}


if "`c(username)'" ==  "nahian" {
	glob ccd_data "/home/nahian/EOP/absenteeism/ccd data"
}

*** districts ------------------------------------------------------------------
foreach org in district school{
	foreach yr of numlist 2019/2023{

		import delim "${ccd_data}/ccd_`org'_`yr'.csv", clear
		
		ren fipst fips
		ren st state
		*ren leaid ncesid
		ren leaid nces_district_id
		*ren st_leaid stateid
		ren st_leaid state_district_id
		cap ren st_schid state_school_id
		cap ren ncessch nces_school_id
		
		gen year = real(substr(school_year, 6, .))
		
		*keep year fips state stateid ncesid
		cap keep year fips state state_district_id state_school_id nces_district_id nces_school_id
		gen data_level = "`org'"
			
		if `yr' == 2019{
			tempfile xwalk
			save `xwalk', replace
		}
		else{
			append using `xwalk'
			save `xwalk', replace
		}
	}
	tempfile `org'_id_xwalk
	save ``org'_id_xwalk'
}

use `school_id_xwalk'
append using `district_id_xwalk'

keep year fips state state_district_id state_school_id nces_district_id nces_school_id data_level

save "${ccd_data}/ccd_id_xwalk_v2.dta", replace

	
