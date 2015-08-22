
 MYSHEBANGLINE="#!/bin/bash"
MYMPIQUEUELINE="#PBS -q transfer"
 MYMPITIMELINE="#PBS -l walltime=4:00:00"
 MYMPISIZELINE="#PBS -l nodes=1:ppn=1"
  MYMPIOUTLINE="#PBS -j oe"

filepre=g${GRID}m_${EXPERIMENT}

if [ "$TYPE" = "ctrl_v2" ]; then
    MYTYPE="MO14 2015-04-27"
elif [ "$TYPE" = "1985_v2" ]; then
    MYTYPE="MO14 2015-04-27"
elif [ "$TYPE" = "1985_v2b" ]; then
    MYTYPE="MO14 2015-04-27"
elif [ "$TYPE" = "1985_v2c" ]; then
    MYTYPE="MO14 2015-04-27"
elif [ "$TYPE" = "ctrl_v1.2" ]; then
    MYTYPE="MO14 2014-11-19"
elif [ "$TYPE" = "ctrl" ]; then
    MYTYPE="MO14 2014-06-26"
elif [ "$TYPE" = "old_bed" ]; then
    MYTYPE="BA01"
elif [ "$TYPE" = "old_bed_v1.2" ]; then
    MYTYPE="BA01"
elif [ "$TYPE" = "searise" ]; then
    MYTYPE="SR13"
else
    echo "$TYPE not recogniced, exciting"
    exit
fi

tl_dir=hindcast_${GRID}m_${CLIMATE}_${TYPE}
nc_dir=processed
jk_dir=jakobshavn

fill=-2e9
# seconds per year, from UDUNITS
SECPERA=3.15569259747e7

cat - > $POSTH <<EOF
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
    rm -f tmp_${filepre}.nc ${tl_dir}/${nc_dir}/${filepre}.nc
    ncks -O --64 -d x,-220000.,-110000. -d y,-2310000.,-2240000. ex_${filepre}.nc ${tl_dir}/${jk_dir}/jak_ex_${filepre}.nc
    ncks --64 -v enthalpy,litho_temp,temp -x ${filepre}.nc ${tl_dir}/${nc_dir}/${filepre}.nc
    ncap2 -O -s "uflux=ubar*thk; vflux=vbar*thk; velshear_mag=velsurf_mag-velbase_mag; where(thk<50) {velshear_mag=$fill; velbase_mag=$fill; velsurf_mag=$fill; flux_mag=$fill;}; sliding_r = velbase_mag/velsurf_mag; tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag);" ${tl_dir}/${nc_dir}/${filepre}.nc ${tl_dir}/${nc_dir}/${filepre}.nc
    ncatted -a bed_data_set,run_stats,o,c,"$MYTYPE" -a grid_dx_meters,run_stats,o,f,$GRID -a grid_dy_meters,run_stats,o,f,$GRID -a long_name,uflux,o,c,"Vertically-integrated horizontal flux of ice in the X direction" -a long_name,vflux,o,c,"Vertically-integrated horizontal flux of ice in the Y direction" -a units,uflux,o,c,"m2 year-1" -a units,vflux,o,c,"m2 year-1" -a units,sliding_r,o,c,"1" -a units,tau_r,o,c,"1" -a units,tau_rel,o,c,"1" ${tl_dir}/${nc_dir}/${filepre}.nc
    ncap2 -O -s "velshear_mag=velsurf_mag-velbase_mag; where(thk<50) {velshear_mag=$fill; velbase_mag=$fill; velsurf_mag=$fill; flux_mag=$fill;}; sliding_r = velbase_mag/velsurf_mag; tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag);" ${tl_dir}/${jk_dir}/jak_ex_${filepre}.nc ${tl_dir}/${jk_dir}/jak_ex_${filepre}.nc
    ncatted -a bed_data_set,run_stats,o,c,"$MYTYPE" -a grid_dx_meters,run_stats,o,f,$GRID -a grid_dy_meters,run_stats,o,f,$GRID -a long_name,uflux,o,c,"Vertically-integrated horizontal flux of ice in the X direction" -a long_name,vflux,o,c,"Vertically-integrated horizontal flux of ice in the Y direction" -a units,uflux,o,c,"m2 year-1" -a units,vflux,o,c,"m2 year-1" -a units,sliding_r,o,c,"1" -a units,tau_r,o,c,"1" -a units,tau_rel,o,c,"1" ${tl_dir}/${jk_dir}/jak_ex_${filepre}.nc
ncap2 -O -s '*sz_idt=time.size(); *dhdt[\$time,\$y,\$x]= 0.f; *dHdt[\$time,\$y,\$x]= 0.f; for(*idt=1 ; idt<sz_idt ; idt++) {dhdt(idt,:,:)=(usurf(idt,:,:)-usurf(idt-1,:,:))/(time(idt)-time(idt-1))*$SECPERA; dHdt(idt,:,:)=(thk(idt,:,:)-thk(idt-1,:,:))/(time(idt)-time(idt-1))*$SECPERA;} dhdt.ram_write(); dHdt.ram_write();' ${tl_dir}/${jk_dir}/jak_ex_${filepre}.nc ${tl_dir}/${jk_dir}/jak_ex_${filepre}.nc
ncatted -a units,dhdt,o,c,'m year-1' \
        -a units,dHdt,o,c,'m year-1' \
        -a long_name,dhdt,o,c,'rate of change of surface_altitude' \
        -a long_name,dHdt,o,c,'rate of change of ice thickness' \
        -a grid_mapping,dhdt,o,c,'mapping' \
        -a grid_mapping,dHdt,o,c,'mapping' \
        -a cell_methods,dhdt,o,c,'time: mean (interval: 1 month)' \
        -a cell_methods,dHdt,o,c,'time: mean (interval: 1 month)' ${tl_dir}/${jk_dir}/jak_ex_${filepre}.nc
ncks -O -d time,,,12  ${tl_dir}/${jk_dir}/jak_ex_${filepre}.nc  ${tl_dir}/${jk_dir}/jak_ex_${filepre}_ym.nc
ncap2 -O -s '*sz_idt=time.size(); *dhdt[\$time,\$y,\$x]= 0.f; *dHdt[\$time,\$y,\$x]= 0.f; for(*idt=1 ; idt<sz_idt ; idt++) {dhdt(idt,:,:)=(usurf(idt,:,:)-usurf(idt-1,:,:))/(time(idt)-time(idt-1))*$SECPERA; dHdt(idt,:,:)=(thk(idt,:,:)-thk(idt-1,:,:))/(time(idt)-time(idt-1))*$SECPERA;} dhdt.ram_write(); dHdt.ram_write();' ${tl_dir}/${jk_dir}/jak_ex_${filepre}_ym.nc ${tl_dir}/${jk_dir}/jak_ex_${filepre}_ym.nc
ncatted -a units,dhdt,o,c,'m year-1' \
        -a units,dHdt,o,c,'m year-1' \
        -a long_name,dhdt,o,c,'rate of change of surface_altitude' \
        -a long_name,dHdt,o,c,'rate of change of ice thickness' \
        -a grid_mapping,dhdt,o,c,'mapping' \
        -a grid_mapping,dHdt,o,c,'mapping' \
        -a cell_methods,dhdt,o,c,'time: sum (interval: 1 year)' \
        -a cell_methods,dHdt,o,c,'time: sum (interval: 1 year)' ${tl_dir}/${jk_dir}/jak_ex_${filepre}_ym.nc
fi
EOF
