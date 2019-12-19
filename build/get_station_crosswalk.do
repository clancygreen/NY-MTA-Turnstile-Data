version 16.0

do header.do


**THIS SECTION STANDARDIZES THE STATION NAMES IN THE STATION CROSSWALK
*It makes sure each remote only maps to one station.
*It combines station and line names to create unique station names for each line.
*It combines stations that are connected via walkways.

insheet using $subway_raw/Remote-Booth-Station.csv, names

rename Remote remote
bysort remote: replace station = station[1]
bysort remote: replace linename = linename[1]
replace station = "14 ST-6 AVE" if remote == "R105"
replace linename = "FLM123" if station == "14 ST-6 AVE"
replace linename = "123ACE" if station =="34 ST-PENN STA"
replace station = "42 ST-TIMES SQ" if station == "42 ST-PA BUS TE"
replace linename = "ACENQRS1237" if station == "42 ST-TIMES SQ"
replace station = "COURT SQ-23 ST" if remote == "R346"
replace linename = "EMG7" if station == "COURT SQ-23 ST"
replace linename = "ACJZ2345" if station == "FULTON ST" & remote == "R028"
replace linename = "ACFR" if station == "JAY ST-METROTEC"
replace station = "CITY HALL" if station == "MURRAY ST-B'WAY"
replace linename = "EM6" if station == "51 ST"
replace station = "LEXINGTON-53 ST" if station == "51 ST"
replace station = "42 ST-BRYANT PK" if station == "5 AVE-BRYANT PK"
replace linename = "BDFM7" if station == "42 ST-BRYANT PK"
replace linename = "BDFQ6" if station == "BLEECKER ST"
replace station = "BROADWAY/LAFAY" if station == "BLEECKER ST"
replace linename = "2345S" if station == "BOTANIC GARDEN"
replace station = "FRANKLIN AVE" if station == "BOTANIC GARDEN"
gen station_line = station + "-" + linename

drop station
rename station_line station
label variable station "Station"

drop booth linename
duplicates drop

bys remote: gen temp=_n

drop if temp==2

save $subway_raw/station_crosswalk, replace
