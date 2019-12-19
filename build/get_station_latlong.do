version 16.0

do header.do


**THIS SECTION CREATES STATION LAT/LONG FILE FOR MERGING
insheet using "$qgis/stations/geocoded_stations.csv", clear

	rename v1 remote
	rename v2 booth
	rename v3 station_latlongname
	rename v4 linename
	rename v5 srt
	rename v6 lat_deg
	rename v7 long_deg
	
	drop linename srt
	
	collapse (mean) lat_deg long_deg (first) station_latlongname, by(remote)

save $subway_raw/station_latlong, replace	
