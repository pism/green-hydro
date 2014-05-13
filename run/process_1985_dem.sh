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
gdalwarp -overwrite -srcnodata 1.69971e+38 -dstnodata 0 -s_srs EPSG:32622 -t_srs EPSG:3413 -tr 90 90 -te -639955 -3355595 855845 -655595 -r bilinear -cutline $CUT -of netCDF  ${DATANAME}.dat ${DATANAME}_epsg3413.nc
ncatted -a _FillValue,Band1,d,, ${DATANAME}_epsg3413.nc

gdal_translate -of netCDF ${GIMP}.tif ${GIMP}.nc

cdo add  ${GIMP}.nc ${DATANAME}_epsg3413.nc usurf_90m_1985.nc
ncks -A -v x,y,polar_stereographic ${GIMP}.nc usurf_90m_1985.nc
ncatted -a grid_mapping,Band1,o,c,"polar_stereographic" usurf_90m_1985.nc
#
OUT=usurf_1km_1985

# These are the cell-centers of the corner grids
# llx=-800000.0 
# lly=-3400000.0 
# urx=700000.0 
# ury=-600000.0
# enlarge domain by 1 cell to get cell-center vs corner right
llx=-800500.0 
lly=-3400500. 
urx=700500.0 
ury=-599500.0
TE="$llx $lly $urx $ury"
gdalwarp -overwrite -s_srs epsg:3413 -t_srs "+proj=stere +lat_0=90 +lat_ts=71 +lon_0=-39 +k=1 +x_0=0 +y_0=0 +ellps=WGS84 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs" -te $TE -tr 1000 1000 -r average -of GTiff usurf_90m_1985.nc  $OUT.tif

gdal_translate -of netCDF $OUT.tif $OUT.nc


ncrename -v Band1,usurf $OUT.nc


cdo sub -selvar,usurf $OUT.nc -selvar,usurf pism_Greenland_1km_v3.nc geoid_correction.nc
THK=thk_1985
cdo sub $OUT.nc geoid_correction.nc ${OUT}_corrected.nc
ncks -O  -v usurf -x pism_Greenland_1km_v3.nc $THK.nc
ncks -A -v usurf  ${OUT}_corrected.nc $THK.nc
ncap2 -O -s "thk=usurf-topg; where(LandMask!=2) thk=0;" $THK.nc $THK.nc
ncks -A -v x,y pism_Greenland_1km_v3.nc $THK.nc
exit
ncatted -a _FillValue,Band1,o,f,-2e9 $OUT.nc
fill_missing.py -v Band1 -f $OUT.nc -o usurf_1985.nc
ncrename -v Band1,usurf usurf_1985.nc
