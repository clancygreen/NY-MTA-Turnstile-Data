****MTA TURNSTILE DATA: TURNSTILE CYCLE EXPLORATION****

/*
By Kevin McCaffrey, August 2014

This Stata DO file examines the cycles that the turnstiles report on.
Wall St-45 reports hourly and all other subway stations report four-hourly.
Some non-MTA subway stations such as PATH seem to have different cycles and are not analyzed here.

This analysis only examines turnstiles that report on even hours, and so excludes
the three stations that regularly report on off-hours: 161 ST-YANKEE-BD4, UNION TPK-KEW G-EF, and 15 ST-PROSPECT-FG.

161 ST-YANKEE-BD4 is 22 minutes after Cycle 1, beginning at 3:22 AM in non-DST and 12:22 AM in DST.
UNION TPK-KEW G-EF is 30 minutes after Cycle 3, beginning at 1:30 AM in non-DST and 2:30 AM in DST.
15 ST-PROSPECT-FG is 30 minutes after Cycle 1, beginning at 3:30 AM in non-DST and 12:30 AM in DST.

The DO file that finds and examines these three stations is "Off-hour Cycles".

*/

*Stata Version 11.2
version 11.2


***OVERALL INSTRUCTIONS***

*Run the Data_Prep_and_Cleaning DO file to obtain data_master and data_prepared.dta

*Put the working directory here after the "cd". Use quotes if there are spaces in the path.
*data_mater should be in this directory.
cd 



***HOURLY TURNSTILES***



use data_master	


**THIS SECTION CREATES A DAYLIGHT SAVINGS TIME DUMMY VARIABLE
	*A knowledge of the Daylight Savings Time dates is crucial to working with this dataset

*Here are the dates when DST changes, with the Stata ('statadate' variable) equivalents

	*To DST		statadate		From DST	statadate
	*3/14/2010	18335			11/7/2010	18573
	*3/13/2011	18699			11/6/2010	18937
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
label define DST 1 "Daylight Savings Time" 0 "Non-Daylight Savings Time"


**THIS SECTION CREATES A UNIQUE TURNSTILE IDENTIFIER


*Create a unique identifier for each turnstile
gen identifier = remote + " " + booth + " " + turnstile 
label variable identifier "Turnstile Identifier"
drop booth turnstile
order identifier, after(remote)

*Keep only those observations that occur on the hour
keep if mod(statatime, 3600000) == 0

*Create and sort by a hierarchy of transaction codes (for time duplicates)

gen byte trans_srt =	cond(transaction == "REGULAR", 		1,			///				
						cond(transaction == "RECOVR AUD", 	2,			///				
						cond(transaction == "RECOVR", 		3,			///				
						cond(transaction == "AUD", 			4, 			///				
						cond(transaction == "OPEN",			5,			///				
						cond(transaction == "DOOR", 		6,			///				
						cond(transaction == "OPN", 			7, .)))))))	//		

sort identifier statadate statatime trans_srt
drop trans_srt

*Delete duplicate times, keeping the observation with the highest transaction hierarchy
by identifier statadate: drop if statatime[_n] == statatime[_n-1]



**THIS SECTION FINDS HOURLY TURNSTILES 

*Calculate the average time in hours between observations, and the average number of observations
gen time_diff_hr = (statatime[_n] - statatime[_n-1]) / 3600000 if statadate[_n] == statadate[_n-1]
gen record = 1
egen daily_records = total(record), by(identifier statadate)
collapse time_diff_hr daily_records, by(identifier station)

*View the values
sort time_diff_hr
set more off
list station identifier time_diff_hr daily_records	//	Alternatively, just use the data viewer to explore the results.

*Save the results
save hourly_turnstile_search



***FOUR-HOUR TURNSTILES***



use data_prepared, clear

*Drop 1:00 AM readings on "Fall Back" days since they could represent two different cycles
drop if (statadate == 18573 | statadate == 18937 | statadate == 19301 | statadate == 19665 | statadate == 20029)	///
	&	statatime == 3600000


	
**THIS SECTION LABELS THE FOUR POSSIBLE FOUR-HOUR CYCLES



