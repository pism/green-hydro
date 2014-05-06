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

# generate config file
echo "  Generating config files..."
for CONFIG in "hydro_config"; do
ncgen -o ${CONFIG}.nc ${CONFIG}.cdl
done
echo "  Done generating config file."
echo


# get file; see page http://websrv.cs.umt.edu/isis/index.php/Present_Day_Greenland
DATAVERSION=1.1
DATAURL=http://websrv.cs.umt.edu/isis/images/a/a5/
DATANAME=Greenland_5km_v$DATAVERSION.nc

echo "fetching master file ... "
wget -nc ${DATAURL}${DATANAME}   # -nc is "no clobber"
echo "  ... done."
echo


PISMVERSION=pism_$DATANAME
echo -n "creating bootstrapable $PISMVERSION from $DATANAME ... "
# copy the vars we want, and preserve history and global attrs
ncks -O -v mapping,lat,lon,bheatflx,topg,thk,presprcp,smb,airtemp2m $DATANAME $PISMVERSION
# convert from water equiv to ice thickness change rate; assumes ice density 910.0 kg m-3
ncap2 -O -s "precipitation=presprcp*(1000.0/910.0)" $PISMVERSION $PISMVERSION
ncatted -O -a units,precipitation,c,c,"m/year" $PISMVERSION
ncatted -O -a long_name,precipitation,c,c,"ice-equivalent mean annual precipitation rate" $PISMVERSION
# delete incorrect standard_name attribute from bheatflx; there is no known standard_name
ncatted -a standard_name,bheatflx,d,, $PISMVERSION
# use pism-recognized name for 2m air temp
ncrename -O -v airtemp2m,ice_surface_temp  $PISMVERSION
ncatted -O -a units,ice_surface_temp,c,c,"Celsius" $PISMVERSION
# use pism-recognized name and standard_name for surface mass balance, after
# converting from liquid water equivalent thickness per year to [kg m-2 year-1]
ncap2 -t $NN -O -s "climatic_mass_balance=1000.0*smb" $PISMVERSION $PISMVERSION
ncatted -O -a standard_name,climatic_mass_balance,m,c,"land_ice_surface_specific_mass_balance" $PISMVERSION
ncatted -O -a units,climatic_mass_balance,m,c,"kg m-2 year-1" $PISMVERSION
# de-clutter by only keeping vars we want
ncks -O -v mapping,lat,lon,bheatflx,topg,thk,precipitation,ice_surface_temp,climatic_mass_balance \
  $PISMVERSION $PISMVERSION
# straighten dimension names
ncrename -O -d x1,x -d y1,y -v x1,x -v y1,y $PISMVERSION $PISMVERSION
nc2cdo.py $PISMVERSION
echo "done."
echo

# extract paleo-climate time series into files suitable for option
# -atmosphere ...,delta_T
TEMPSERIES=pism_dT.nc
echo -n "creating paleo-temperature file $TEMPSERIES from $DATANAME ... "
ncks -O -v oisotopestimes,temp_time_series $DATANAME $TEMPSERIES
ncrename -O -d oisotopestimes,time \
            -v oisotopestimes,time \
            -v temp_time_series,delta_T $TEMPSERIES
# reverse time dimension
ncpdq -O --rdr=-time $TEMPSERIES $TEMPSERIES
# make times follow same convention as PISM
ncap2 -t $NN -O -s "time=-time" $TEMPSERIES $TEMPSERIES
ncatted -O -a units,time,m,c,"years since 1-1-1" $TEMPSERIES
ncatted -O -a calendar,time,c,c,"365_day" $TEMPSERIES
ncatted -O -a units,delta_T,m,c,"Kelvin" $TEMPSERIES
echo "done."
echo

