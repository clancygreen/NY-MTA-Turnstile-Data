version 16.0

* Get mac definitions.
do header.do

* Run build.
timer on 1

do get_station_crosswalk.do
do get_station_latlong.do
do process_old.do
do process_new.do
do append_old_and_new.do
do check_against_df.do

timer off 1
timer list 1
