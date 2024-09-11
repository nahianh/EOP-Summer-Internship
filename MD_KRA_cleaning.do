* MD KRA Data Cleaning
* nahian 8/8, 8/13

* set pathways
	clear all
	
	glob state MD
	
	if "`c(username)'" ==  "nahian" {
		glob data "/home/nahian/EOP/kra/raw"
		glob clean "/home/nahian/EOP/kra/clean"
		glob ccd_data "/home/nahian/EOP/absenteeism/ccd data"
		}
		
* import 2022-2023 MCAP data----------------------------------------------------
foreach sheet in "LEA_Level" "State_Level"{
	import excel using "${data}/MCAP_KRA_2023", sheet("`sheet'") firstrow clear
	save "${data}/file_`sheet'", replace
}

	u "${data}/file_State_Level.dta", clear
	append using "${data}/file_LEA_Level.dta"

* prep
	rename *, lower 
	drop year schoolname school createdate
	
	rename leaname name
	rename lea lea_id
	rename testedcount totscores
	rename demonstratingcount n3
	rename demonstratingpct p3
	
	gen domain = "overall"
	gen subgroup = ""
	
	replace subgroup = "all" if studentgroup == "All Students"
	replace subgroup = "asn" if studentgroup == "Asian"
	replace subgroup = "nam" if studentgroup == "American Indian or Alaska Native"
	replace subgroup = "blk" if studentgroup == "Black/African American"
	replace subgroup = "hsp" if studentgroup == "Hispanic/Latino of Any Race"
	replace subgroup = "wht" if studentgroup == "White"
	replace subgroup = "mtr" if studentgroup == "Two or More Races"
	replace subgroup = "nhp" if studentgroup == "Native Hawaiian or Other Pacific Islander"
	replace subgroup = "frl" if studentgroup == "Economically Disadvantaged"
	replace subgroup = "nfl" if studentgroup == "Non-economically Disadvantaged"
	replace subgroup = "mal" if studentgroup == "Male"
	replace subgroup = "fem" if studentgroup == "Female"
	replace subgroup = "ell" if studentgroup == "English Learner"
	replace subgroup = "iep" if studentgroup == "Students with Disabilities"
	replace subgroup = "nep" if studentgroup == "Students without Disabilities" 
	
	drop studentgroup
	
	order subgroup, b(totscores)
	order domain, b(n3)
	
	save "${data}/state_lea_2023", replace
	
	*u "${data}/state_lea_2023"
	
* merge in the pdf data
	clear all
	import delimited "${data}/raw_MD_2023.csv", varnames(1) 
	
	drop column1
	
	replace name = "Prince George's" if name == "Prince George’s"
	replace name = "Queen Anne's" if name == "Queen Anne’s"
	replace name = "Saint Mary's" if name == "St. Mary’s"
	replace name = "State" if name == "Maryland State"
		
	merge 1:1 name subgroup domain using "${data}/state_lea_2023.dta", keep(1 2 3)
	
	sort name
	
	order totscores, b(domain)
	order p3, a(pers_demo)
	order n3, a(p3)
	
	replace pers_demo = p3 if missing(pers_demo) & !missing(p3)
	
	save "${data}/merged_2023", replace

* clean up data
** convert to numeric: tot_enrlmt, p_rate, totscores, pers_demo, n3, pers_appr, pers_emer, score
	u "${data}/merged_2023", clear
	replace subgroup = "nhp" if subgroup == "hpi" //(fixing a mistake 8/13)
	
foreach col in tot_enrlmt p_rate totscores pers_demo n3 pers_appr pers_emer score{
	
	replace `col'= subinstr(`col', ",", "", .)
	replace `col'= subinstr(`col', "%", "", .)
	replace `col'= subinstr(`col', "NA", "", .)
	replace `col'= subinstr(`col', "*", "", .)
	*replace `col' = "" if strpos(`col', "<") > 0
	*replace `col' = subinstr(`col', "<= 5.0", "", .)
	
	destring `col', replace
	
}

foreach col in p_rate pers_demo pers_appr pers_emer{
	replace `col' = `col' /100
	
}

** fill in the blanks for tot_enrlmt, p_rate
levelsof name, local(names)
local cols tot_enrlmt p_rate
foreach n of local names {
    foreach col of local cols{
	     qui su `col' if name == "`n'" & subgroup == "all" & domain == "overall", meanonly
	     local target_value = r(mean)   
	     replace `col' = `target_value' if name == "`n'" & missing(`col')
    }
       
}



	rename p3 p3_true
	order p3_true, last
	
	rename pers_demo p3
	rename pers_appr p2
	rename pers_emer p1
	
	gen n2 = .
	gen n1 = .
	
	order n2, a(p2)
	order n1, a(p1)
	
