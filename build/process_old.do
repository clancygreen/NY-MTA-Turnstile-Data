version 16.0

do header.do

**THIS SECTION CREATES THE MASTER DATASET FROM THE TEXT FILES FOR OLD FILE STRUCTURE
clear


local datafiles : dir "$subway_oldtext_dir" files "*.txt"
assert strlen(`" `datafiles' "') != 0

*Loop through the raw data files
foreach file in `datafiles' {

	*Import the next file
    di ""
	display "Importing `file'"

    qui {
        insheet using $subway_oldtext_dir/`file', clear

        *This is a special case that deals with extra text
        *at the beginning of the 7/14/2012 data file
        if "`file'" == "turnstile_120714.txt" {
            display "Dropping the first ten observations"
            drop in 1/10
            destring v7 v8 v12 v13 v17 v18 v22 v23 v27 v28 v32 v33 v37 v38 v42 v43, replace
        }
        
        *The end of the 8/25/2012 data file has an odd line at the end with "USE",
        *whose formatting doesn't fit with the other lines. This deletes the last line.
        if "`file'" == "turnstile_120825.txt" {
            local obs_total = _N
            display "Dropping the last observation"
            drop in `obs_total'
        }
        
        *In turnstile_120505.txt, there is one value of just a hyphen in v43
        *This will make sure all of the entries and exits are numeric format,
        *as long as there are no other characters besides hyphen in those fields.
        *This has to be done before the stacking; otherwise, data is lost and set to missing.
        destring v7 v8 v12 v13 v17 v18 v22 v23 v27 v28 v32 v33 v37 v38 v42 v43, replace ignore("-")
        
        *Organize the data with one observation on one line
        display "Stacking the observations"
        stack	v1 v2 v3 v4  v5  v6  v7  v8	 ///
                v1 v2 v3 v9  v10 v11 v12 v13 ///
                v1 v2 v3 v14 v15 v16 v17 v18 ///
                v1 v2 v3 v19 v20 v21 v22 v23 ///
                v1 v2 v3 v24 v25 v26 v27 v28 ///
                v1 v2 v3 v29 v30 v31 v32 v33 ///
                v1 v2 v3 v34 v35 v36 v37 v38 ///
                v1 v2 v3 v39 v40 v41 v42 v43 ///
                , into(v1 v2 v3 v4 v5 v6 v7 v8) clear
        display "Dropping empty observations from the stacking"
        drop if v7 == . | v8 == .
        drop _stack

        compress

    }
	
	save "$subway_weekly_dir/`file'.dta", replace
}

*Append all the weekly datasets together.  
clear

local datafiles : dir "$subway_weekly_dir" files  "*.txt.dta"
assert strlen(`" `datafiles' "') != 0

foreach file in `datafiles' {
   local datafiles_fullpath $subway_weekly_dir/`file' `datafiles_fullpath'
}

