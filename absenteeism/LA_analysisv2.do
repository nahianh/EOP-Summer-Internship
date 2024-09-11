* LA Analysis v2
* nahian 8/23, 8/27

* set pathways
	clear all
	
	glob state LA 
	
	*log using "/home/nahian/EOP/absenteeism/log_LA_cleaning.smcl", replace
	if "`c(username)'" ==  "nahian" {
		glob data "/home/nahian/EOP/absenteeism/raw data"
		glob analysis "/home/nahian/EOP/absenteeism/analysis"
		glob clean "/home/nahian/EOP/absenteeism/clean data"
		glob ccd_data "/home/nahian/EOP/absenteeism/ccd data"
	}

* load data
u "${clean}/clean_${state}.dta", clear
	gen subgroup_grade = ""
	replace subgroup_grade = subgroup
	replace subgroup_grade = grade if subgroup == "all"
	drop subgroup grade
	keep if data_level == "district" //subsetting to district bc seda data is at district level
	drop if missing(nces_district_id)
*--------------------------------------------------------------------
* absenteeism trends in general (all students)
preserve
	keep if subgroup_grade == "all"
	graph bar (mean) rate, over(year) ///
	title("Absenteeism Rate Over Time for All Students") ///
	ytitle("Absenteeism Rate")
	
	bysort year: summarize rate
restore

preserve
	keep if subgroup_grade == "all"
	graph box rate, over(year) ///
	title("Absenteeism Rate Over Time for All Students") ///
	ytitle("Absenteeism Rate")
restore


* absenteeism trends - racial subgroups
preserve
	keep if inlist(subgroup_grade, "asn", "blk", "hsp", "nam", "nhp", "wht", "mtr")
//	reshape wide rate, i(state_abb fips district_name year) j(subgroup_grade) string
//	graph bar rate*, over(year) ///
// 	title("Absenteeism Rate Over Time - Racial Subgroups") ///
// 	ytitle("Absenteeism Rate")
// 	egen mean = mean(rate*), by(year)
// 	twoway line mean year
	collapse (mean) rate, by(year subgroup_grade)
	twoway (line rate year if subgroup_grade == "asn", lcolor(blue)) ///
       (line rate year if subgroup_grade == "blk", lcolor(red)) ///
       (line rate year if subgroup_grade == "nam", lcolor(green)) ///
       (line rate year if subgroup_grade == "hsp", lcolor(orange)) ///
       (line rate year if subgroup_grade == "nhp", lcolor(purple)) ///
       (line rate year if subgroup_grade == "wht", lcolor(brown)) ///
       (line rate year if subgroup_grade == "mtr", lcolor(black)), ///
       title("Absenteeism Rate Over Time - Racial Subgroups") ///
       ytitle("Absenteeism Rate") ///
       legend(order(1 "Asian" 2 "Black" 3 "Native American" 4 "Hispanic" 5 "Native Hawaiian/Pacific Islander" 6 "White" 7 "Multi-racial"))
restore

* absenteeism summary stats - all + (seda) racial subgroups + income  

preserve
	keep if inlist(subgroup_grade, "all", "blk", "hsp", "wht", "ecd", "nec")
	reshape wide rate, i(state_abb fips district_name year) j(subgroup_grade) string
	tabstat rate*, by(year) stat(mean sd min max) nototal
restore


* absenteeism trends - ecd vs nec
preserve
	keep if inlist(subgroup_grade, "ecd", "nec")
	reshape wide rate, i(state_abb fips district_name year) j(subgroup_grade) string
	graph bar rate*, over(year) ///
	title("Absenteeism Rate Over Time - Low Inc vs Non Low Inc") ///
	ytitle("Absenteeism Rate")
restore

* absenteeism trends - iep vs nep
preserve
	keep if inlist(subgroup_grade, "iep", "nep")
	reshape wide rate, i(state_abb fips district_name year) j(subgroup_grade) string
	graph bar rate*, over(year) ///
	title("Absenteeism Rate Over Time - Students w/ Disabilities vs Non") ///
	ytitle("Absenteeism Rate")
restore

