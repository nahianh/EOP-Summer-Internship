* MD Data Checks
* nahian
* created 8/16, updates: 8/19, 8/26

* set pathways
	clear all
	
	ssc install mdesc
	
	glob state MD
	
	if "`c(username)'" ==  "nahian" {
		glob data "/home/nahian/EOP/kra/raw"
		glob clean "/home/nahian/EOP/kra/clean"
		glob output "/home/nahian/EOP/kra/output"
	}
*------------------------------------------------
*verify that 2015 totscores are actually totscores and not enrollment
use "${clean}/md_all_wide.dta", clear
	keep if year == 2015
	drop if n1 == . & n2 == . & n3 == . & n_notprof == .
	*is totscores for subgroup = all always > sum of n's ?
	keep if subgroup == "all"
	egen totn = rowtotal(n1 n2 n3 n_notprof)
	gen totn_diff = totscores - totn
	sum totn_diff
 	//yes, always > "totscores". so this "totscores" is probably enrollment...  
	

*create flags for self-calculated vs reported n's
use "${clean}/md_all_wide.dta", clear
	// note: 2014 is the only year where totscores are not reported or I could not calc them (no participation_rate)
	// 2022 and 2023 have "true" totscores, true n3, and calculated n1 and n2's
		//2015 has true n3 and n_notprof (which is n1+n2), and an imposter totscores as determined above
	// 2016-2019 have calculated totscores and n's
	drop if year == 2014
	gen true_totscores = 1 if inlist(year, 2022, 2023)
	gen true_n3 = 1 if inlist(year, 2015, 2022, 2023)
	gen true_n1n2 = 1 if year == 2015
	replace true_totscores = 0 if missing(true_totscores)
	replace true_n3 = 0 if missing(true_n3)
	replace true_n1n2 = 0 if missing(true_n1n2)
	
		
*** #10: do district/school ns (across levels) add up to totscores?

* if only n3 or p3 reported, calculate n_notprof and p_notprof
	replace n_notprof = totscores - n3 if n1 == . & n2 == . & n_notprof == .
	replace p_notprof = (1 - p3) if p1 == . & p2 == . & p_notprof == .
	drop if n1 == . & n2 == . & n3 == . & n_notprof == .
	
	mdesc n*
	
	*variable for any n reported
	gen rep_n = 0
	replace rep_n = 1 if n1 != . | n2 != . | n3 != . | n_notprof != .
	
	egen totn = rowtotal(n1 n2 n3 n_notprof) if rep_n == 1 // rowtotal counts missing as 0, check if this equals total scores
	gen totn_diff = totscores - totn
	bysort year: sum totn_diff 

***Do percents (across levels) add up to 1?
use "${clean}/md_all_wide.dta", clear // note: all years should have pers
* if only n3 or p3 reported, calculate n_notprof and p_notprof
	replace n_notprof = totscores - n3 if n1 == . & n2 == . & n_notprof == .
	replace p_notprof = (1 - p3) if p1 == . & p2 == . & p_notprof == .
	
	mdesc p*
	drop if p1 == . & p2 == . & p3 == . & p_notprof == .

	
	*variable for any n reported
	gen rep_p = 0
	replace rep_p = 1 if p1 != . | p2 != . | p3 != . | p_notprof != .

	
	*variable for at least 2 pers reported
	*gen rep_p = ( (p1 != .) + (p2 != .) + (p3 != .) + (p_notprof != .) ) >= 2
	
	egen totper = rowtotal(p1 p2 p3 p_notprof) if rep_p == 1
	gen totper_diff = 1 - totper
	bysort year: sum totper_diff
	
	*check how it changes when not including p_notprof (since that is self-calculated)
	drop rep_p totper totper_diff
	keep if p_notprof == .
	gen rep_p = ( (p1 != .) + (p2 != .) + (p3 != .) ) >= 2
	egen totper = rowtotal(p1 p2 p3) if rep_p == 1
	gen totper_diff = 1 - totper
	bysort year: sum totper_diff
	//Excluding p_notprof means most observations are unusable here. Generally, means increase slightly. 
	
