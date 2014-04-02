#!/bin/bash

# (C) 2014 by Andy Aschwanden
#
# integrate basal heat flux over the NEGIS area
#
# example:
#
# ./geoheat_negis.sh MYFILE

set -e # exit on error

INFILE=pism_Greenland_20km_v2_970mW_hs.nc
if [ $# -gt 0 ] ; then
  INFILE="$1"
fi

# just copy bheaflx over
ncks -O -v bheatflx $INFILE bheatflx_${INFILE}
nc2cdo.py bheatflx_${INFILE}
# calculate grid area
cdo gridarea bheatflx_${INFILE} gridarea.nc
# set all bheatflx values outside of NEGIS to zero
scalar_within_poly.py -i -v bheatflx ../outlines/negis_outline.shp bheatflx_${INFILE}
# Multipy bheatflx and gridarea, sum up and convert W -> GW (giga Watt)
cdo divc,1e9 -fldsum -mul bheatflx_${INFILE} gridarea.nc bheat_negis_${INFILE}
# Fix units
ncatted -a units,bheatflx,o,c,"GW" bheat_negis_${INFILE}

