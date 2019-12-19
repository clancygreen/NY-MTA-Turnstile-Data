version 16.0

do header.do

****MTA TURNSTILE DATA PREP AND CLEANING****

*By Kevin McCaffrey, Ivan Khilko, and Maureen Ballard 
*August 2014

//Frye
//Created: 2-25-2018
//Updated: 6-6-2018 DF		//Modified data to account for new subway data post 2014
//Run: 6-6-2018 DF

***DATASET BUILDING***



//==============================================================================
//
//==============================================================================

//Append Wall St 45 Data to Original Data
use "$subway_raw/data_prepared.dta", clear
append using "$subway_raw/Wall_St_45_prepared.dta"

//Append New Data
append using "$subway_raw/data_prepared_newyears.dta"

//Determine if remotes have different groups
//Generate Group ID for Each Remote
egen remote_grp = group(remote)

* Process by remote group (groups) to avoid slowdown caused by lack of memory.
* This is doable bc identifier varies with remote group, so by-variables 
* in the code below never cross remote group boundaries.

* Note: This requires a tmp directory large enough to hold a several gig file. 
*       If that's an issue, change tmp directory by changing shell variable TMPDIR
*       or write an ordinary file. 
tempfile remote_grps_together
save `remote_grps_together' 

summ remote_grp
local min_remote_grp = `r(min)'
local max_remote_grp = `r(max)'

* Number of remote groups to process together.
local p 100

* Loop over every remote grp, since the end grp may not be multiple of p.
forv rg = `min_remote_grp' / `max_remote_grp' {

    * Get first rg in processing group.
    if mod(`rg', `p') == 1 {
        local min_in_pg `rg'
    }

    * Restrict to rg on load.
    if mod(`rg', `p') == 0 | `rg' == `max_remote_grp' {
        di ""
        di "Processing remote grps `min_in_pg'-`rg' of `max_remote_grp'"
        di ""

        use `remote_grps_together' if remote_grp >= `min_in_pg' & remote_grp <= `rg', clear
    }
    else {
        * Jump to top of loop.
        continue
    }

    * Group var should be continuous, so count should never be 0.
    count
    assert `r(N)' > 0

    //Add Time Information
    *Create Full Date Variable
    gen double datetime = statadate*24*60*60*1000 + statatime
    format datetime %tcNN/DD/CCYY_HH:MM:SS
    bys identifier (statadate statatime): gen double firstobs = datetime[1]
    gen negdatetime = -datetime
    bys identifier (negdatetime): gen double lastobs = datetime[1]
    drop negdatetime
    sort identifier datetime

    gen dategap_min = (lastobs-firstobs)/60000
    gen dategap_days = dategap_min/1440

    //Check that within Remote, they follow the same hour bin structure

    //Generate Time Groups
    gen hour = hh(statatime)
    gen grp_0 = (hour==0 | hour==4 | hour==8 | hour==12 | hour==16 | hour==20)
    gen grp_1 = (hour==1 | hour==5 | hour==9 | hour==13 | hour==17 | hour==21)
    gen grp_2 = (hour==2 | hour==6 | hour==10 | hour==14 | hour==18 | hour==22)
    gen grp_3 = (hour==3 | hour==7 | hour==11 | hour==15 | hour==19 | hour==23)

    //Generate Group Totals
    forvalues i=0(1)3 {
         bys remote_grp: egen max_bin_`i' = max(grp_`i')
         bys remote_grp: egen tot_bin_`i' = total(grp_`i')
    }
         
    //Build Lagged Obs & Per Hour Flows
    foreach var in entries exits {
        bys identifier (datetime): gen l_diff_`var' = diff_`var'[_n-1]
        bys identifier (datetime): gen f_diff_`var' = diff_`var'[_n+1]
        
        gen l_`var'flowperhr = l_diff_`var'/4
        gen `var'flowperhr = diff_`var'/4
        gen f_`var'flowperhr = f_diff_`var'/4
    }

    //Identify most popular time category (less popular categories will be adjusted to the most popular category)
    egen totbinmax = rowmax(tot_bin_0 tot_bin_1 tot_bin_2 tot_bin_3)

    gen conformbin = .
    gen initbin = .

    forvalues i=0(1)3 {
        replace initbin = `i' if grp_`i'==1
        replace conformbin = `i' if tot_bin_`i' == totbinmax
    }
        
    gen hrsincurrbin = .
    gen hrsinprevbin = .
    gen hrsinnextbin = .
        
    //Exact Matches
    replace hrsincurrbin = 4 if initbin==conformbin
    replace hrsinprevbin = 0 if initbin==conformbin
    replace hrsinnextbin = 0 if initbin==conformbin	
            
    //Partial Matches
    * Run as a loop
    forvalues i=0(1)3 {
        replace hrsincurrbin = 3 if initbin==`i' & conformbin==`i'+1
        replace hrsinprevbin = 0 if initbin==`i' & conformbin==`i'+1
        replace hrsinnextbin = 1 if initbin==`i' & conformbin==`i'+1
        
        replace hrsincurrbin = 2 if initbin==`i' & conformbin==`i'+2
        replace hrsinprevbin = 0 if initbin==`i' & conformbin==`i'+2
        replace hrsinnextbin = 2 if initbin==`i' & conformbin==`i'+2				
        
        replace hrsincurrbin = 3 if initbin==`i' & conformbin==`i'+3
        replace hrsinprevbin = 1 if initbin==`i' & conformbin==`i'+3
        replace hrsinnextbin = 0 if initbin==`i' & conformbin==`i'+3
        
        replace hrsincurrbin = 3 if initbin==`i' & conformbin==`i'-1
        replace hrsinprevbin = 1 if initbin==`i' & conformbin==`i'-1
        replace hrsinnextbin = 0 if initbin==`i' & conformbin==`i'-1
        
        replace hrsincurrbin = 2 if initbin==`i' & conformbin==`i'-2
        replace hrsinprevbin = 2 if initbin==`i' & conformbin==`i'-2
        replace hrsinnextbin = 0 if initbin==`i' & conformbin==`i'-2				
        
        replace hrsincurrbin = 3 if initbin==`i' & conformbin==`i'-3
        replace hrsinprevbin = 0 if initbin==`i' & conformbin==`i'-3
        replace hrsinnextbin = 1 if initbin==`i' & conformbin==`i'-3
    }
            
    //Create New Time Variable for
    gen conformtime=.
    forvalues i=0(1)3 {
        forvalues j=1(1)3 {
            replace conformtime = hour + `j' if initbin==`i' & conformbin==`i'+`j'
            replace conformtime = hour - `j' if initbin==`i' & conformbin==`i'-`j'
        }
    }
        
    replace conformtime = hour if initbin==conformbin
                            
    //Create New Weighted Average Entries & Exits
    foreach var in entries exits {
        gen `var'_flow_adj = `var'flowperhr * hrsincurrbin + l_`var'flowperhr*hrsinprevbin + f_`var'flowperhr*hrsinnextbin
    }
                    
    //Generate New Date/Time Variable
                
    gen double statadateconformtime = dhms(statadate, conformtime,0,0)

    save "$subway_raw/data_prepared_final.dta", replace

    //erase "/Users/`dir'/Dropbox/Uber/Data/RawSubwayData/data_prepared.dta"

    //erase "/Users/`dir'/Dropbox/Uber/Data/RawSubwayData/Wall_St_45_prepared.dta"

    use "$subway_raw/data_prepared_final.dta", clear			

    //Keep Only Necessary Vars
    keep station remote identifier booth turnstile dayofweek weekday DST station_latlongname lat_deg long_deg entries_flow_adj exits_flow_adj statadateconformtime conformbin	

    order station remote identifier booth turnstile statadateconformtime conformbin dayofweek weekday DST station_latlongname lat_deg long_deg entries_flow_adj exits_flow_adj 
        
    // Collapse Data to Station Level - CA-Unit
    collapse (sum) entries_flow_adj exits_flow_adj (mean) lat_deg long_deg (first) dayofweek weekday DST station_latlongname, by(remote statadateconformtime)

    // Drop First Obs with No Entries/Exits	
    bys remote: gen temp=_n
    drop if temp==1
    drop temp
        
    // Format Date
    format statadateconformtime %tc

    * Save with max remote group.
    tempfile tmp_rg_`rg'
    save `tmp_rg_`rg''
}

di ""
di "Appending rg files"
di ""

clear

* Append remote group files
forv rg = `min_remote_grp' / `max_remote_grp' {
    if mod(`rg', `p') == 0 | `rg' == `max_remote_grp' {
        * If multiple of p OR max remote group, there should be tempfile saved.
        append using `tmp_rg_`rg''
    }
    else {
    }
}

//Save Collapsed Data
save "$data/subwaydata_collapsed_final_cg.dta", replace