# extract paleo-climate time series into files suitable for option
# -ocean ...,delta_SL
SLSERIES=pism_dSL.nc
echo -n "creating paleo-sea-level file $SLSERIES from $DATANAME ... "
ncks -O -v sealeveltimes,sealevel_time_series $DATANAME $SLSERIES
ncrename -O -d sealeveltimes,time \
            -v sealeveltimes,time \
            -v sealevel_time_series,delta_SL $SLSERIES
# reverse time dimension
ncpdq -t $NN -O --rdr=-time $SLSERIES $SLSERIES
# make times follow same convention as PISM
ncap2 -O -s "time=-time" $SLSERIES $SLSERIES
ncatted -O -a units,time,m,c,"years since 1-1-1" $SLSERIES
ncatted -O -a calendar,time,c,c,"365_day" $SLSERIES
echo "done."
echo

# get old Bamber topograpy
DATAVERSION=0.93
DATAURL=http://websrv.cs.umt.edu/isis/images/8/86/
DATANAME=Greenland_5km_v$DATAVERSION.nc

echo "fetching master file ... "
wget -nc ${DATAURL}${DATANAME}   # -nc is "no clobber"
echo "  ... done."
echo

PISMVERSIONOLD=pism_$DATANAME
echo -n "creating bootstrapable $PISMVERSIONOLD from $DATANAME ... "
# copy the vars we want, and preserve history and global attrs
ncks -O -v mapping,lat,lon,topg,thk $DATANAME $PISMVERSIONOLD
# straighten dimension names
ncrename -O -d x1,x -d y1,y -v x1,x -v y1,y $PISMVERSIONOLD $PISMVERSIONOLD
nc2cdo.py $PISMVERSIONOLD
echo "done."
echo

nc2cdo.py $PISMVERSION
HS=970mW_hs
CTRL=ctrl
OLD=old_bed
for GS in "20" "10" "5" "2.5" "2" "1"; do
    DATANAME=pism_Greenland_${GS}km_v2
    wget -nc http://pism-docs.org/download/${DATANAME}.nc
    nc2cdo.py ${DATANAME}.nc
    ncks -O $DATANAME.nc ${DATANAME}_${CTRL}.nc
    ncks -O -v topg,thk -x $DATANAME.nc ${DATANAME}_${OLD}.nc
    echo
    echo "Creating hotspot"
    echo 
    sh create_hotspot.sh $NN $GS ${DATANAME}.nc ${DATANAME}_${HS}.nc
    echo
    echo "Adding climatic fields"
    echo
    if [[ $NN == 1 ]] ; then
	cdo remapbil,${DATANAME}.nc $PISMVERSION tmp_Greenland_${GS}km.nc
	cdo remapbil,${DATANAME}.nc $PISMVERSIONOLD old_Greenland_${GS}km.nc
    else
	cdo -P $NN remapbil,${DATANAME}.nc $PISMVERSION tmp_Greenland_${GS}km.nc
	cdo -P $NN remapbil,${DATANAME}.nc $PISMVERSIONOLD old_Greenland_${GS}km.nc
    fi
    ncks -A -v x,y ${DATANAME}.nc tmp_Greenland_${GS}km.nc
    echo
    ncks -A -v climatic_mass_balance,precipitation,ice_surface_temp tmp_Greenland_${GS}km.nc ${DATANAME}_${CTRL}.nc
    ncks -A -v climatic_mass_balance,precipitation,ice_surface_temp tmp_Greenland_${GS}km.nc ${DATANAME}_${HS}.nc
    ncks -A -v climatic_mass_balance,precipitation,ice_surface_temp tmp_Greenland_${GS}km.nc ${DATANAME}_${OLD}.nc
    ncks -A -v thk,topg old_Greenland_${GS}km.nc ${DATANAME}_${OLD}.nc
    ncatted -O -a _FillValue,thk,d,, -a missing_value,thk,d,, ${DATANAME}_${OLD}.nc
    ncap2 -O -s "where(thk<0) thk=0;" ${DATANAME}_${OLD}.nc ${DATANAME}_${OLD}.nc
done