** calc n1, n2

levelsof name, local(names)	
foreach n of local names{
	*store totscores
	qui su totscores if name == "`n'" & subgroup == "all" & domain == "overall", meanonly
	local totscore_value = r(mean) 
	*store true n3
	qui su n3 if name == "`n'" & subgroup == "all" & domain == "overall", meanonly
	local true_n3 = r(mean) 	
	*store pers approaching (p2)
	qui su p2 if name == "`n'" & subgroup == "all" & domain == "overall", meanonly
	local pers_appr = r(mean)
	*store pers emerging (p1)
	qui su p1 if name == "`n'" & subgroup == "all" & domain == "overall", meanonly
	local pers_emer = r(mean) 	
	
	*calculate
	replace n2 = round((`pers_appr' / (`pers_appr' + `pers_emer')) * (`totscore_value' - `true_n3')) if name == "`n'" & subgroup == "all" & domain == "overall"
	replace n1 = round((`pers_emer' / (`pers_appr' + `pers_emer')) * (`totscore_value' - `true_n3')) if name == "`n'" & subgroup == "all" & domain == "overall"
	
	*calc p_rate
	replace p_rate = `totscore_value' / tot_enrlmt if name == "`n'" & subgroup == "all" & domain == "overall" & missing(p_rate)
	
}	

* fill in missing lea_id
levelsof name, local(names)	

foreach n of local names{
	qui{
		preserve
		keep if name == "`n'" & !missing(lea_id)
		if _N > 0 {
			local target_value = lea_id[1]
			restore
			replace lea_id = "`target_value'" if name == "`n'" & missing(lea_id)
		}
		else {
			restore
		}
	}

}	
	
* cleaning
	drop _merge
	gen year = 2022 //fall year
	gen test_period = 1 
	gen maxcat = 3
save "${data}/merged_2023", replace
	
* import 2021-2022 MCAP data----------------------------------------------------
clear all
foreach sheet in "LEA_Level" "State_Level (weighted)"{
	import excel using "${data}/MCAP_KRA_2022", sheet("`sheet'") firstrow clear
	save "${data}/file_`sheet'_22", replace
}

	u "${data}/file_State_Level (weighted)_22.dta", clear
	
	gen TestedCount2 = ""
	replace TestedCount2 = string(TestedCount, "%10.0g")
	drop TestedCount
	ren TestedCount2 TestedCount
	
	gen DemonstratingReadinessCount2 = ""
	replace DemonstratingReadinessCount2 = string(DemonstratingReadinessCount, "%10.0g")
	drop DemonstratingReadinessCount
	ren DemonstratingReadinessCount2 DemonstratingReadinessCount	

	gen DemonstratingReadinessPct2 = ""
	replace DemonstratingReadinessPct2 = string(DemonstratingReadinessPct, "%10.0g")
	drop DemonstratingReadinessPct
	ren DemonstratingReadinessPct2 DemonstratingReadinessPct	
	
	append using "${data}/file_LEA_Level_22.dta"

* prep before merging in pdf data
	rename *, lower 
	drop if leaname == ""
	keep lea leaname schoolname studentgroup testedcount demonstratingreadinesscount demonstratingreadinesspct
	
	rename leaname name
	rename lea lea_id
	rename testedcount totscores
	rename demonstratingreadinesscount n3
	rename demonstratingreadinesspct p3_true
	
	gen domain = "overall"
	rename studentgroup subgroup
	
	replace subgroup = "all" if subgroup == "All Students"
	replace subgroup = "asn" if subgroup == "Asian"
	replace subgroup = "nam" if subgroup == "American Indian or Alaska Native"
	replace subgroup = "blk" if subgroup == "Black or African American"
	replace subgroup = "hsp" if subgroup == "Hispanic/Latino of Any Race"
	replace subgroup = "wht" if subgroup == "White"
	replace subgroup = "mtr" if subgroup == "Two or More Races"
	replace subgroup = "nhp" if subgroup == "Native Hawaiian or Other Pacific"
	replace subgroup = "frl" if subgroup == "Economically Disadvantaged"
	replace subgroup = "nfl" if subgroup == "Non-economically Disadvantaged"
	replace subgroup = "mal" if subgroup == "Male"
	replace subgroup = "fem" if subgroup == "Female"
	replace subgroup = "ell" if subgroup == "English Learners"
	replace subgroup = "iep" if subgroup == "Students with Disabilities"
	replace subgroup = "nep" if subgroup == "Students without Disabilities" 
		
	order subgroup, b(totscores)
	order domain, b(n3)
	
	save "${data}/state_lea_2022", replace
	u "${data}/state_lea_2022", clear
	drop schoolname
	replace subgroup = trim(subgroup)
	replace domain = trim(domain)
	replace name = trim(name)
	save "${data}/state_lea_2022", replace

* merge in pdf data	
	clear all
	import delimited "${data}/raw_MD_2022.csv", varnames(1) 
	replace subgroup = "nhp" if subgroup == "hpi"
	
	drop column1
	replace name = subinstr(name, "County", "", .)
	replace name = "Baltimore County" if name == "Baltimore "
	replace name = "State" if name == "Maryland State"
	replace name = subinstr(name, "âs", "", .)
	replace name = "Prince George's" if name == "Prince George "
	replace name = "Queen Anne's" if name == "Queen Anne "
	replace name = "St. Mary's" if name == "St. Mary "
	
	replace subgroup = trim(subgroup)
	replace domain = trim(domain)
	replace name = trim(name)


	merge 1:1 name subgroup domain using "${data}/state_lea_2022.dta", keep(1 2 3)
	
	sort name
	
	order totscores, b(domain)
	order p3_true, a(pers_demo)
	order n3, a(p3_true)
	
	replace pers_demo = p3_true if missing(pers_demo) & !missing(p3_true)
	
	save "${data}/merged_2022", replace

* create a census (1) vs sample (0) flag
	u "${data}/merged_2022", clear
	gen census = .
	replace census = 1 if p_rate == "CENSUS"
	replace census = 0 if p_rate == "SAMPLE"
	
	replace p_rate = "" if p_rate == "CENSUS"
	replace p_rate = "" if p_rate == "SAMPLE"
	
* convert str to numeric
foreach col in tot_enrlmt p_rate totscores pers_demo n3 pers_appr pers_emer score{
	
	replace `col'= subinstr(`col', ",", "", .)
	replace `col'= subinstr(`col', "%", "", .)
	replace `col'= subinstr(`col', "NA", "", .)
	replace `col'= subinstr(`col', "*", "", .)
	*replace `col' = "" if strpos(`col', "<") > 0
	*replace `col' = subinstr(`col', "<= 5.0", "", .)
	
	destring `col', replace
	
}

foreach col in p_rate pers_demo pers_appr pers_emer{
	replace `col' = `col' /100
	
}

** fill in the blanks for tot_enrlmt, p_rate, census
levelsof name, local(names)
local cols tot_enrlmt p_rate census
foreach n of local names {
    foreach col of local cols{
	     qui su `col' if name == "`n'" & subgroup == "all" & domain == "overall", meanonly
	     local target_value = r(mean)   
	     replace `col' = `target_value' if name == "`n'" & missing(`col')
    }
       
}

	order p3_true, last
	
	rename pers_demo p3
	rename pers_appr p2
	rename pers_emer p1
	
	gen n2 = .
	gen n1 = .
	
	order n2, a(p2)
	order n1, a(p1)
	
** calc n1, n2

levelsof name, local(names)	
foreach n of local names{
	*store totscores
	qui su totscores if name == "`n'" & subgroup == "all" & domain == "overall", meanonly
	local totscore_value = r(mean) 
	*store true n3
	qui su n3 if name == "`n'" & subgroup == "all" & domain == "overall", meanonly
	local true_n3 = r(mean) 	
	*store pers approaching (p2)
	qui su p2 if name == "`n'" & subgroup == "all" & domain == "overall", meanonly
	local pers_appr = r(mean)
	*store pers emerging (p1)
	qui su p1 if name == "`n'" & subgroup == "all" & domain == "overall", meanonly
	local pers_emer = r(mean) 	
	
	*calculate
	replace n2 = round((`pers_appr' / (`pers_appr' + `pers_emer')) * (`totscore_value' - `true_n3')) if name == "`n'" & subgroup == "all" & domain == "overall"
	replace n1 = round((`pers_emer' / (`pers_appr' + `pers_emer')) * (`totscore_value' - `true_n3')) if name == "`n'" & subgroup == "all" & domain == "overall"
	
	*calc p_rate
	replace p_rate = `totscore_value' / tot_enrlmt if name == "`n'" & subgroup == "all" & domain == "overall" & missing(p_rate)
	
}	

* fill in missing lea_id
levelsof name, local(names)	

foreach n of local names{
	qui{
		preserve
		keep if name == "`n'" & !missing(lea_id)
		if _N > 0 {
			local target_value = lea_id[1]
			restore
			replace lea_id = "`target_value'" if name == "`n'" & missing(lea_id)
		}
		else {
			restore
		}
	}

}	
	
* cleaning
	drop _merge
	gen year = 2021 //fall year
	gen test_period = 1 
	gen maxcat = 3
save "${data}/merged_2022", replace

*import & clean 16-17, 17-18, 18-19, 19-20 data (pdfs)---------------------------------------------------
clear all
local firstfile = 1
foreach springyr in 2017 2018 2019 2020{
	clear all
	import delimited "${data}/raw_MD_`springyr'.csv", varnames(1) 
	
	cap drop v1 
	cap drop Column1
	
	local fallyr = `springyr' - 1
	gen year = `fallyr'
	gen test_period = 1 
	gen maxcat = 3
	
	*clean subgroups
	replace subgroup = "nep" if subgroup == "children w/o disabilities"
	replace subgroup = "iep" if subgroup == "children w/ disabilities"
	replace subgroup = "nel" if subgroup == "english proficient"
	replace subgroup = "ell" if subgroup == "english learners"
	replace subgroup = "nfl" if subgroup == "mid-high inc"
	replace subgroup = "frl" if subgroup == "low inc"
	replace subgroup = "nhp" if subgroup == "hpi"
	
	*clean names
	drop if name == ""
	replace name = lower(name) //remember to do this for 2023 and 2022 too before merging
	replace name = trim(name)
	
	replace name = "state" if name == "maryland"
	replace name = "state" if name == "maryland state"
	
	replace name = subinstr(name, "county", "", .)
	replace name = "baltimore county" if name == "baltimore "
	
	replace name = subinstr(name, "âs", "", .) 
	replace name = subinstr(name, "’s", "", .)
	
	replace name = trim(name)
	
	replace name = "prince george's" if name == "prince george"
	replace name = "queen anne's" if name == "queen anne"
	replace name = "st. mary's" if name == "st. mary"
	replace name = "st. mary's" if name == "saint mary"
	
	replace subgroup = trim(subgroup)
	replace domain = trim(domain)
	
	*clean domains
	replace domain = "mth" if domain == "math"
	
	*rename cols: pers_demo pers_appr pers_emer
	ren pers_demo p3
	ren pers_appr p2
	ren pers_emer p1
	
	*convert to numeric: tot_enrlmt p_rate p3 p2 p1 score
	foreach col in tot_enrlmt p_rate p3 p2 p1 score{
		capture confirm variable `col'
		if !_rc {
	
			replace `col'= subinstr(`col', ",", "", .)
			replace `col'= subinstr(`col', "%", "", .)
			replace `col'= subinstr(`col', "NA", "", .)
			replace `col'= subinstr(`col', "*", "", .)
			*replace `col' = "" if strpos(`col', "<") > 0
			*replace `col' = subinstr(`col', "<= 5.0", "", .)
			
			destring `col', replace
		}
	}
	
	*convert to proportions: p_rate p3 p2 p1
	foreach col in p_rate p3 p2 p1{
		replace `col' = `col' /100
		
	}
	
	*only keep p_rate where subgroup = all and domain = overall, otherwise blank
	replace p_rate = . if !(subgroup == "all" & domain == "overall")
	
	*append datasets
	if `firstfile' {
		save "${data}/combined_17-20.dta", replace
		local firstfile = 0
	}
	else {
		append using "${data}/combined_17-20.dta"
		save "${data}/combined_17-20.dta", replace
	}
	
}
drop column1
save "${data}/combined_17-20.dta", replace

*import & clean 2015-16 data----------------------------------------------------
clear all
import delimited "${data}/raw_MD_2016v2.csv", varnames(1)
	
	drop v1

* clean names
	replace name = lower(name)
	replace name = trim(name)
	
	replace name = "state" if name == "maryland state"
	
	replace name = subinstr(name, "county", "", .)
	replace name = "baltimore county" if name == "baltimore "
	replace name = trim(name)
	replace name = "st. mary's" if name == "saint mary's"
	
	sort name subgroup domain
	
* clean domains
	replace domain = "mth" if domain == "math"
* clean subgroups
	replace subgroup = lower(trim(subgroup))
	
	replace subgroup = "blk" if subgroup == "african american"
	replace subgroup = "all" if subgroup == "aggregated data"
	replace subgroup = "nam" if subgroup == "american indian/alaskan native"
	replace subgroup = "asn" if subgroup == "asian"
	replace subgroup = "nel" if subgroup == "english language learners - no"
	replace subgroup = "ell" if subgroup == "english language learners - yes"
	replace subgroup = "fem" if subgroup == "female"
	replace subgroup = "nfl" if subgroup == "free and reduced price meals - no"
	replace subgroup = "frl" if subgroup == "free and reduced price meals - yes"
	replace subgroup = "hsp" if subgroup == "hispanic"
	replace subgroup = "mal" if subgroup == "male"
	replace subgroup = "nhp" if subgroup == "native hawaiian/pacific islander"
	replace subgroup = "nep" if subgroup == "special education - no"
	replace subgroup = "iep" if subgroup == "special education - yes"
	replace subgroup = "mtr" if subgroup == "two or more races (non-hispanic/latino)"
	replace subgroup = "wht" if subgroup == "white"
*rename cols
	ren n_demo n3
	ren n_appr n2
	ren n_emer n1
	ren pers_demo p3
	ren pers_appr p2
	ren pers_emer p1
	ren n_tested totscores
*convert to numeric

	foreach col in n_notdemo pers_notdemo n3 n2 n1 p3 p2 p1 score{
		capture confirm variable `col'
		if !_rc {
	
			replace `col'= subinstr(`col', ",", "", .)
			replace `col'= subinstr(`col', "%", "", .)
			replace `col'= subinstr(`col', "NA", "", .)
			replace `col'= subinstr(`col', "*", "", .)
			*replace `col' = "" if strpos(`col', "<") > 0
			*replace `col' = subinstr(`col', "<= 5.0", "", .)
			destring `col', replace
		}
	}
	
	*convert to proportions: pers_notdemo p3 p2 p1
	foreach col in pers_notdemo p3 p2 p1{
		replace `col' = `col' /100
		
	}
	
	order totscores, b(domain)
* generate cols
	gen year = 2015 //fall year
	gen maxcat = 3
	gen test_period = 1
save "${data}/md_2015.dta", replace

* import and clean 2014-2015 data
clear all
import delim "${data}/raw_MD_2015.csv", varnames(1)

	drop v1
*gen cols
	gen year = 2014 //fall year
	gen maxcat = 3
	gen test_period = 1

*rename cols
	ren demonstratingreadiness p3
	ren developingreadiness p2
	ren emergingreadiness p1
*clean names
	//fixing pdf scraping issues
	replace name = "prince george's" if tot_enrlmt == "10,260"
	replace name = "queen anne's" if tot_enrlmt == "544"
	replace name = "st. mary's" if tot_enrlmt == "1,342"
	
	replace name = trim(lower(name))
	
	replace name = "state" if name == "maryland state"
	
	replace name = subinstr(name, "county", "", .)
	replace name = "baltimore county" if name == "baltimore "
	replace name = trim(name)

*clean domains
	replace domain = trim(lower(domain))
	replace domain = "lanlit" if domain == "language & literacy"
	replace domain = "mth" if domain == "mathematics"
	replace domain = "phy" if domain == "physical well-being & motor development"
	replace domain = "sel" if domain == "social foundations"

*clean subgroups
	replace subgroup = trim(lower(subgroup))
	replace subgroup = "blk" if subgroup == "african american"
	replace subgroup = "nam" if subgroup == "american indian"
	replace subgroup = "asn" if subgroup == "asian"
	replace subgroup = "frl" if subgroup == "children from low-income households"
	replace subgroup = "nfl" if subgroup == "children from mid-/high income households"
	replace subgroup = "iep" if subgroup == "children w/ disability"
	replace subgroup = "nep" if subgroup == "children w/o disability"
	replace subgroup = "ell" if subgroup == "english language learners"
	replace subgroup = "nel" if subgroup == "english proficient"
	replace subgroup = "hsp" if subgroup == "hispanic"
	replace subgroup = "nhp" if subgroup == "native hawaiian/pacific islander"
	replace subgroup = "mtr" if subgroup == "two or more races"
	replace subgroup = "wht" if subgroup == "white"

*convert to numeric
	foreach col in tot_enrlmt p3 p2 p1 {
		capture confirm variable `col'
		if !_rc {
	
			replace `col'= subinstr(`col', ",", "", .)
			replace `col'= subinstr(`col', "%", "", .)
			replace `col'= subinstr(`col', "NA", "", .)
			replace `col'= subinstr(`col', "*", "", .)
			replace `col'= subinstr(`col', "demonstrate readiness", "", .)
			*replace `col' = "" if strpos(`col', "<") > 0
			*replace `col' = subinstr(`col', "<= 5.0", "", .)
			destring `col', replace
		}
	}
	
	*convert to proportions: pers_notdemo p3 p2 p1
	foreach col in p3 p2 p1{
		replace `col' = `col' /100
		
	}
save "${data}/md_2014.dta", replace
	
*------------------------------------------------------------------------------

*files to merge: md_2014.dta, md_2015.dta, combined_17-20.dta, merged_2022, merged 2023

* leaving here for easy access
// clear all
// u "${data}/md_2014.dta", clear
// u "${data}/md_2015.dta", clear
// u "${data}/combined_17-20.dta", clear
// u "${data}/merged_2022.dta", clear
//u "${data}/merged_2023.dta", clear

*prep before merging
clear all

* calc n's for 2016-2019: (added 8/19)
u "${data}/combined_17-20.dta", clear

	gen totscores = tot_enrlmt * p_rate
	order totscores, a(tot_enrlmt)
	
	gen n3 = totscores * p3
	gen n2 = totscores * p2
	gen n1 = totscores * p1
	
	order n3, a(p3)
	order n2, a(p2)
	order n1, a(p1)
save "${data}/combined_17-20.dta", replace

	*clean names
foreach yr in 2022 2023{
	u "${data}/merged_`yr'.dta", clear
	replace name = trim(lower(name))
	replace name = "maryland school for the deaf" if name == "md school for the deaf"
	replace name = "st. mary's" if name == "saint mary's"
	replace name = "maryland school for the blind" if name == "md school for the blind"
	save "${data}/merged_`yr'.dta", replace
	
}
*merge and save as md_working_file to keep any variables dropped later on
	u "${data}/merged_2023.dta", clear
	append using "${data}/merged_2022.dta"
	append using "${data}/combined_17-20.dta"
	append using "${data}/md_2015.dta"
	append using "${data}/md_2014.dta"
	save "${clean}/md_working_file.dta", replace

*rename variables: p_rate -> participation_rate, tot_enrlmt -> totenrolled
	ren p_rate participation_rate
	ren tot_enrlmt totenrolled
	ren n_notdemo n_notprof
	ren pers_notdemo p_notprof

*identifiers: apply state id's, then merge in nces ids
levelsof name, local(names)	
foreach n of local names{
	qui{
		preserve
		keep if name == "`n'" & !missing(lea_id)
		if _N > 0 {
			local target_value = lea_id[1]
			restore
			replace lea_id = "`target_value'" if name == "`n'" & missing(lea_id)
		}
		else {
			restore
		}
	}

}
save "${clean}/md_working_file.dta", replace

u "${ccd_data}/ccd_id_xwalk_v2.dta", clear
	tempfile ${state}_id_xwalk
	keep if state == "${state}"
	replace state_district_id = subinstr(state_district_id, "${state}-", "", .)
	keep state_district_id nces_district_id
	duplicates drop
	ren state_district_id state_id
	ren nces_district_id nces_id
save ${state}_id_xwalk, replace

u "${clean}/md_working_file.dta", clear
	ren lea_id state_id
	merge m:1 state_id using ${state}_id_xwalk
	drop if _merge == 2
	drop _merge
save "${clean}/md_working_file.dta", replace
	
*flag state-level vs district-level
	gen stateflag = .
	gen districtflag = .
	replace stateflag = 1 if name == "state"
	replace stateflag = 0 if name != "state"
	replace districtflag = 1 if name != "state"
	replace districtflag = 0 if name == "state"
*save final file as md_all_wide
save "${clean}/md_all_wide.dta", replace

*make a copy reshaped to long + levels (1, 2, 3)
u "${clean}/md_all_wide.dta", clear
	gen temp_id = _n
	drop p3_true
	ren n_notprof n12
	ren p_notprof p12

	reshape long n p, i(temp_id) j(level) 
	tostring level, replace
	replace level = "notprof" if level == "12"
	
	drop temp_id
	egen cell = group(state_id year)
	
	order year name nces_id state_id totenrolled totscores participation_rate subgroup domain level n p 

*save final file as md_all_long
save "${clean}/md_all_long.dta", replace
	
	
	
	
	
	
	
	

	
