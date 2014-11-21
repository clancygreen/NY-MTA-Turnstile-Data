****MTA TURNSTILE DATA RATIO ANALYSIS****

****FALL/WINTER 2013-2014 SNAPSHOT BASED ON 4-HOUR BLOCKS****

*By Kevin McCaffrey and Ivan Khilko, August 2014

*Stata Version 11.2
version 11.2


***OVERALL INSTRUCTIONS***

*Follow the instructions from Data_Prep_and_Cleaning DO file and run the DO file.
*Run Turnstile_Cycles DO file.
*This DO file starts with the data_prepared data file and uses turnstile_cycle_crosswalk,
	*which are created by those DO files.

*You will need master_remote_crosswalk.dta, which is a list of remote numbers with a business district indicator for each.
*The .CSV is available in this GitHub folder. 
*(It can be converted to DTA format with Stata.)
	
*The size of the complete data file is around 3 gigabytes. It is recommended to have at least 8 gig of memory.

*Set your working directory here, after the cd
	*It is advisable for speed, given the size of the dataset to be built, that the working directory be on your local computer.
	*The data_prepared data file should be in this directory
cd 


**THIS SECTION PREPARES THE DATASET FOR RATIO ANALYSIS


use data_prepared, clear

*Merge in the turnstile cycle list. This might not be necessary but is convenient.
merge m:1 identifier using turnstile_cycle_crosswalk, keepusing(turnstile_cycle)
drop _merge
save data_prepared_cycles.dta, replace


*use data_prepared_cycles.dta, clear // Only necessary if starting from here

*Turnstiles on cycles 1 and 2 represent 97% of the turnstiles. 
	*There's a question as to whether the times on cycles 3 and 4 are accurate.
*Turnstile Cycle 5 is for turnstiles in remote R359 at Court Sq., which has turnstiles that have observations
	*on Cycle 1 and Cycle 2. They switched from Cycle 2 to Cycle 1 on 03aug2011.
keep if turnstile_cycle == 1 | turnstile_cycle == 2 | turnstile_cycle == 5

*The Non-Daylight Savings Time period provides the best time blocks for Turnstile Cycle 2 for capturing morning activity
	*(8-12am, compared to either 5-9am or 9am-1pm in DST)
keep if DST == 0

*Only keep most recent non-DST period (for a current snapshot)
keep if statadate >= 19665 & statadate < 19791 // November 3, 2013 to March 9, 2014

*Drop seasonal stations
drop if station == "ORCHARD BEACH-6" | station == "AQUEDUCT TRACK-A" 

*This station reports off-cycle, but there are some observations reported on Cycle 2. 
	*There are no changes in the entries and exits in those observations.
*This line seems to be no longer necessary after the most recent update of the turnstile cycle file
drop if station == "161 ST-YANKEE-BD4" 

*Merge in the business district list
merge m:1 remote using master_remote_crosswalk, keepusing(bizdist)

*Just a small number of remote numbers in the crosswalk don't match.
*All of the remote numbers in the data file match with the crosswalk.
keep if _merge == 3
drop _merge

label variable bizdist "Business District"
label define bizdist 1 "Business District" 0 "Not a Business District"


**THIS SECTION DEALS WITH TIME BLOCKS


/*
Note on time blocks used in the time series analysis:

This analysis uses 4-hour time blocks, the time block available in the MTA data.
Time blocks for morning and evening flagged as such.

If one of the 4-hour readings is missing from a turnstile,
it simply will not get added into the count for that station or neighborhood.
This introduces error, but this should not be a problem since:
		1. most time blocks are present, so the error is small to begin with
		2. the error is reduced when we aggregate to the station or neighborhood level
		3. moving averages are used to smooth the time series

Alternatively, code could be written to check for all 4-hour blocks for a given station or neighborhood and 
produce a missing value instead of an incomplete total for that day.
See: http://statlore.wordpress.com/2013/01/25/how-to-preserve-missing-values-with-statas-collapse-command/
*/

*Identify what observations happen during morning or evening commutes
gen byte morning = 0
gen byte evening = 0
label variable morning "Morning"
label variable evening "Evening"

