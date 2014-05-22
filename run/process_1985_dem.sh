#!/bin/bash

# Copyright (C) 2014 Andy Aschwanden

# downloads "SeaRISE" master dataset
# downloads "hotspot" master dataset
# adds climatic mass balance and precip from SeaRISE to hotspot data set

set -e -x  # exit on error

# run ./preprocess.sh 1 if you haven't CDO compiled with OpenMP
NN=1  # default number of processors
if [ $# -gt 0 ] ; then
  NN="$1"
fi

# remove bad upstream values from 1985 DEM
CUT=../outlines/dem_clean.shp
DATANAME=DEM_5.5_july_24_85
wget -nc http://pism-docs.org/download/${DATANAME}.dat
#ncap2 -O -s "thk=(1/((1028./910)-1)+1)*Band1" ${DATANAME}.nc ${DATANAME}.nc
gdalwarp -overwrite -t_srs EPSG:32622 -of GTiff $DATANAME.dat $DATANAME.tif


# Create a buffer that is a multiple of the grid resolution
# and works for grid resolutions up to 36km.
xmin=$((-638000 - 22650))
ymin=$((-3349600 - 22650))
xmax=$((864700 + 22650))
ymax=$((-657600 + 21350))

gdalwarp -overwrite -srcnodata 1.70141e+038 -dstnodata 0 -s_srs EPSG:32622 -t_srs EPSG:3413 -tr 150 150 -te $xmin $ymin $xmax $ymax -r average -cutline $CUT -of netCDF  ${DATANAME}.tif ${DATANAME}_epsg3413.nc

ncrename -v Band1,surface_1985 ${DATANAME}_epsg3413.nc
ncatted -a _FillValue,surface_1985,d,, ${DATANAME}_epsg3413.nc


mcbfile=Greenland_150m_mcb_jpl_v1.1
for var in "surface" "bed"; do
    gdalwarp -overwrite  -tr 150 150 -te $xmin $ymin $xmax $ymax -r average  -of GTiff  NETCDF:${mcbfile}.nc:${var} ${mcbfile}_ext_${var}.tif
    gdalwarp -overwrite -s_srs EPSG:3413 -t_srs EPSG:3413 -of netCDF ${mcbfile}_ext_${var}.tif ${mcbfile}_ext_${var}.nc
    ncrename -O -v Band1,$var ${mcbfile}_ext_${var}.nc ${mcbfile}_ext_${var}.nc 
done
for var in "mask"; do
    gdalwarp -overwrite  -tr 150 150 -te $xmin $ymin $xmax $ymax -r near  -of GTiff  NETCDF:${mcbfile}.nc:${var} ${mcbfile}_ext_${var}.tif
    gdalwarp -overwrite -s_srs EPSG:3413 -t_srs EPSG:3413 -of netCDF ${mcbfile}_ext_${var}.tif ${mcbfile}_ext_${var}.nc
    ncrename -O -v Band1,$var ${mcbfile}_ext_${var}.nc ${mcbfile}_ext_${var}.nc
    ncatted -a _FillValue,$var,d,, ${mcbfile}_ext_${var}.nc
done

ncks -O ${mcbfile}_ext_surface.nc  ${mcbfile}_merged.nc
ncks -A ${mcbfile}_ext_bed.nc  ${mcbfile}_merged.nc
ncks -A ${mcbfile}_ext_mask.nc  ${mcbfile}_merged.nc
ncks -A ${DATANAME}_epsg3413.nc  ${mcbfile}_merged.nc
ncks -O -4 ${mcbfile}_merged.nc ${mcbfile}_merged.nc
ncap2 -O -s "where(surface_1985>0) surface=surface_1985;" ${mcbfile}_merged.nc ${mcbfile}_merged.nc
# Calculate thickness of floating tongue following Motyka et al (2011), use 28.5m as an estimate to convert height
# above ellipsoid to mean sea level. Motyka suggests 28-29 m in the area of interest
ncap2 -O -s "thickness=surface-bed; where(mask!=2) thickness=0; thk_shelf=(1/((1028./910)-1)+1)*(surface-28.5);" ${mcbfile}_merged.nc ${mcbfile}_merged.nc
gdalwarp -overwrite -s_srs EPSG:3413 -t_srs EPSG:3413 -cutline ../outlines/jakobshavn_1985_floating_tongue.shp -of GTiff NETCDF:${mcbfile}_merged.nc:thk_shelf shelf.tif
gdalwarp -overwrite -of netCDF -s_srs EPSG:3413 -t_srs EPSG:3413 shelf.tif shelf.nc

# ncap2 -O -s "thickness=surface-bed; where(mask!=2) thickness=0; thk_shelf=(1/((1028./910)-1)+1)*(surface-28.5); where(mask==0 && thk_shelf>200) thickness=thk_shelf;" ${mcbfile}_merged.nc ${mcbfile}_merged.nc


exit

rm ${mcbfile}_ext*
