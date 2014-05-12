#!/bin/bash

# Copyright (C) 2014 Andy Aschwanden

# downloads "SeaRISE" master dataset
# downloads "hotspot" master dataset
# adds climatic mass balance and precip from SeaRISE to hotspot data set

set -e -x  # exit on error

# run ./preprocess.sh 1 if you havent CDO compiled with OpenMP
NN=1  # default number of processors
if [ $# -gt 0 ] ; then
  NN="$1"
fi

# remove bad upstream values from 1985 DEM
CUT=../outlines/dem_clean.shp
DATANAME=DEM_5.5_july_24_85
wget -nc http://pism-docs.org/download/${DATANAME}.dat
GIMP=gimpdem_90m
wget -nc ftp://ftp-bprc.mps.ohio-state.edu/downloads/gdg/gimpdem/${GIMP}.tif

# Remap 1985 to GIMP DEM projection, dimensions, and resolution
gdalwarp -overwrite -srcnodata 1.69971e+38 -dstnodata -2e9 -s_srs epsg:32622 -t_srs epsg:3413 -tr 90 90 -te -639955 -3355595 855845 -655595 -r average -cutline $CUT -of GTiff ${DATANAME}.dat ${DATANAME}_epsg3413.tif

#
OUT=usurf_90m_1985_epsg3413
gdal_merge.py -n -2e9 -of GTiff -o $OUT.tif ${GIMP}.tif ${DATANAME}_epsg3413.tif

IN=$OUT
OUT=usurf_1km_1985

gdalwarp -overwrite -s_srs epsg:3413 -t_srs "+proj=stere +lat_0=90 +lat_ts=71 +lon_0=-39 +k=1 +x_0=0 +y_0=0 +ellps=WGS84 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs" -te -800000.0 -3400000.0 700000.0 -600000.0 -tr 1000 1000 -r average -of GTiff $IN.tif  $OUT.tif

gdal_translate -of netCDF $OUT.tif $OUT.nc

exit
ncatted -a _FillValue,Band1,o,f,-2e9 $OUT.nc
fill_missing.py -v Band1 -f $OUT.nc -o usurf_1985.nc
ncrename -v Band1,usurf usurf_1985.nc