*Label observations reported on Cycle 1 ("Cycle 1" because it's the most common cycle)
	*(4 hour intervals starting from 11:00 PM (3:00 AM) in non-DST and 12:00 AM in DST)
	*(These turnstiles account for 55% of the total.)

gen byte cycle_one_obs = 0
replace cycle_one_obs = 1 if ((DST == 0 & mod(statatime + 3600000, 14400000) == 0) ///
	| (DST == 1 & mod(statatime, 14400000) == 0))
*Adjust for early morning readings (12:00 AM or 1:00 AM) on days where DST begins or ends. (The change happens at 2:00 AM.)
replace cycle_one_obs = 0 if (statadate == 18335 | statadate == 18699 | statadate == 19063 | statadate == 19427 | statadate == 19791) ///
	& statatime == 0 
replace cycle_one_obs = 1 if (statadate == 18573 | statadate == 18937 | statadate == 19301 | statadate == 19665 | statadate == 20029) ///
	& statatime == 0

	
*Label observations reported on Cycle 2 (one hour later than Cycle 1)
	*(4 hours intervals starting from midnight in non-DST and 1:00 AM in DST)
	*(These turnstiles account for 41% of the total.)
gen byte cycle_two_obs = 0
replace cycle_two_obs = 1 if ((DST == 0 & mod(statatime, 14400000) == 0) ///
	| (DST == 1 & mod(statatime - 3600000, 14400000) == 0))
*Adjust for early morning readings (12:00 AM or 1:00 AM) on days where DST begins or ends. (The change happens at 2:00 AM.)
replace cycle_two_obs = 1 if (statadate == 18335 | statadate == 18699 | statadate == 19063 | statadate == 19427 | statadate == 19791) ///
	& statatime == 0 
replace cycle_two_obs = 0 if (statadate == 18573 | statadate == 18937 | statadate == 19301 | statadate == 19665 | statadate == 20029) ///
	& statatime == 0
*1:00 AM on "Fall Back" days could be either Cycle 2 or Cycle 3, so they are excluded.
	

*Label observations reported on Cycle 3 (two hours than Cycle 1)
	*(4 hour intervals starting from 1:00 AM in non-DST and 2:00 AM in DST)
	*(These turnstiles account for 2% of the total.)
gen byte cycle_three_obs = 0
replace cycle_three_obs = 1 if ((DST == 0 & mod(statatime - 3600000, 14400000) == 0) ///
	| (DST == 1 & mod(statatime - 7200000, 14400000) == 0))
*Adjust for early morning readings (12:00 AM or 1:00 AM) on days where DST begins or ends. (The change happens at 2:00 AM.)
replace cycle_three_obs = 1 if (statadate == 18335 | statadate == 18699 | statadate == 19063 | statadate == 19427 | statadate == 19791) ///
	& statatime == 3600000 
*1:00 AM on "Fall Back" days could be either Cycle 2 or Cycle 3, so they are excluded.


*Label observations reported on Cycle 4 (one hour earlier than Cycle 1)
	*(4 hour intervals starting from 10:00 PM in non-DST and 11:00 PM in DST)
	*(These turnstiles account for 1% of the total.)
gen byte cycle_four_obs = 0
replace cycle_four_obs = 1 if ((DST == 0 & mod(statatime + 7200000, 14400000) == 0) ///
	| (DST == 1 & mod(statatime + 3600000, 14400000) == 0))
*Adjust for early morning readings (12:00 AM or 1:00 AM) on days where DST begins or ends. (The change happens at 2:00 AM.)
*N/A for this group



**THIS SECTION SUMS THE CYCLE-IDENTIFIED OBSERVATIONS AND ASSIGNS EACH TURNSTILE TO A CYCLE



*Collapse down to the turnstile level, capturing the median entries and exits and the total observations for each turnstile cycle	
sort identifier
collapse (median) diff_entries diff_exits (sum) cycle_one_obs cycle_two_obs cycle_three_obs cycle_four_obs, by(identifier station)


*Create identifiers for the different turnstile cycles. Setting the threshold at 5 seems to eliminate most flukes.
gen byte cycle_one_turnstile = 0
replace cycle_one_turnstile = 1 if cycle_one_obs > 5

gen byte cycle_two_turnstile = 0
replace cycle_two_turnstile = 1 if cycle_two_obs > 5

gen byte cycle_three_turnstile = 0
replace cycle_three_turnstile = 1 if cycle_three_obs > 5

gen byte cycle_four_turnstile = 0
replace cycle_four_turnstile = 1 if cycle_four_obs > 5

*Combine into one identifier
gen turnstile_cycle = 	cond(cycle_one_turnstile 	== 1,	1,				///
						cond(cycle_two_turnstile 	== 1,	2,				///
						cond(cycle_three_turnstile	== 1,	3,				///
						cond(cycle_four_turnstile	== 1, 	4, .))))

*Find those few observations that have a missing value
replace turnstile_cycle = 1 if missing(turnstile_cycle) & cycle_one_obs 	> 0 	& cycle_one_obs 	< .
replace turnstile_cycle = 2 if missing(turnstile_cycle) & cycle_two_obs 	> 0 	& cycle_two_obs 	< .
replace turnstile_cycle = 3 if missing(turnstile_cycle) & cycle_three_obs 	> 0		& cycle_three_obs 	< .
replace turnstile_cycle = 4 if missing(turnstile_cycle) & cycle_four_obs	> 0		& cycle_four_obs	< .

*Create a special 'mixed' category for the turnstiles in Remote R359, one of the Court Sq remotes
	*They switched from Cycle 2 to Cycle 1 on 03aug2011.
*These are the only turnstiles to have records worth accounting for in two different turnstile cycles.
replace turnstile_cycle = 5 if strmatch(identifier, "R359*")

label variable turnstile_cycle "Turnstile Cycle"
label define turnstile_cycle 1 "3am-12am" 2 "12am-1am" 3 "1am-2am" 4 "2am-3am" 5 "mixed" //6 "hourly" This is an extra code that could be used for Wall St-45

save turnstile_cycles



**THIS SECTION SIMPLIFIES THE TURNSTILE CYCLES FILE FOR USE AS A TURNSTILE CYCLE CROSSWALK



*use turnstile_cycles, clear

drop diff_entries diff_exits cycle_one_obs cycle_two_obs cycle_three_obs cycle_four_obs ///
	cycle_one_turnstile cycle_two_turnstile cycle_three_turnstile cycle_four_turnstile

save turnstile_cycle_crosswalk



**THIS SECTION COUNTS THE NUMBER OF TURNSTILES ON EACH CYCLE, THEN CALCULATES SHARE



*use turnstile_cycle_crosswalk, clear

gen byte turn_count = 1
egen station_turns 		= total(turn_count), by(station)
egen cycle_one_count 	= total(turn_count) if turnstile_cycle == 1, by(station)
egen cycle_two_count 	= total(turn_count) if turnstile_cycle == 2, by(station)
egen cycle_three_count 	= total(turn_count) if turnstile_cycle == 3, by(station)
egen cycle_four_count 	= total(turn_count) if turnstile_cycle == 4, by(station)
egen cycle_five_count 	= total(turn_count) if turnstile_cycle == 5, by(station)
*This is currently not in use, but could be used for hourly turnstiles at Wall St-45
*egen cycle_six_count 	= total(turn_count) if turnstile_cycle == 6, by(station)

gen float cycle_one_share 	= cycle_one_count 	/ station_turns * 100
gen float cycle_two_share 	= cycle_two_count 	/ station_turns * 100
gen float cycle_three_share	= cycle_three_count / station_turns * 100
gen float cycle_four_share	= cycle_four_count 	/ station_turns * 100
gen float cycle_five_share	= cycle_five_count 	/ station_turns * 100
*gen float cycle_six_share	= cycle_six_count 	/ station_turns * 100

label variable cycle_one_share 	"Share of turnstiles on 3am-12am cycle (%)"
label variable cycle_two_share 	"Share of turnstiles on 12am-1am cycle (%)"
label variable cycle_three_share "Share of turnstiles on 1am-2am cycle (%)"
label variable cycle_four_share "Share of turnstiles on 2am-3am cycle (%)"
label variable cycle_five_share "Share of turnstiles on mixed cycle (%)"
*label variable cycle_six_share 	"Share of turnstiles on hourly cycle (%)"

collapse cycle_one_count cycle_two_count cycle_three_count cycle_four_count cycle_five_count 		///
/*cycle_six_count*/ cycle_one_share cycle_two_share cycle_three_share cycle_four_share 				///
cycle_five_share /*cycle_six_share*/, by(station)

save turnstile_cycles_per_station