*------------------------------------------------		
*** #11: how much missingness is there by subgroup?
use "${clean}/md_all_wide.dta", clear
	replace n_notprof = totscores - n3 if n1 == . & n2 == . & n_notprof == .
	replace p_notprof = (1 - p3) if p1 == . & p2 == . & p_notprof == .
	drop if n1 == . & n2 == . & n3 == . & n_notprof == .
	drop if p1 == . & p2 == . & p3 == . & p_notprof == .

	keep if districtflag == 1
	keep name year subgroup domain totscores
	keep if !missing(totscores)
	
	reshape wide totscores, i(name domain year) j(subgroup) string
	
	* for what percent of district-domain-years that we have all scores do we have each subgroup?
	mdesc

	
use "${clean}/md_all_wide.dta", clear
	*bysort year: tab subgroup
	replace n_notprof = totscores - n3 if n1 == . & n2 == . & n_notprof == .
	replace p_notprof = (1 - p3) if p1 == . & p2 == . & p_notprof == .
	drop if n1 == . & n2 == . & n3 == . & n_notprof == .
	*drop if p1 == . & p2 == . & p3 == . & p_notprof == .

	keep if districtflag == 1
	keep if !missing(totscores)
	
	*variable for any n reported
	gen rep_n = 0
	replace rep_n = 1 if n1 != . | n2 != . | n3 != . | n_notprof != .

	*variable for at least 2 n's reported 
	*replace rep_n = ( (n1 != .) + (n2 != .) + (n3 != .) + (n_notprof != .) ) >= 2 
	
	egen totn = rowtotal(n1 n2 n3 n_notprof) if rep_n == 1
	
	drop rep_n
	drop p3_true
	drop participation_rate
	
	ren name districtname
	ren nces_id id_nces
	ren n_notprof n12
	ren p_notprof per12
	ren p3 per3
	ren p2 per2
	ren p1 per1
	
	
	reshape wide tot* n* per*, i(state_id districtname year test_period domain) j(subgroup) string
	
*------------------------------------------------	
* are frl and nfl always missing together?
	gen missingfrl = totnfrl == .
	gen missingnfl = totnnfl == .
	tab missingfrl missingnfl 
	//4 cases where frl missing but nfl not, 
	
	sum totscoresall if missingfrl | missingnfl // ?

* if missing frl or nfl, how many students in the other group?
	gen pct_rep = totnfrl/totnall if missingnfl
	replace pct_rep = totnnfl/totnall if missingfrl
	sum pct_rep // ?
	
* in places that have both frl and nfl do they add to all subgroup?
	gen total = totnfrl + totnnfl
	gen reprate = total / totnall 
	sum reprate // very close mean = .9999851 
*------------------------------------------------
* are iep and nep always missing together?
	gen missingiep = totniep == .
	gen missingnep = totnnep == .
	tab missingiep missingnep
	//8 cases where iep missing but nep not. 4 cases where nep missing but iep not.
	sum totscoresall if missingiep | missingnep

* if missing iep or nep, how many students in the other group?
	drop pct_rep total reprate
	gen pct_rep = totniep/totnall if missingnep
	replace pct_rep = totnnep/totnall if missingiep
	sum pct_rep
* in places that have both iep and nep do they add to all subgroup?
	gen total = totniep + totnnep
	gen reprate = total / totnall 
	sum reprate 	 // yes, mean = 1
*------------------------------------------------
* are ell and nel always missing together?
	gen missingell = totnell == .
	gen missingnel = totnnel == .
	tab missingell missingnel
	//18 cases where ell missing but nel not. 37 cases where nel missing but nel not.
	sum totscoresall if missingell | missingnel

* if missing ell or nel, how many students in the other group?
	drop pct_rep total reprate
	gen pct_rep = totnell/totnall if missingnel
	replace pct_rep = totnnel/totnall if missingell
	sum pct_rep
* in places that have both ell and nel do they add to all subgroup?
	gen total = totnell + totnnel
	gen reprate = total / totnall 
	sum reprate 	// very close, mean = .999834 