*For turnstiles on Cycle 1, captures 11:00 AM for morning and 7:00 PM for evening (only in Non-DST)
*For turnstiles on Cycle 2, captures 12:00 PM for morning and 8:00 PM for evening (only in Non-DST)
replace morning = 1 if (statatime == 39600000 & turnstile_cycle == 1) ///
	| (statatime == 43200000 & turnstile_cycle == 2)
replace evening = 1 if (statatime == 68400000 & turnstile_cycle == 1) 	 ///
	| (statatime == 72000000 & turnstile_cycle == 2)

*This part deals with Court Sq., which has turnstiles that have observations on Cycle 1 and Cycle 2
		*They switched from Cycle 2 to Cycle 1 on 03aug2011.
replace morning = 1 if (statatime == 39600000 | statatime == 43200000) & turnstile_cycle == 5
replace evening = 1 if (statatime == 68400000 | statatime == 72000000) & turnstile_cycle == 5
	

**THIS SECTION COLLAPSES DOWN TO STATION TOTALS


*Save the variable labels for restoration after the collapse
foreach v of var * {
	local l`v' : variable label `v'
    if `"`l`v''"' == "" {
		local l`v' "`v'"
	}
}

*Combine entries and exits by summing to one per station, date, and time grouping. 
*(Each date only has one dayofweek and weekday value; each station only has one bizdist value.)
sort station statadate morning evening
collapse (sum) diff_entries diff_exits, by(station statadate morning evening dayofweek weekday bizdist)

*Restore the variable labels
foreach v of var * {
	label var `v' "`l`v''"
}

save cycle_one_and_two_by_station_snapshot.dta, replace


**THIS SECTION CALCULATES RATIOS WITH THE COLLAPSED DATA AND FURTHER COLLAPSES


*use cycle_one_and_two_by_station_snapshot.dta, clear // only necessary if starting here


*Create a ratio of exits to entries for each station
*This ratio uses daily values. The idea is that over time (about a given day), entries and exits should be equal,
	*though a number of exits go uncounted--the loss factor.
	*This section actually adds the various four-hour time blocks. See discussion on error above.
	*Alternatively, for these daily totals, counts could be taken by differencing the last reading of each day 
		*from the last reading of the previous day of each turnstile.
egen daily_entries = total(diff_entries), by(station statadate)	
egen daily_exits = total(diff_exits), by(station statadate)
gen r_ex_en = daily_exits / daily_entries
label variable r_ex_en "Daily ratio of exits/entries"

*Calculate the median ratio
sort station weekday
egen med_r_ex_en = median(r_ex_en), by(station weekday)
label variable med_r_ex_en "Median ratio of exits/entries"

*Calculate the ratio of medians
egen d_en_med = median(daily_entries), by(station weekday)
egen d_ex_med = median(daily_exits), by(station weekday)
gen r_med_ex_en = d_ex_med / d_en_med
label variable r_med_ex_en "Ratio of median exits/entries"

*Calculate the median daily ratios for morning entries / evening entries and morning exits / evening exits
	*for each combination of station and weekday / weekend
sort station statadate morning evening
gen d_r_m_en_e_en = .
replace d_r_m_en_e_en = diff_entries[_n] / diff_entries[_n-1] if morning[_n] == 1 & evening[_n-1] == 1 & station[_n] == station[_n-1] ///
	& statadate[_n] == statadate[_n-1]
label variable d_r_m_en_e_en "Daily ratio of morning/evening entries"

gen d_r_m_ex_e_ex = .
replace d_r_m_ex_e_ex = diff_exits[_n] / diff_exits[_n-1] if morning[_n] == 1 & evening[_n-1] == 1 & station[_n] == station[_n-1] ///
	& statadate[_n] == statadate[_n-1]
label variable d_r_m_ex_e_ex "Daily ratio of morning/evening exits"

sort station weekday morning evening
egen med_r_m_en_e_en = median(d_r_m_en_e_en), by(station weekday)
label variable med_r_m_en_e_en "Median ratio of morning/evening entries"

egen med_r_m_ex_e_ex = median(d_r_m_ex_e_ex), by(station weekday)
label variable med_r_m_ex_e_ex "Median ratio of morning/evening exits"

*Calculate the median number of entries and exits for each combination of station, weekday / weekend, and time grouping
egen entries_med = median(diff_entries), by(station weekday morning evening)
egen exits_med = median(diff_exits), by(station weekday morning evening)
label variable entries_med "Median entries"
label variable exits_med "Median exits"


*Save the variable labels for restoration after the collapse
foreach v of var * {
	local l`v' : variable label `v'
		if `"`l`v''"' == "" {
			local l`v' "`v'"
		}
}

