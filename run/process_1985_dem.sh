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
gdal_translate -a_nodata 1.70141e38 -of GTiff -a_srs EPSG:32622 ${DATANAME}.dat ${DATANAME}.tif
gdal_translate -of netCDF ${DATANAME}.tif ${DATANAME}.nc
ncap2 -O -s "thk=(1/((1028./910)-1)+1)*Band1" ${DATANAME}.nc ${DATANAME}.nc

# Remap 1985 to GIMP DEM projection, dimensions, and resolution
# gdalwarp -overwrite -srcnodata 1.69971e+38 -dstnodata 0 -s_srs EPSG:32622 -t_srs EPSG:3413 -tr 90 90 -te -639955 -3355595 855845 -655595 -r bilinear -cutline $CUT -of GTiff  ${DATANAME}.tif ${DATANAME}_epsg3413.tif

gdalwarp -overwrite -srcnodata 1.70141e+038 -dstnodata 0 -s_srs EPSG:32622 -t_srs EPSG:3413 -tr 90 90 -te -639955 -3355595 855845 -655595 -r bilinear -cutline $CUT -of netCDF  ${DATANAME}.dat ${DATANAME}_epsg3413.nc
ncrename -v Band1,usurf_1985 ${DATANAME}_epsg3413.nc
ncatted -a _FillValue,usurf_1985,d,, ${DATANAME}_epsg3413.nc

GIMP=gimpdem_90m
wget -nc ftp://ftp-bprc.mps.ohio-state.edu/downloads/gdg/gimpdem/${GIMP}.tif
gdal_translate -of netCDF ${GIMP}.tif ${GIMP}.nc
ncks -O ${GIMP}.nc  ${GIMP}_merged.nc
ncrename -v Band1,usurf ${GIMP}_merged.nc
ncks -A -v usurf_1985 ${DATANAME}_epsg3413.nc ${GIMP}_merged.nc
ncap2 -O -s "where(usurf_1985>0) usurf=usurf_1985;" ${GIMP}_merged.nc ${GIMP}_merged.nc

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
gdalwarp -overwrite -s_srs epsg:3413 -t_srs "+proj=stere +lat_0=90 +lat_ts=71 +lon_0=-39 +k=1 +x_0=0 +y_0=0 +ellps=WGS84 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs" -te $TE -tr 1000 1000 -r average -of GTiff NETCDF:${GIMP}_merged.nc:usurf  $OUT.tif

gdal_translate -of netCDF $OUT.tif $OUT.nc

gdalwarp -overwrite -s_srs epsg:3413 -t_srs "+proj=stere +lat_0=90 +lat_ts=71 +lon_0=-39 +k=1 +x_0=0 +y_0=0 +ellps=WGS84 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs" -te $TE -tr 1000 1000 -r average -of GTiff ${GIMP}.tif ${GIMP}_1km.tif
gdal_translate -of netCDF ${GIMP}_1km.tif ${GIMP}_1km.nc
ncrename -v Band1,usurf ${GIMP}_1km.nc

cdo sub -selvar,usurf ${GIMP}_1km.nc -selvar,usurf pism_Greenland_1km_v3.nc geoid_correction.nc
ncatted -a missing_value,,d,, -a _FillValue,,d,, -a grid_mapping,usurf,o,c,"mapping"  geoid_correction.nc
ncks -A -v mapping pism_Greenland_1km_v3.nc geoid_correction.nc
THK=thk_1985
cdo sub $OUT.nc geoid_correction.nc ${OUT}_corrected.nc
ncks -O  -v usurf -x pism_Greenland_1km_v3.nc $THK.nc
ncks -A -v usurf  ${OUT}_corrected.nc $THK.nc
# Calculate thickness of floating tongue following Motyka et al (2011)
ncap2 -O -s "thk=usurf-topg; where(LandMask!=2) thk=0; thk_shelf=(1/((1028./910)-1)+1)*usurf; where(LandMask==0 && thk_shelf>300) thk=thk_shelf; where(LandMask==0 && (usurf-thk)<topg) topg=usurf-thk-200;" $THK.nc $THK.nc
ncks -A -v x,y pism_Greenland_1km_v3.nc $THK.nc
ncatted -a missing_value,,d,, -a _FillValue,,d,, -a grid_mapping,topg,o,c,"mapping" -a grid_mapping,usurf,o,c,"mapping" -a grid_mapping,thk_shelf,o,c,"mapping" $THK.nc
OUTNAME=pism_Greenland_1km_1985
ncks -O -v thk_shelf -x $THK.nc ${OUTNAME}.nc
nc2cdo.py ${OUTNAME}.nc

for GRID in "20" "10" "2.5" "2"; do
    SRGRID=searise_${GRID}km_grid.nc
    create_greenland_grid.py -g $GRID $SRGRID
    nc2cdo.py $SRGRID
    
    if [[ $NN == 1 ]] ; then
	cdo -v remapcon,$SRGRID ${OUTNAME}.nc pism_Greenland_${GRID}km_1985.nc
    else
	cdo -v -P $NN remapcon,$SRGRID ${OUTNAME}.nc pism_Greenland_${GRID}km_1985.nc
    fi
    ncap2 -O -s "where(thk<0) thk=0." pism_Greenland_${GRID}km_1985.nc pism_Greenland_${GRID}km_1985.nc
    ncks -A -v x,y,mapping $SRGRID pism_Greenland_${GRID}km_1985.nc
    ncatted -a grid_mapping,thk,o,c,"mapping" -a grid_mapping,LandMask,o,c,"mapping" -a grid_mapping,usurf,o,c,"mapping" -a grid_mapping,topg,o,c,"mapping" pism_Greenland_${GRID}km_1985.nc
done

# remapcon has problems with generating weights for 5km grid.
# Use bilinear
for GRID in "5"; do
    SRGRID=searise_${GRID}km_grid.nc
    create_greenland_grid.py -g $GRID $SRGRID
    nc2cdo.py $SRGRID
    
    if [[ $NN == 1 ]] ; then
	cdo -v remapbil,$SRGRID ${OUTNAME}.nc pism_Greenland_${GRID}km_1985.nc
    else
	cdo -v -P $NN remapbil,$SRGRID ${OUTNAME}.nc pism_Greenland_${GRID}km_1985.nc
    fi
    ncap2 -O -s "where(thk<0) thk=0." pism_Greenland_${GRID}km_1985.nc pism_Greenland_${GRID}km_1985.nc
    ncks -A -v x,y,mapping $SRGRID pism_Greenland_${GRID}km_1985.nc
    ncatted -a grid_mapping,thk,o,c,"mapping" -a grid_mapping,LandMask,o,c,"mapping" -a grid_mapping,usurf,o,c,"mapping" -a grid_mapping,topg,o,c,"mapping" pism_Greenland_${GRID}km_1985.nc
done
