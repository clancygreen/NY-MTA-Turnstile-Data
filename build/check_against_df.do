version 16.0

do header.do


use $data/subwaydata_collapsed_final, clear

merge 1:1 * using $data/subwaydata_collapsed_final_cg

* Updated data slightly different for ~470 obs.
tab _merge

* Updated data goes through 2017.
gen year = year(dofc(statadateconformtime))
tab year if _merge == 2

* Different obs concentrated on Fridays in 2014.
tab dayofweek year if _merge == 1
