
 MYSHEBANGLINE="#!/bin/bash"
MYMPIQUEUELINE="#PBS -q transfer"
 MYMPITIMELINE="#PBS -l walltime=4:00:00"
 MYMPISIZELINE="#PBS -l nodes=1:ppn=1"
  MYMPIOUTLINE="#PBS -j oe"

filepre=g${GRID}m_${EXPERIMENTR}

if [ "$VERSION" = "2" ]; then
    MYTYPE="MO14 2015-04-27"
elif [ "$VERSION" = "1.2" ]; then
    MYTYPE="MO14 2014-11-19"
else
    echo "$VERSION not recogniced, exciting"
    exit
fi
OTYPE="${OTYPE}"

tl_dir=relax_${GRID}m_${CLIMATE}_${TYPE}
nc_dir=processed
jk_dir=jakobshavn
fill=-2e9

cat - > $POSTR <<EOF
$MYSHEBANGLINE
$MYMPIQUEUELINE
$MYMPITIMELINE
$MYMPISIZELINE
$MYMPIOUTLINE

source ~/python/bin/activate

cd \$PBS_O_WORKDIR
  
if [ ! -d ${tl_dir} ]; then
    mkdir ${tl_dir}
fi

if [ ! -d ${tl_dir}/${nc_dir} ]; then
    mkdir ${tl_dir}/${nc_dir}
fi

if [ ! -d ${tl_dir}/${jk_dir} ]; then
    mkdir ${tl_dir}/${jk_dir}
fi


if [ -f ${filepre}.nc ]; then
    rm -f tmp_${filepre}_1.nc ${tl_dir}/${nc_dir}/${filepre}_1.nc
    ncks -O --64 -d x,-220000.,-110000. -d y,-2310000.,-2240000. ex_${filepre}_1.nc ${tl_dir}/${jk_dir}/jak_ex_${filepre}_1.nc
    ncks --64 -v enthalpy,litho_temp,temp -x ${filepre}_1.nc ${tl_dir}/${nc_dir}/${filepre}_1.nc
    ncap2 -O -s "uflux=ubar*thk; vflux=vbar*thk; velshear_mag=velsurf_mag-velbase_mag; where(thk<50) {velshear_mag=$fill; velbase_mag=$fill; velsurf_mag=$fill; flux_mag=$fill;}; sliding_r = velbase_mag/velsurf_mag; tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag);" ${tl_dir}/${nc_dir}/${filepre}_1.nc ${tl_dir}/${nc_dir}/${filepre}_1.nc
    ncatted -a ocean_forcing_type,run_stats,o,c,"$OTYPE" -a bed_data_set,run_stats,o,c,"$MYTYPE" -a grid_dx_meters,run_stats,o,f,$GRID -a grid_dy_meters,run_stats,o,f,$GRID -a long_name,uflux,o,c,"Vertically-integrated horizontal flux of ice in the X direction" -a long_name,vflux,o,c,"Vertically-integrated horizontal flux of ice in the Y direction" -a units,uflux,o,c,"m2 year-1" -a units,vflux,o,c,"m2 year-1" -a units,sliding_r,o,c,"1" -a units,tau_r,o,c,"1" -a units,tau_rel,o,c,"1" ${tl_dir}/${nc_dir}/${filepre}_1.nc
fi

EOF
