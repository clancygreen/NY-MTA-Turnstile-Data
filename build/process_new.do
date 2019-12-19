version 16.0

do header.do

//==============================================================================
// Build New Station From 
//==============================================================================

**THIS SECTION CREATES THE MASTER DATASET FROM THE TEXT FILES FOR NEW FILE STRUCTURE

*cd "/Users/`dir'/Dropbox/Uber/Data/RawSubwayData/IndividualWeekFiles/TurnstileTextFiles_newtype"

clear

local datafiles : dir "$subway_newtext_dir" files  "*.txt"
assert strlen(`" `datafiles' "') != 0

*Loop through the raw data files
foreach file in `datafiles' {

	*Import the next file
	display "Importing `file'"
	import delimited using $subway_newtext_dir/`file', delimiter(comma) clear

	compress
	
	save "$subway_newstata_dir/`file'.dta", replace
}

*Append all the weekly datasets together.  
clear

*cd "/Users/`dir'/Dropbox/Uber/Data/RawSubwayData/IndividualWeekFiles/Turnstile_Stata_NewType"

local datafiles : dir "$subway_newstata_dir" files  "*.txt.dta"

foreach file in `datafiles' {
    local datafiles_fullpath $subway_newstata_dir/`file' `datafiles_fullpath'
}

append using `datafiles_fullpath'

*Rename the variables to conform with old data
rename ca booth
rename unit remote
rename scp turnstile
rename date date_master
rename time time_master
rename desc transaction
rename entries entries_master
rename exits exits_master

*Set the way the entries and exits are displayed (instead of scientific notation)
format entries_master %15.0g
format exits_master %15.0g	

*DATE AND TIME

*Set the date format and identify days of the week
gen int statadate = date(date_master, "MD20Y")
format statadate %td
drop date

gen int dayofweek = statadate
format dayofweek %tdDay

*Create dummy variable for weekday
gen byte day = dow(statadate)
gen byte weekday = 1 if day > 0 & day < 6
replace weekday = 0 if weekday != 1
drop day

*Convert time from string to numeric
gen statatime = clock(time_master, "hms")
format statatime %tc_HH:MM:SS
drop time

*STATION LAT/LONG

*Merge in station names, and lat/long

mmerge remote using "$subway_raw/station_latlong.dta"

replace lat_deg=40.755839 if _merge==1 & remote=="R072"
replace long_deg=-74.001961 if _merge==1 & remote=="R072"

replace lat_deg=40.768889 if _merge==1 & remote=="R570"
replace long_deg=-73.958333 if _merge==1 & remote=="R570"

replace lat_deg=40.777861 if _merge==1 & remote=="R571"
replace long_deg=-73.95175 if _merge==1 & remote=="R571"

replace lat_deg=40.7841 if _merge==1 & remote=="R572"
replace long_deg=-73.9472 if _merge==1 & remote=="R572"

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

save "$subway_raw/newyears_data_master.dta", replace	


use "$subway_raw/newyears_data_master.dta", clear

***Adjust New Data for DST
	
*Here are the dates when DST changes, with the Stata ('statadate' variable) equivalents

		*To DST		statadate				From DST		statadate
		*3/9/2014	19791					11/2/2014		20029
		*3/8/2015	20155					11/1/2015		20393
		*3/13/2016	20526					11/6/2016		20764
		*3/12/2017	20890					11/5/2017		21128
		*3/11/2018	21254
		
gen byte DST =	cond(statadate	>=	19791 & statadate <	20029, 1, 			///		DST
				cond(statadate	>=	20029 & statadate <	20155, 1, 			///		REG
				cond(statadate	>=	20155 & statadate <	20393, 1, 			///		DST
				cond(statadate	>=	20393 & statadate <	20526, 1, 			///		REG
				cond(statadate	>=	20526 & statadate <	20764, 1, 			///		DST
				cond(statadate	>=	20764 & statadate <	20890, 1, 			///		REG
				cond(statadate	>=	20890 & statadate <	21128, 1, 			///		DST
				cond(statadate	>=	21128 & statadate <	21254, 1,.)))))))) 	///		REG

label variable DST "Daylight Savings Time"
label define DST 0 "Standard Time" 1 "Daylight Savings Time" 
label values DST DST

				
*Create a unique identifier for each turnstile
gen identifier = remote + " " + booth + " " + turnstile 
label variable identifier "Turnstile Identifier"
//drop booth turnstile
order identifier, after(remote)


save "$subway_raw/DST_turnstile_newyears.dta", replace

erase "$subway_raw/newyears_data_master.dta"

*****DF DOESN'T THINK THIS IS NECESSARY IN THE NEW YEARS

** THIS SECTION SPLITS OUT WALL ST STATION ON THE 4/5 TRAINS INTO A SEPARATE DATASET
*Almost all turnstiles report at four-hour cycles throughout the dataset.
*At Wall St-45, all of the turnstiles report hourly, and they are the only turnstiles to do so regularly, so they are treated differently in the code.
*There are two other turnstiles that had small stretches of reporting hourly, but they didn’t seem to be reporting anything useful.
*They are: Hunts Point Ave, R146 R412 00-02-00 and Smith-9 St, R270 N536 00-02-00 (same turnstile no. -- not a mistake)

		
//keep if station == "WALL ST-45"
//save "$subway_raw/Wall_St_45_newyears.dta", replace

use "$subway_raw/DST_turnstile_newyears.dta", clear

//drop if station == "WALL ST-45"

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
	(statadate == 19791 | statadate == 20155 | statadate == 20526 | statadate == 20890)	///
	| (statadate == 20029 | statadate == 20393 | statadate == 20764 | statadate == 21128)	///
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
	(statadate == 19791 | statadate == 20155 | statadate == 20526 | statadate == 20890) 					///
	&	(	(statadate[_n] == statadate[_n-1] & statatime[_n-1] < 7200000 & statatime[_n] - statatime[_n-1] == 18000000) 		///	 5 hours difference: same day
			| (statadate[_n] - statadate[_n-1] == 1 & statatime[_n] >= 7200000 & statatime[_n] - statatime[_n-1] == -68400000)	///	-7 hours difference: next day
		) 																														///
	&	identifier[_n] == identifier[_n-1]																						///
)

*Identify four-hour intervals that are affected by "Fall Back"
replace four_hr_int = 1 if (																									///
	(statadate == 20029 | statadate == 20393 | statadate == 20764 | statadate == 21128) 					///
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
save "$subway_raw/data_prepared_newyears.dta", replace

erase "$subway_raw/DST_turnstile_newyears.dta"				