append using `datafiles_fullpath'

*Rename the variables
rename v1 booth
rename v2 remote
rename v3 turnstile
rename v4 date_master
rename v5 time_master
rename v6 transaction
rename v7 entries_master
rename v8 exits_master

*Set the way the entries and exits are displayed (instead of scientific notation)
format entries_master %15.0g
format exits_master %15.0g


*DATE AND TIME

*Set the date format and identify days of the week
gen int statadate = date(date_master, "MD20Y")
format statadate %td
drop date_master

gen int dayofweek = statadate
format dayofweek %tdDay

*Create dummy variable for weekday
gen byte day = dow(statadate)
gen byte weekday = 1 if day > 0 & day < 6
replace weekday = 0 if weekday != 1
drop day

*Convert time from string to numeric
gen statatime = clock( time_master, "hms")
format statatime %tc_HH:MM:SS
drop time_master

*STATION NAMES

*Merge in the station names and other info from the modified station crosswalk
*Bring in only the station-line combination and not the parts
merge m:1 remote using "$subway_raw/station_crosswalk.dta", keepusing(division station)

*Drop the handful of odd cases that don't match 
replace station = "45 RD-COURT H S" if _merge==1

//drop if _merge == 1		//Drops One Station at R508 - instead I replaced the name
drop if _merge == 2		//Drops stations with no data
drop _merge

*STATION LAT/LONG

*Merge in station names, and lat/long
mmerge remote using "$subway_raw/station_latlong.dta"

replace lat_deg=40.747615 if _merge==1
replace long_deg=-73.945069 if _merge==1

drop if _merge == 2

drop _merge

*Drop divisions that aren't part of the subway system, then remove the division variable
drop if division == "BEE" | division == "SRT" | division == "RIT"  | division == "LIB" 
drop division

order station remote booth turnstile statadate statatime transaction entries_master exits_master day dayofweek

label variable station "Station"
label variable remote "Remote"
label variable booth "Booth (Control)"
label variable turnstile "Turnstile"
label variable statadate "Date"
label variable statatime "Time"
label variable transaction "Transaction"
label variable entries_master "Entries (Master)"
label variable exits_master "Exits (Master)"
label variable dayofweek "Day of the Week"
label variable weekday "Weekday"
label define weekday 1 "Weekday" 0 "Weekend"

save "$subway_raw/data_master.dta", replace


use "$subway_raw/data_master.dta", clear

***DATA CLEANING AND PREPARATION FOR ANALYSIS***

**THIS SECTION CREATES A DAYLIGHT SAVINGS TIME DUMMY VARIABLE
*A knowledge of the Daylight Savings Time dates is crucial to working with this dataset

*Here are the dates when DST changes, with the Stata ('statadate' variable) equivalents

	*To DST		statadate		From DST	statadate
	*3/14/2010	18335			11/7/2010	18573
	*3/13/2011	18699			11/6/2011	18937
	*3/11/2012	19063			11/4/2012	19301
	*3/10/2013	19427			11/3/2013	19665
	*3/9/2014	19791			11/2/2014	20029

gen byte DST =	cond(statadate >= 18335 & statadate < 18573, 1,				///		DST
				cond(statadate >= 18573 & statadate < 18699, 0,				///		REG
				cond(statadate >= 18699 & statadate < 18937, 1,				///		DST
				cond(statadate >= 18937 & statadate < 19063, 0,				///		REG
				cond(statadate >= 19063 & statadate < 19301, 1,				///		DST
				cond(statadate >= 19301 & statadate < 19427, 0,				///		REG
				cond(statadate >= 19427 & statadate < 19665, 1,				///		DST
				cond(statadate >= 19665 & statadate < 19791, 0,				///		REG
				cond(statadate >= 19791 & statadate < 20029, 1,.)))))))))	//		DST

label variable DST "Daylight Savings Time"
label define DST 0 "Standard Time" 1 "Daylight Savings Time" 
label values DST DST

				
*Create a unique identifier for each turnstile
gen identifier = remote + " " + booth + " " + turnstile 
label variable identifier "Turnstile Identifier"
//drop booth turnstile
order identifier, after(remote)

** THIS SECTION SPLITS OUT WALL ST STATION ON THE 4/5 TRAINS INTO A SEPARATE DATASET
*Almost all turnstiles report at four-hour cycles throughout the dataset.
*At Wall St-45, all of the turnstiles report hourly, and they are the only turnstiles to do so regularly, so they are treated differently in the code.
*There are two other turnstiles that had small stretches of reporting hourly, but they didn’t seem to be reporting anything useful.
*They are: Hunts Point Ave, R146 R412 00-02-00 and Smith-9 St, R270 N536 00-02-00 (same turnstile no. -- not a mistake)

		
save "$subway_raw/DST_turnstile.dta", replace

keep if station == "WALL ST-45"
save "$subway_raw/Wall_St_45.dta", replace

use "$subway_raw/DST_turnstile.dta", clear

drop if station == "WALL ST-45"



**THIS SECTION CLEANS AND DIFFERENCES THE DATA



*This process is designed for capturing four-hour time blocks.
*If daily totals are desired, possible approaches include: 
*differencing from the last scheduled reporting time of the day to the same time the previous day
*differencing at the four-hour level, as below, then summing the differences if all six daily four-hour blocks are accounted for
*The first method is probably best, so one missed report doesn't necessarily remove the whole day from consideration for a given turnstile.

*Keep only those observations that occur on the hour
keep if mod(statatime, 3600000) == 0

*Create and sort by a heirarchy of transaction codes (for time duplicates)
*This is based on the frequency with which these codes appear in the data as well as our limited knowledge of the meaning of the codes.
*There are other codes, such as DOOR OPEN, DOOR CLOSE, and LOGON, that are less frequent and used for maintenance.
*Only the most frequent seven are listed here.


gen byte trans_srt =	cond(transaction == "REGULAR", 		1,			///		92.2% of transactions that occur on exact hours		
						cond(transaction == "RECOVR AUD", 	2,			///		2.6%		
						cond(transaction == "RECOVR", 		3,			///		2.1%		
						cond(transaction == "AUD", 			4, 			///		1.9%		
						cond(transaction == "OPEN",			5,			///		0.6%		
						cond(transaction == "DOOR", 		6,			///		0.4%		
						cond(transaction == "OPN", 			7, .)))))))	//		0.1%		
*Note: After eliminating duplicates using the steps below, the percentages are 96.3, 0.3, and 0.3 for the first three and the same for the others.
*This suggests that most of the RECOVR AUD and RECOVR transactions occur in tandem with REGULAR transactions, while the other transactions typically do not.

sort identifier statadate statatime trans_srt
drop trans_srt

*Delete duplicate times, keeping the observation with the highest transaction hierarchy
by identifier statadate: drop if statatime[_n] == statatime[_n-1]



**THIS SECTION IDENTIFIES FOUR-HOUR INTERVALS BETWEEN OBSERVATIONS, TAKING INTO ACCOUNT DAYLIGHT SAVINGS TIME, AND DIFFERENCES ENTRIES AND EXITS



*Indicate dates when DST status changes
gen byte dst_switch = 0
replace dst_switch = 1 if (																						///
	(statadate == 18335 | statadate == 18699 | statadate == 19063 | statadate == 19427 | statadate == 19791)	///
	| (statadate == 18573 | statadate == 18937 | statadate == 19301 | statadate == 19665 | statadate == 20029)	///
)

*Indicate when both observations of an interval are on or after 2:00 AM on DST Switch Days
gen byte after_switch = 0
replace after_switch = 1 if statadate[_n] == statadate[_n-1] & statatime[_n-1] >= 7200000 & dst_switch == 1		///
	& identifier[_n] == identifier[_n-1]

*Indicate when the interval is across the date threshold and the latter observation is before 2:00 AM on a DST Switch Day
gen byte before_switch = 0
replace before_switch = 1 if statadate[_n] - statadate[_n-1] == 1 & statatime[_n] < 7200000 & dst_switch == 1	///
	& identifier[_n] == identifier[_n-1]
*Some 1:00 AM observations on "Fall Back" days all are, in fact, after the switch (2:00 AM goes back to 1:00 AM), 
*but this will allow the ones that are before the switch (normal) to be counted as normal.

*Identify four-hour intervals that are not affected by DST switches
gen byte four_hr_int = 0
replace four_hr_int = 1 if (																									///
	(dst_switch == 0 | after_switch == 1 | before_switch == 1)																	///
	/*The next two lines are the core of the four-hour differencing*/															///
	& 	(	(statadate[_n] == statadate[_n-1] & statatime[_n] - statatime[_n-1] == 14400000) 									///		 4 hours difference: same day
			| (statadate[_n] - statadate[_n-1] == 1 & statatime[_n] - statatime[_n-1] == -72000000) 							///		-8 hours difference: next day
		)																														///
	&	identifier[_n] == identifier[_n-1]																						///
)

*Identify four-hour intervals that are affected by "Spring Forward"
replace four_hr_int = 1 if (																									///
	(statadate == 18335 | statadate == 18699 | statadate == 19063 | statadate == 19427 | statadate == 19791) 					///
	&	(	(statadate[_n] == statadate[_n-1] & statatime[_n-1] < 7200000 & statatime[_n] - statatime[_n-1] == 18000000) 		///	 5 hours difference: same day
			| (statadate[_n] - statadate[_n-1] == 1 & statatime[_n] >= 7200000 & statatime[_n] - statatime[_n-1] == -68400000)	///	-7 hours difference: next day
		) 																														///
	&	identifier[_n] == identifier[_n-1]																						///
)

*Identify four-hour intervals that are affected by "Fall Back"
replace four_hr_int = 1 if (																									///
	(statadate == 18573 | statadate == 18937 | statadate == 19301 | statadate == 19665 | statadate == 20029) 					///
	&	(	(statadate[_n] == statadate[_n-1] & statatime[_n-1] < 7200000 & statatime[_n] - statatime[_n-1] == 10800000) 		///	 3 hours difference: same day
			| (statadate[_n] - statadate[_n-1] == 1 & statatime[_n] >= 3600000 & statatime[_n] - statatime[_n-1] == -75600000)	///	-9 hours difference: next day
		) 																														///
	&	identifier[_n] == identifier[_n-1]																						///
)


*Repeat to search for four-hour intervals two records apart in case there's an oddball hourly reading in between
*Repeating for [_n-3] just seems to bring up a small number of fluke readings
*Repeating for [_n-4] only captures Wall St-45 due to its hourly readings. The station is being processed differently in a different data file.

gen four_hr_int_gap = 0
replace four_hr_int_gap = 1 if (																								///
	(	(statatime[_n] - statatime[_n-2] == 14400000 & statadate[_n] == statadate[_n-2])										///
	|	(statatime[_n] - statatime[_n-2] == -72000000 & statadate[_n] - statadate[_n-2] == 1) 									///
	) 																															///
	& identifier[_n] == identifier[_n-2]																						///
	& dst_switch[_n] == 0 & dst_switch[_n-2] == 0		/// excludes DST switch days to avoid false readings					///
)	


*Difference the entries and exits. These will become the key variables in the dataset.
gen diff_entries = entries_master[_n] - entries_master[_n-1] if four_hr_int == 1
gen diff_exits = exits_master[_n] - exits_master[_n-1] if four_hr_int == 1

replace diff_entries = entries_master[_n] - entries_master[_n-2] if four_hr_int_gap == 1
replace diff_exits = exits_master[_n] - exits_master[_n-2] if four_hr_int_gap == 1

label variable diff_entries "Entries"
label variable diff_exits "Exits"

*Remove those records without a first-differenced value, for example, the first observation for each turnstile
drop if diff_entries == .

*Drop variables that are no longer needed
drop dst_switch after_switch before_switch four_hr_int four_hr_int_gap

*Drop observations with negative first-difference values:
drop if diff_entries < 0
drop if diff_exits < 0

*Check for outliers / false readings that haven't been deleted
*After spot-checking a few stations, including Times Square, 6000 seems to be a good number.
*6000 per four hours = 25 / min. (at one SCP, which may be more than one turnstile)
*Alternatively, multiples of Interquartile Ranges or Median Absolute Deviation for each station (and perhaps weekday / weekend) could be used,
*but this data has a lot of variation and spikes, for example due to holidays, so cutting too agressively across the board is risky.
*It may be better to leave in all observations that aren't clearly false and then use medians in the analysis. That's what this method does.

	
*Another possible approach is to find the false readings by the activity around them. There are sometimes instances of the entries and/or exits count jumping 
*around, with large, obviously false, movements in both directions of the entries_master and exits_master counts. It seems that this might be primarily when
*maintenance is performed on a turnstile. It might be possible before any observations are dropped (including the observations between hours) to identify the
*pairs or small groups of the entries_master and exits_master movements. The movements are often equivalent in size but opposite in sign, or may be close in size
*but not exact. Such a cleaning method would have to create differences early solely for this purpose, then evaluate the fluctuations, for example, by looking for 
*a negative difference and a partnering positive difference within about 10% of the value of the negative difference.
	
drop if diff_entries > 6000
drop if diff_exits > 6000

*Save the cleaned and prepared dataset and erase the intermediary file DST_turnstile
save "$subway_raw/data_prepared.dta", replace

erase "$subway_raw/DST_turnstile.dta"


***WALL ST-45 CLEANING AND PREPARATION
*Almost all turnstiles report at four-hour cycles throughout the dataset.
*At Wall St-45, all of the turnstiles report hourly, and they are the only turnstiles to do so regularly, so they are treated differently in the code.
*There are two other turnstiles that had small stretches of reporting hourly, but they didn’t seem to be reporting anything useful.
*They are: Hunts Point Ave, R146 R412 00-02-00 and Smith-9 St, R270 N536 00-02-00 (same turnstile no. -- not a mistake)


use "$subway_raw/Wall_St_45.dta", clear



**THIS SECTION IDENTIFIES THE BEGINNING AND END OF DAYLIGHT SAVINGS TIME



*Indicate dates when DST begins ("Spring Forward")
gen byte dst_begin = 0
replace dst_begin = 1 if (statadate == 18335 | statadate == 18699 | statadate == 19063 | statadate == 19427 | statadate == 19791)

*Indicate dates when DST ends ("Fall Back")
gen byte dst_end = 0
replace dst_end = 1 if (statadate == 18573 | statadate == 18937 | statadate == 19301 | statadate == 19665 | statadate == 20029)



**THIS SECTION CLEANS AND DIFFERENCES THE DATA



*Keep only observations whose time is on an exact hour
keep if mod(statatime, 3600000) == 0


*Keep only the places on 4 hour intervals 0,4,8,12,16,20
keep if statatime==tc(01jan1960 0:00:00) | statatime==tc(01jan1960 4:00:00) | statatime==tc(01jan1960 8:00:00) | statatime==tc(01jan1960 12:00:00) ///
		| statatime==tc(01jan1960 16:00:00) | statatime==tc(01jan1960 20:00:00)



*Create and sort by a heirarchy of transaction codes (for time duplicates)
*This is based on the frequency with which these codes appear in the data as well as our limited knowledge of the meaning of the codes.
*There are other codes, such as DOOR OPEN, DOOR CLOSE, and LOGON, that are less frequent and used for maintenance.
*Only the most frequent seven are listed here.

gen byte trans_srt =	cond(transaction == "REGULAR", 		1,			///		97.3% of transactions that occur on exact hours		
						cond(transaction == "RECOVR AUD", 	2,			///		0.9%		
						cond(transaction == "RECOVR", 		3,			///		0.8%		
						cond(transaction == "AUD", 			4, 			///		0.7%		
						cond(transaction == "OPEN",			5,			///		0.2%		
						cond(transaction == "DOOR", 		6,			///		0.1%		
						cond(transaction == "OPN", 			7, .)))))))	//		0.1%		
*Note: After eliminating duplicates using the steps below, the percentages are 98.5, 0.2, 0.3, and 0.6 for the first four and the same for the others.
*This suggests that many of the RECOVR AUD, RECOVR, and AUD transactions occur in tandem with REGULAR transactions, while the other transactions typically do not.


*Prioritize observations by transaction code.
*When DST ends, there are usually two 1:00 AM records. (1:00 AM occurs naturally, then 2:00 AM becomes 1:00 AM again.)
*This code assumes the higher reading is the later one, and the one to use for differencing 1:00 to 2:00 AM.
sort identifier statadate statatime trans_srt entries_master exits_master
drop trans_srt

*Delete duplicate times, keeping the observation with the highest transaction hierarchy
by identifier statadate: drop if statatime[_n] == statatime[_n-1] & (dst_end == 0 | (dst_end == 1 & statatime != 3600000))

**THIS SECTION IDENTIFIES ONE-HOUR INTERVALS BETWEEN OBSERVATIONS, TAKING INTO ACCOUNT DAYLIGHT SAVINGS TIME, AND DIFFERENCES ENTRIES AND EXITS
	
*To compare this station with others, the user may want to create four-hour blocks out of this data.
*To create four-hour blocks, two options are to 1) difference the one-hour blocks and aggregate 
*2) difference four-hour blocks, based on decisions about how to define those blocks (see annotations in the "ratios" DO file)
*Option 1) is used below. If aggregating from one-hour blocks, the user should be careful only to include those blocks
*where all four one-hour blocks are present, that is, not to aggregate three one-hour blocks together and call it a four-hour block.

*Indicate dates when DST status changes
gen byte dst_switch = 0
replace dst_switch = 1 if (																										///
	(statadate == 18335 | statadate == 18699 | statadate == 19063 | statadate == 19427 | statadate == 19791)					///
	| (statadate == 18573 | statadate == 18937 | statadate == 19301 | statadate == 19665 | statadate == 20029)					///
)

*Indicate when both observations of an interval are on or after 2:00 AM on DST Switch Days
gen byte after_switch = 0
replace after_switch = 1 if statadate[_n] == statadate[_n-1] & statatime[_n-1] >= 7200000 & dst_switch[_n] == 1					///
	& identifier[_n] == identifier[_n-1]

*Indicate when the interval occurs before 2:00 AM on a "Spring Forward" Day
gen byte before_switch = 0
replace before_switch = 1 if statatime[_n] < 7200000 & dst_begin[_n] == 1 & identifier[_n] == identifier[_n-1]

*Indicate when the interval occurs before 1:00 AM on a "Fall Back" Day
replace before_switch = 1 if statatime[_n] < 3600000 & dst_end[_n] == 1	& identifier[_n] == identifier[_n-1]	
*Since the Wall St-45 is an hourly dataset, there are two instances of 1:00 AM observations on "Fall Back" days.
*Those observations are treated separately.

		
*Identify one-hour intervals that are not affected by DST switches
gen byte one_hr_int = 0
replace one_hr_int = 1 if (																										///
	(dst_switch == 0 | after_switch == 1 | before_switch == 1)																	///
	/*The next two lines are the core of the one-hour differencing*/															///
	& 	(	(statadate[_n] == statadate[_n-1] & statatime[_n] - statatime[_n-1] == 3600000) 									///		 1 hours differece: same day
			| (statadate[_n] - statadate[_n-1] == 1 & statatime[_n] - statatime[_n-1] == -82800000) 							///		-23 hours difference: next day
		)																														///
	&	identifier[_n] == identifier[_n-1]																						///
)


*Identify one-hour intervals that are affected by "Spring Forward"
replace one_hr_int = 1 if (																										///
	(statadate == 18335 | statadate == 18699 | statadate == 19063 | statadate == 19427 | statadate == 19791) 					///
	&	(statadate[_n] == statadate[_n-1] & statatime[_n-1] < 7200000 & statatime[_n] > 7200000									///		Only applies to 1:00 to 2:00 (becomes 3:00AM)
				& statatime[_n] - statatime[_n-1] == 7200000) 																	///		2 hours difference 
	&	identifier[_n] == identifier[_n-1]																						///
)

*Identify one-hour intervals that are affected by "Fall Back"
replace one_hr_int = 1 if (																										///
	(statadate == 18573 | statadate == 18937 | statadate == 19301 | statadate == 19665 | statadate == 20029) 					///
	&	statadate[_n] == statadate[_n-1]																						///
	&	(	(statatime[_n-1] == 0 & statatime[_n] == 3600000)																	///		12:00 AM to 1:00 AM (first one)
		|	(statatime[_n-1] == 3600000 & statatime[_n] == 3600000)																///		1:00 AM (first) to 1:00 AM (second)
		|	(statatime[_n-1] == 3600000 & statatime[_n] == 7200000)																///		1:00 AM (second) to 2:00 AM
		) 																														///
	&	identifier[_n] == identifier[_n-1]																						///
)

*Both instances of 1:00 AM are captured by this method. 
*Note that this method assumes that the higher of the readings (by entries_master first, then exits_master) is the later one.
*It may be possible to avoid this assumption by flagging the order of the 1:00 instances as they exist in the raw data files, 
*before any re-sorting or stacking of the data is done.
*If analysis is performed using early morning times, the user should be careful about the extra instances of 1:00 AM.
*If needed, a standardized time variable, such as GMT, could be created based on the given times, 
*DST status (being careful of early morning switches), and the assumption about the 1:00 AM observations mentioned above.


*Difference the entries and exits. These will become the key variables in the dataset.
gen diff_entries = entries[_n] - entries[_n-1] if identifier[_n] == identifier[_n-1] //& one_hr_int == 1
gen diff_exits = exits[_n] - exits[_n-1] if identifier[_n] == identifier[_n-1] //& one_hr_int == 1

label variable diff_entries "Entries"
label variable diff_exits "Exits"

*Drop variables that are no longer needed
drop dst_begin dst_end dst_switch after_switch before_switch one_hr_int

*Remove those records without a first-differenced value, for example, the first observation for each turnstile
drop if diff_entries == .

*Drop observations with negative first-difference values:
drop if diff_entries < 0 
drop if diff_exits < 0

*Check for outliers / false readings that haven't been deleted
*The cut-off value is based on looking at the dataset (see the notes below) and the cut-off value for the four-hour blocks, 6000.
*(6000 / 4 = 1500)
drop if diff_entries > 1500		//	Readings go up to 786, then jump up to one clearly false reading of 1.8 million
drop if diff_exits > 1500		//	Readings go up to 1195, then jump up to 3364 in the same record as the diff_entries of 1.8 million


*Save the cleaned and prepared dataset and erase the intermediary file Wall_St-45
save "$subway_raw/Wall_St_45_prepared.dta", replace

erase "$subway_raw/Wall_St_45.dta"