* absenteeism trends - mal vs fem
preserve
	keep if inlist(subgroup_grade, "mal", "fem")
	reshape wide rate, i(state_abb fips district_name year) j(subgroup_grade) string
	graph bar rate*, over(year) ///
	title("Absenteeism Rate Over Time - Gender") ///
	ytitle("Absenteeism Rate")
restore

* absenteeism trends - hls vs nhl
preserve
	keep if inlist(subgroup_grade, "hls", "nhl")
	reshape wide rate, i(state_abb fips district_name year) j(subgroup_grade) string
	graph bar rate*, over(year) ///
	title("Absenteeism Rate Over Time - Homeless vs Non") ///
	ytitle("Absenteeism Rate")
restore

* correlation btwn absenteeism over time - 
preserve
	keep if subgroup_grade == "all"
	reshape wide rate, i(state_abb fips district_name nces_district_id subgroup_grade data_level def mer) j(year)
// 	**2019 vs 2022
// 	twoway scatter rate2019 rate2022, title("Absenteeism Rate 2019 vs Absenteeism Rate 2022")
// 	**2019 vs 2023
// 	twoway scatter rate2019 rate2023, title("Absenteeism Rate 2019 vs Absenteeism Rate 2023")
	correlate rate*
	
restore


*-------------------------------------------------------------------------------
*merge w seda data
tempfile ${state}_seda
u "${analysis}/seda2023.dta", clear
	keep if state == "${state}"
	keep fips stateabb sedaadmin subject subgroup ys_mn_2019_ol ys_mn_2022_ol ys_mn_2023_ol ys_mn_1923_ol ys_mn_1922_ol ys_mn_2223_ol
	ren stateabb state_abb 
	ren sedaadmin nces_district_id
	reshape wide ys*, i(state_abb nces_district_id subgroup) j(subject) string
	
save ${state}_seda, replace
	
*merge
u "${clean}/clean_${state}.dta", clear
	gen subgroup_grade = ""
	replace subgroup_grade = subgroup
	replace subgroup_grade = grade if subgroup == "all"
	drop subgroup grade
	keep if data_level == "district"
	drop if missing(nces_district_id)
	drop state_district_id state_school_id nces_school_id schoolname
	drop if subgroup_grade == "ftr" | subgroup_grade == "nfr"

	reshape wide rate, i(state_abb fips district_name nces_district_id subgroup_grade data_level def mer) j(year)
	ren subgroup_grade subgroup
	
	merge m:1 state_abb fips nces_district_id subgroup using ${state}_seda
 	drop if _merge != 3
	gen rate_1923 = rate2023 - rate2019
	gen rate_1922 = rate2022 - rate2019
	gen rate_2223 = rate2023 - rate2022
	
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
*-------------------------------------------------------------------------------
* test score trends - all students
preserve
	drop rate_1923 rate_1922 rate_2223 mth_1922 rla_1922 mth_1923 rla_1923 mth_2223 rla_2223
	reshape long rate mth_ rla_, i(state_abb fips district_name nces_district_id subgroup data_level def mer) j(year)
	keep if subgroup == "all"
	collapse (mean) mth_ rla_, by(year subgroup)
	twoway line mth_ rla_ year, title("Average Test Scores Trend by Subject - All Students")

restore
* test score trends - by subgroups (math)
preserve
	drop rate_1923 rate_1922 rate_2223 mth_1922 rla_1922 mth_1923 rla_1923 mth_2223 rla_2223
	reshape long rate mth_ rla_, i(state_abb fips district_name nces_district_id subgroup data_level def mer) j(year)
	collapse (mean) mth_ , by(year subgroup)
	twoway (line mth_ year if subgroup == "all", lcolor(blue)) ///
       (line mth_ year if subgroup == "blk", lcolor(red)) ///
       (line mth_ year if subgroup == "ecd", lcolor(green)) ///
       (line mth_ year if subgroup == "hsp", lcolor(orange)) ///
       (line mth_ year if subgroup == "nec", lcolor(purple)) ///
       (line mth_ year if subgroup == "wht", lcolor(brown)), ///
       title("Average Math Score Over Time - w/ Subgroups") ///
       ytitle("Average Math Score") ///
       legend(order(1 "All" 2 "Black" 3 "Low Inc" 4 "Hispanic" 5 "Not Low Inc" 6 "White"))

restore