*------------------------------------------------	
* are mal and fem always missing together?
	gen missingmal = totnmal == .
	gen missingfem = totnfem == .
	tab missingmal missingfem
	//mal and fem are always missing together
	sum totscoresall if missingmal | missingfem
	
* if missing mal or fem, how many students in the other group?
	drop pct_rep total reprate
	gen pct_rep = totnmal/totnall if missingfem
	replace pct_rep = totnfem/totnall if missingmal
	sum pct_rep //0 observations

* in places that have both mal and fem do they add to all subgroup?
	gen total = totnmal + totnfem
	gen reprate = total / totnall 
	sum reprate // very close, mean = .9998448
	
*------------------------------------------------	
* are races always missing together?
	gen missingasn = totnasn == .
	gen missingblk = totnblk == .
	gen missinghsp = totnhsp == .
	gen missingmtr = totnmtr == .
	gen missingnam = totnnam == .
	gen missingwht = totnwht == .
	gen missingnhp = totnnhp == .
	gen nmissing = missingasn + missingblk + missinghsp + missingmtr + missingnam + missingwht + missingnhp
	tab nmissing
	table domain nmissing, nototal

* is there less missingness among bigger subgroups?
	gen nmissing_abhw = missingasn + missingblk + missinghsp + missingwht 
	tab nmissing_abhw
	table domain nmissing_abhw, nototal

* in places that have all race/eth do they add to all subgroup?
	drop total reprate
	gen  total = totnasn + totnblk + totnhsp + totnmtr + totnnam + totnwht + totnnhp
	gen  reprate = total / totnall 
	sum reprate //yes
* in places that do not have all race/eth - how close are they to all subgroup?
	drop total reprate
	egen total = rowtotal(totnasn totnblk totnhsp totnmtr totnnam totnwht totnnhp) 
		// use rowtotal for adding that ignores missing values
	gen  reprate = total / totnall 
	sum reprate if nmissing != 0 //mean = 0.562


	drop missing* nmiss* total reprate pct_rep

//------------------------------------------------------------------------------
*Data Exploration

use "${clean}/md_all_wide.dta", clear
	*bysort year: tab subgroup
	replace n_notprof = totscores - n3 if n1 == . & n2 == . & n_notprof == .
	replace p_notprof = (1 - p3) if p1 == . & p2 == . & p_notprof == .
	drop if n1 == . & n2 == . & n3 == . & n_notprof == .
	*drop if p1 == . & p2 == . & p3 == . & p_notprof == .

	*keep if districtflag == 1
	*keep if !missing(totscores)
	
	*variable for any n reported
	gen rep_n = 0
	replace rep_n = 1 if n1 != . | n2 != . | n3 != . | n_notprof != .

	*variable for at least 2 n's reported 
	*replace rep_n = ( (n1 != .) + (n2 != .) + (n3 != .) + (n_notprof != .) ) >= 2 
	
	egen totn = rowtotal(n1 n2 n3 n_notprof) if rep_n == 1
	
	drop rep_n
	*drop p3_true
	*drop participation_rate
	
	ren name districtname
	ren nces_id id_nces
	ren n_notprof n12
	ren p_notprof per12
	ren p3 per3
	ren p2 per2
	ren p1 per1
	
	
	*reshape wide tot* n* per*, i(state_id districtname year test_period domain) j(subgroup) string
*--------------------------------------------------------------------------------
*do district ns sum to state-wide ns?
preserve
	collapse (sum) n1 n2 n3 totscores totn, by(year subgroup domain stateflag) fast
	gen flag = "state" if stateflag == 1
	replace flag = "dist" if stateflag == 0
	drop stateflag	
	table year subgroup domain flag, stat(sum totscores) nototals
	//2021 has big diffs
	
	reshape wide n? tot*, i(year domain subgroup) j(flag) string

	foreach v in n1 n2 n3 totscores totn {
		g `v'resid = `v'state - `v'dist
		g `v'residpct = `v'resid/`v'state
	}		
		
	g sharerep = 1 - totnresidpct
	su sharerep if subg == "all" // mean .9824333  
	bysort subgroup: su sharerep // lower for subgroups (but fem has mean 1.068)
		
	table domain, stat(mean sharerep)
	table domain subgroup, stat(mean sharerep) nformat(%5.4f)