*Combine entries and exits to one per station, morning/evening, and weekday/weekend
*(Each station only has one bizdist value.)
collapse entries_med exits_med med_r_ex_en r_med_ex_en med_r_m_en_e_en med_r_m_ex_e_ex, by(station weekday morning evening bizdist)

*Restore the variable labels
foreach v of var * {
	label var `v' "`l`v''"
}

*Create a ratio of morning entries to evening entries for each combination of station and weekday / weekend 
*This ratio (and exits below) uses median values.
gen r_med_m_en_e_en = .
label variable r_med_m_en_e_en "Ratio of medians: morning entries / evening entries"
replace r_med_m_en_e_en = entries_med[_n] / entries_med[_n-1] if morning[_n] == 1 & evening[_n-1] == 1 & station[_n] == station[_n-1] & weekday[_n] == weekday[_n-1]

*Repeat with exits
gen r_med_m_ex_e_ex = .
label variable r_med_m_ex_e_ex "Ratio of medians: morning exits / evening exits"
replace r_med_m_ex_e_ex = exits_med[_n] / exits_med[_n-1] if morning[_n] == 1 & evening[_n-1] == 1 & station[_n] == station[_n-1] & weekday[_n] == weekday[_n-1]

*Separate the morning and evening medians into separate columns to keep them after the next collapse
gen m_en_med = entries_med if morning == 1
gen e_en_med = entries_med if evening == 1
gen m_ex_med = exits_med if morning == 1
gen e_ex_med = exits_med if evening == 1
label variable m_en_med "Median morning entries"
label variable e_en_med "Median evening entries"
label variable m_ex_med "Median morning exits"
label variable e_ex_med "Median evening exits"

*Reorder the new variables
order r_med_m_en_e_en med_r_m_en_e_en r_med_m_ex_e_ex med_r_m_ex_e_ex r_med_ex_en med_r_ex_en m_en_med e_en_med m_ex_med e_ex_med


*Save the variable labels for restoration after the collapse
foreach v of var * {
	local l`v' : variable label `v'
		if `"`l`v''"' == "" {
			local l`v' "`v'"
		}
}

*Combine entries to one per station and weekday / weekend
collapse r_med_m_en_e_en med_r_m_en_e_en r_med_m_ex_e_ex med_r_m_ex_e_ex r_med_ex_en med_r_ex_en m_en_med e_en_med m_ex_med e_ex_med, ///
	by(station weekday bizdist)

*Restore the variable labels
foreach v of var * {
        label var `v' "`l`v''"
}

*Create rank variables for quick analysis	
egen int m_en_rank = rank(m_en_med), field by(weekday) // 1 is the highest (busiest)
egen int e_en_rank = rank(e_en_med), field by(weekday) // 1 is the highest (busiest)
egen int m_en_e_en_rank = rank(med_r_m_en_e_en), track by(weekday) // 1 is the lowest (most commercial)
egen int m_ex_e_ex_rank = rank(med_r_m_ex_e_ex), field by(weekday) // 1 is the highest (most commercial)

*Set the format to avoid scientific notation before CSV export
format m_en_med e_en_med m_ex_med e_ex_med %15.0f

*Save the file as DTA, CSV, and a slimmed down CSV
save ratios_cycle_one_and_two_non_dst_snapshot.dta, replace
outsheet using ratios_cycle_one_and_two_non_dst_snapshot.csv, comma replace
outsheet station bizdist med_r_m_en_e_en m_en_med e_en_med ///
	using key_ratio_cycle_one_and_two_non_dst_snapshot.csv if weekday == 1, comma replace

