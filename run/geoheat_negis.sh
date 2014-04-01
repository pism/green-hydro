#!/bin/bash

# (C) 2014 by Andy Aschwanden
#
# calculate geothermal heat production over the NEGIS area
#
# example:
#
# ./geoheat_negis.sh     ## <-  2km grid (default)
# ./geoheat_negis.sh 10  ## <- 10km grid
set -e # exit on error

GRID=2  # default grid resolution in km
if [ $# -gt 0 ] ; then
  GRID="$1"
fi

# just copy bheaflx over
ncks -O -v bheatflx,lat,lon pism_Greenland_${GRID}km_v2_hotspot.nc bheatflx_Greenland_${GRID}km_hotspot.nc
# calculate grid area
cdo gridarea bheatflx_Greenland_${GRID}km_hotspot.nc gridarea.nc
# set all bheatflx values outside of NEGIS to zero
scalar_within_poly.py -i -v bheatflx ../outlines/negis_outline.shp bheatflx_Greenland_${GRID}km_hotspot.nc
# Multipy bheatflx and gridarea, sum up, and covert mW -> W
cdo divc,1000 -fldsum -mul bheatflx_Greenland_${GRID}km_hotspot.nc gridarea.nc bheat_negis_${GRID}km_hotspot.nc
# Fix units
ncatted -a units,bheatflx,o,c,"W" bheat_negis_${GRID}km_hotspot.nc