* test score trends - by subgroups (rla)
preserve
	drop rate_1923 rate_1922 rate_2223 mth_1922 rla_1922 mth_1923 rla_1923 mth_2223 rla_2223
	reshape long rate mth_ rla_, i(state_abb fips district_name nces_district_id subgroup data_level def mer) j(year)
	collapse (mean) rla_ , by(year subgroup)
	twoway (line rla_ year if subgroup == "all", lcolor(blue)) ///
       (line rla_ year if subgroup == "blk", lcolor(red)) ///
       (line rla_ year if subgroup == "ecd", lcolor(green)) ///
       (line rla_ year if subgroup == "hsp", lcolor(orange)) ///
       (line rla_ year if subgroup == "nec", lcolor(purple)) ///
       (line rla_ year if subgroup == "wht", lcolor(brown)), ///
       title("Average RLA Score Over Time - w/ Subgroups") ///
       ytitle("Average RLA Score") ///
       legend(order(1 "All" 2 "Black" 3 "Low Inc" 4 "Hispanic" 5 "Not Low Inc" 6 "White"))

restore

* summary stats by year & subgroup
preserve
	drop rate_1923 rate_1922 rate_2223 mth_1922 rla_1922 mth_1923 rla_1923 mth_2223 rla_2223
	//reshape long rate mth_ rla_, i(state_abb fips district_name nces_district_id subgroup data_level def mer) j(year)
	//bysort year subgroup: summarize mth_ rla_
	tabstat mth_2019 rla_2019 mth_2022 rla_2022 mth_2023 rla_2023, by(subgroup) stat(mean sd min max) nototal
restore

*-------------------------------------------------------------------------------
*absenteeism 2019 vs test scores 2019
	//twoway scatter mth_2019 rla_2019 rate2019 if subgroup == "all"
	twoway scatter mth_2019 rla_2019 rate2019, ///
	by(subgroup, title("Mean Absenteeism vs Mean Test Scores 2019")) ///
	xtitle("Absenteeism Rate 2019") ///
	ytitle("Mean Test Scores 2019") ///
	legend(order(1 "Math" 2 "Reading"))
// 	foreach subgroup in "all" "blk" "hsp" "wht" "ecd" "nec"{
// 		correlate mth_2019 rla_2019 rate2019 if subgroup == "`subgroup'"}
	correlate mth_2019 rla_2019 rate2019 if subgroup == "all"
	
*absenteeism 2022 vs test scores 2022
	twoway scatter mth_2022 rla_2022 rate2022, ///
	by(subgroup, title("Mean Absenteeism vs Mean Test Scores 2022")) ///
	xtitle("Absenteeism Rate 2022") ///
	ytitle("Mean Test Scores 2022") ///
	legend(order(1 "Math" 2 "Reading"))	
// 	foreach subgroup in "all" "blk" "hsp" "wht" "ecd" "nec"{
// 		correlate mth_2022 rla_2022 rate2022 if subgroup == "`subgroup'"
// 	}
	correlate mth_2022 rla_2022 rate2022 if subgroup == "all"

*absenteeism 2023 vs test scores 2023
	twoway scatter mth_2023 rla_2023 rate2023, ///
	by(subgroup, title("Mean Absenteeism vs Mean Test Scores 2023")) ///
	xtitle("Absenteeism Rate 2023") ///
	ytitle("Mean Test Scores 2023") ///
	legend(order(1 "Math" 2 "Reading"))
	correlate mth_2023 rla_2023 rate2023 if subgroup == "all"

