*Cross State Analysis
* nahian 8/26, 8/27

	clear all
	ssc install asdoc
	
	if "`c(username)'" ==  "nahian" {
		glob data "/home/nahian/EOP/absenteeism/raw data"
		glob analysis "/home/nahian/EOP/absenteeism/analysis"
		glob clean "/home/nahian/EOP/absenteeism/clean data"
		glob ccd_data "/home/nahian/EOP/absenteeism/ccd data"
	}

*Load data - LA, NV, NC, TN, WI, SD, MI

tempfile temp_NV
u "${clean}/clean_NV.dta", clear
	keep if data_level == "district"
	destring rate, replace force
	replace rate = rate / 100
save `temp_NV'

tempfile temp_NC
u "${clean}/clean_NC.dta", clear
	keep if data_level == "district"
	destring rate, replace force
save `temp_NC'

tempfile temp_TN
u "${clean}/clean_TN.dta", clear
	keep if data_level == "district"
	destring rate, replace force
	replace rate = rate / 100
save `temp_TN'

tempfile temp_WI
u "${clean}/clean_WI.dta", clear
	keep if data_level == "district"
	destring rate, replace force
	replace rate = rate / 100
save `temp_WI'

tempfile temp_SD
u "${clean}/clean_SD.dta", clear
	keep if data_level == "district"
	destring rate, replace force
save `temp_SD'

tempfile temp_MI
u "${clean}/clean_MI.dta", clear
	keep if data_level == "district"
	destring rate, replace force
	replace rate = rate / 100
save `temp_MI'

u "${clean}/clean_LA.dta", clear
	rename schoolname school_name
	append using `temp_NV', force
	append using `temp_NC'
	append using `temp_TN'
	append using `temp_WI'
	append using `temp_SD'
	append using `temp_MI'
	keep if data_level == "district"
	drop if missing(nces_district_id)
	replace grade = "all" if missing(grade)
	keep state_abb fips data_level district_name school_name subgroup grade rate year nces_district_id def mer
save "${analysis}/seven_states.dta", replace


u "${analysis}/seven_states.dta", clear
	
*Table of summary stats by year, state
preserve
	keep if subgroup == "all" & grade == "all"
	reshape wide rate, i(state_abb fips data_level district_name school_name subgroup grade nces_district_id def mer) j(year) 
	tabstat rate*, by(state_abb) stat(mean sd) nototal format(%9.2f)
restore

preserve
	keep if subgroup == "all" & grade == "all"
	graph box rate, over(year) by(state_abb) asyvars ///
	legend(rows(1) position(12))
restore

*Line plot of absenteeism by state
preserve
	keep if subgroup == "all" & grade == "all"
	collapse (mean) rate, by(year state_abb) 	
	twoway (line rate year if state_abb == "LA", lcolor(blue)) ///
       (line rate year if state_abb == "NV", lcolor(red)) ///
       (line rate year if state_abb == "NC", lcolor(green)) ///
       (line rate year if state_abb == "TN", lcolor(orange)) ///
       (line rate year if state_abb == "WI", lcolor(purple)) ///
       (line rate year if state_abb == "SD", lcolor(brown)) ///
       (line rate year if state_abb == "MI", lcolor(black)), ///
       title("Absenteeism Rate Over Time - by State") ///
       ytitle("Absenteeism Rate") ///
       legend(order(1 "LA" 2 "NV" 3 "NC" 4 "TN" 5 "WI" 6 "SD" 7 "MI"))
restore

*Merge in SEDA data

tempfile temp_seda
u "${analysis}/seda2023.dta", clear
	keep if state == "LA" | state == "NV" | state == "NC" | state == "TN" | state == "WI" | state == "SD" | state == "MI"
	keep fips stateabb sedaadmin subject subgroup ys_mn_2019_ol ys_mn_2022_ol ys_mn_2023_ol ys_mn_1923_ol ys_mn_1922_ol ys_mn_2223_ol
	ren stateabb state_abb 
	ren sedaadmin nces_district_id
	reshape wide ys*, i(state_abb nces_district_id subgroup) j(subject) string
	ren ys_mn_2019_olmth mth_2019
	ren ys_mn_2022_olmth mth_2022
	ren ys_mn_2023_olmth mth_2023
	ren ys_mn_2019_olrla rla_2019
	ren ys_mn_2022_olrla rla_2022
	ren ys_mn_2023_olrla rla_2023
	ren ys_mn_1922_olmth mth_1922
	ren ys_mn_1922_olrla rla_1922
	ren ys_mn_1923_olmth mth_1923
	ren ys_mn_1923_olrla rla_1923
	ren ys_mn_2223_olmth mth_2223
	ren ys_mn_2223_olrla rla_2223
save `temp_seda', replace

u "${analysis}/seven_states.dta", clear
	keep if inlist(subgroup, "all", "blk", "hsp", "wht", "ecd", "nec")
	reshape wide rate, i(state_abb fips data_level district_name school_name subgroup grade nces_district_id def mer) j(year)
	merge m:1 state_abb fips nces_district_id subgroup using `temp_seda'
	keep if _merge == 3

*visualizations
preserve
	keep if subgroup == "all" & grade == "all"
	twoway (scatter rate2019 mth_2019 if state_abb == "LA", lcolor(blue)) ///
       (scatter rate2019 mth_2019 if state_abb == "NV", lcolor(red)) ///
       (scatter rate2019 mth_2019 if state_abb == "NC", lcolor(green)) ///
       (scatter rate2019 mth_2019 if state_abb == "TN", lcolor(orange)) ///
       (scatter rate2019 mth_2019 if state_abb == "WI", lcolor(purple)) ///
       (scatter rate2019 mth_2019 if state_abb == "SD", lcolor(brown)) ///
       (scatter rate2019 mth_2019 if state_abb == "MI", lcolor(black)), ///
       title("Average Math Scores vs Absenteeism Rate (2019, all students)") ///
       ytitle("Absenteeism Rate") ///
       legend(order(1 "LA" 2 "NV" 3 "NC" 4 "TN" 5 "WI" 6 "SD" 7 "MI"))
restore

preserve
	keep if subgroup == "all" & grade == "all"
	twoway (scatter mth_2019 rla_2019 rate2019), ///
	by(state_abb, title("Average Absenteeism Rate vs Average Test Scores 2019")) ///
	xtitle("Absenteeism Rate 2019") ///
	ytitle("Mean Test Scores 2019") ///
	legend(order(1 "Math" 2 "Reading")) 
	
restore

preserve
	keep if subgroup == "all" & grade == "all"
	twoway scatter mth_2022 rla_2022 rate2022, ///
	by(state_abb, title("Average Absenteeism Rate vs Average Test Scores 2022")) ///
	xtitle("Absenteeism Rate 2022") ///
	ytitle("Mean Test Scores 2022") ///
	legend(order(1 "Math" 2 "Reading"))
restore

preserve
	keep if subgroup == "all" & grade == "all"
	twoway scatter mth_2023 rla_2023 rate2023, ///
	by(state_abb, title("Average Absenteeism Rate vs Average Test Scores 2023")) ///
	xtitle("Absenteeism Rate 2023") ///
	ytitle("Mean Test Scores 2023") ///
	legend(order(1 "Math" 2 "Reading")) 
restore
     