restore

*** check score distribution ---------------------------------------------------
*** how many districts are missing scores in score levels? 
keep if subgroup == "all" 
*gen flag_levs  = (n1 != 0) + (n2 != 0) + (n3 != 0) + (n12 != 0)
gen flag_levs  = (n1 != .) + (n2 != .) + (n3 != .) + (n12 != .)
gen flag_drop = flag_levs <= 2 // binary indicator indicating if row has less than 2 levels with >0.
preserve
	keep if stateflag == 0
	table flag_levs domain
	table domain, stat(mean flag_drop) 
restore

*how are students distributed across score levels? 
reshape long n per, i(id districtname year domain subgroup) j(level)

preserve
	keep if stateflag == 1
	table level domain, stat(mean per) nformat(%5.2f) nototals
restore

sort year level domain
by year level domain: egen med = median(per)
by year level domain: egen lqt = pctile(per), p(25)
by year level domain: egen uqt = pctile(per), p(75)

*** boxplot of percent in each score level
foreach yr of numlist 2014/2022{
	preserve
	keep if year == `yr'
	set scheme stcolor_alt
	#d ;
		twoway 
			(rbar lqt med level, pstyle(p1) barw(.5) fcolor(white))
			(rbar med uqt level, pstyle(p1) barw(.5) fcolor(white))
			(scatter per level, pstyle(p1) mcolor(%10) msymbol(Oh))
			(scatter per level if stateflag == 1, msymbol(D)),
			by(domain) ytitle(percent of students in score level, size(3)) xtitle("score level",size(3))
			legend(order(3 "district" 4 "state") size(2));
		#d cr
			
	graph export "${output}/boxplot md kra score level_`yr'.png", width(1280) replace
	restore
}


*** count districts, scores over time ------------------------------------------
*** #9: how consistent is the number of scores over time? // do districts get phased in  or do students from different districts get added?

* check how many totscores in each year
preserve
	keep if stateflag == 1
	keep if domain == "overall"
	keep year totscores
	gen type = "Totscores"
	tempfile n_scores
	save `n_scores'
restore

* check how many unique districts in each year
preserve
	keep if stateflag == 0
	keep year id districtname
	duplicates drop
	gen n = 1
	collapse (sum) totscores = n, by(year)
	gen type = "Districts"
	append using `n_scores'
	
	* plot increase in totscores v increase in n_districts
	* look for a jump in districts and/or a jump in state totscores 
	#d;
		twoway
		(connected totscores year, yaxis(1) lcolor(stblue) leg(off)),
		xline(2014)
		by(type, yrescale)
		ytitle(n)
		xlabel(2014(1)2023)
		xsize(13.33) ysize(7.5);
	#d cr
	
	graph export "${output}/md kra n_scores v n_dist over time.png", width(1280) replace
	
restore

* then check ns in each district in each year (as percent of enrollment) // skip - do not have enrollment data yet 
// keep if domain == "cog"
drop med lqt uqt
//
// merge m:1 id year subgroup using "${kra_data}/ky/clean data/ky_enrollment.dta"
// keep if _merge == 3
// drop _merge
//
// gen reprate = totscores/enrolledKG

sort year 
by year: egen med = median(participation_rate)
by year: egen lqt = pctile(participation_rate), p(25)
by year: egen uqt = pctile(participation_rate), p(75)
	
#d;
	twoway 
		(rbar lqt med year, pstyle(p1) barw(.5) fcolor(white) leg(off))
		(rbar med uqt year, pstyle(p1) barw(.5) fcolor(white) leg(off))
		(scatter participation_rate year if participation_rate < 2, pstyle(p1) mcolor(%20) msymbol(Oh) leg(off)),
		xline(2018)
		ytitle("percent of enrollment (by district)") 
		xlabel(2014(2)2023)
		xsize(13.33) ysize(7.5);
#d cr

graph export "${output}/md scores as pct of enrollment by district over time.png", width(1280) replace


