*absenteeism 2022 vs test scores 2023 (does last years absenteeism affect this year's scores?)
	twoway scatter mth_2023 rla_2023 rate2022 if subgroup == "all"
	
*absenteeism change 19-22 vs test scores change 19-22
	twoway scatter mth_1922 rla_1922 rate_1922, by(subgroup) ///
	xtitle("Change in Absenteeism Rate 2019-2022") ///
	ytitle("Change in Mean Test Scores 2019-2022")

*absenteeism change 19-23 vs test scores change 19-23
	twoway scatter mth_1923 rla_1923 rate_1923, by(subgroup) ///
	xtitle("Change in Absenteeism Rate 2019-2023") ///
	ytitle("Change in Mean Test Scores 2019-2023")

*absenteeism change 22-23 vs test scores change 22-23
	twoway scatter mth_2223 rla_2223 rate_2223, by(subgroup) ///
	xtitle("Change in Absenteeism Rate 2022-2023") ///
	ytitle("Change in Mean Test Scores 2022-2023")

*absenteeism in 2022 related to change in scores from 19-22
	twoway scatter mth_1922 rla_1922 rate2022, by(subgroup) ///
	xtitle("Absenteeism Rate 2022") ///
	ytitle("Change in Mean Test Scores 2019-2022")

*absenteeism in 2023 related to change in scores from 22-23
	twoway scatter mth_2223 rla_2223 rate2023, by(subgroup) ///
	xtitle("Absenteeism Rate 2023") ///
	ytitle("Change in Mean Test Scores 2022-2023")
 *--------------------------------------------------------------------------
*8/27 - restrict absenteeism to grades k-8 (will lose subgroup data)--------
tempfile ${state}_seda
u "${analysis}/seda2023.dta", clear
	keep if state == "${state}"
	keep fips stateabb sedaadmin subject subgroup ys_mn_2019_ol ys_mn_2022_ol ys_mn_2023_ol ys_mn_1923_ol ys_mn_1922_ol ys_mn_2223_ol
	ren stateabb state_abb 
	ren sedaadmin nces_district_id
	reshape wide ys*, i(state_abb nces_district_id subgroup) j(subject) string
	
save ${state}_seda, replace
	
*merge
u "${clean}/clean_${state}.dta", clear
	gen subgroup_grade = ""
	replace subgroup_grade = subgroup
	replace subgroup_grade = grade if subgroup == "all"
	drop subgroup grade
	keep if data_level == "district"
	drop if missing(nces_district_id)
	drop state_district_id state_school_id nces_school_id schoolname
	drop if subgroup_grade == "ftr" | subgroup_grade == "nfr"

	bysort district_name year: egen avg_rate = mean(rate) if subgroup_grade == "PreK-5" | subgroup_grade == "6-8"
	bysort district_name year: replace rate = avg_rate if subgroup_grade == "PreK-5" | subgroup_grade == "6-8"
	drop if subgroup_grade == "PreK-5"
	drop if subgroup_grade == "all"
	replace subgroup_grade = "all" if subgroup_grade == "6-8"
	drop avg_rate

	reshape wide rate, i(state_abb fips district_name nces_district_id subgroup_grade data_level def mer) j(year)
	
	ren subgroup_grade subgroup
	
	
	merge m:1 state_abb fips nces_district_id subgroup using ${state}_seda
 	drop if _merge != 3
	gen rate_1923 = rate2023 - rate2019
	gen rate_1922 = rate2022 - rate2019
	gen rate_2223 = rate2023 - rate2022
	
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

*absenteeism 2019 vs test scores 2019
	//twoway scatter mth_2019 rla_2019 rate2019 if subgroup == "all"
	twoway scatter mth_2019 rla_2019 rate2019, ///
	by(subgroup, title("Mean Absenteeism vs Mean Test Scores 2019")) ///
	xtitle("Absenteeism Rate 2019") ///
	ytitle("Mean Test Scores 2019") ///
	legend(order(1 "Math" 2 "Reading"))
	correlate mth_2019 rla_2019 rate2019 if subgroup == "all"
	
*absenteeism 2022 vs test scores 2022
	twoway scatter mth_2022 rla_2022 rate2022, ///
	by(subgroup, title("Mean Absenteeism vs Mean Test Scores 2022")) ///
	xtitle("Absenteeism Rate 2022") ///
	ytitle("Mean Test Scores 2022") ///
	legend(order(1 "Math" 2 "Reading"))	
	correlate mth_2022 rla_2022 rate2022 if subgroup == "all"
	

*absenteeism 2023 vs test scores 2023
	twoway scatter mth_2023 rla_2023 rate2023, ///
	by(subgroup, title("Mean Absenteeism vs Mean Test Scores 2023")) ///
	xtitle("Absenteeism Rate 2023") ///
	ytitle("Mean Test Scores 2023") ///
	legend(order(1 "Math" 2 "Reading"))
	correlate mth_2023 rla_2023 rate2023 if subgroup == "all"




