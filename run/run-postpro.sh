
 MYSHEBANGLINE="#!/bin/bash"
MYMPIQUEUELINE="#PBS -q transfer"
 MYMPITIMELINE="#PBS -l walltime=2:00:00"
 MYMPISIZELINE="#PBS -l nodes=1:ppn=1"
  MYMPIOUTLINE="#PBS -j oe"

geotiff="--geotiff_file MODISGreenland1kmclean_cut.tif"
#geotiff=""
fluxgates=greenland-flux-gates-250m.shp
res=300
mres=l
fill=-2e9
filepre=g${GRID}m_${EXPERIMENT}_${DURA}a

tl_dir=${GRID}m_${CLIMATE}_${TYPE}
nc_dir=processed
fig_dir=figures
spc_dir=speed_contours
pr_dir=profiles

cat - > $POST <<EOF
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

if [ ! -d ${tl_dir}/${fig_dir} ]; then
    mkdir ${tl_dir}/${fig_dir}
fi

if [ ! -d ${tl_dir}/${spc_dir} ]; then
    mkdir ${tl_dir}/${spc_dir}
fi

if [ -f ${filepre}.nc ]; then
    # because QGIS doesn't like (x,y) ordering
    sh add_epsg3413_mapping.sh ${filepre}.nc
    ncks -v enthalpy,litho_temp,temp_pa,liqfrac -x ${filepre}.nc tmp_${filepre}.nc
    ncpdq -O --64 -3  -a time,y,x tmp_${filepre}.nc ${tl_dir}/${nc_dir}/${filepre}.nc
    rm tmp_$filepre}.nc ${tl_dir}/${nc_dir}/${filepre}.nc
    ncap2 -O -s "velshear_mag=velsurf_mag-velbase_mag; where(thk<50) {velshear_mag=$fill; velbase_mag=$fill; velsurf_mag=$fill; flux_mag=$fill;}; sliding_r = velbase_mag/velsurf_mag; tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag)" ${tl_dir}/${nc_dir}/${filepre}.nc ${tl_dir}/${nc_dir}/${filepre}.nc
    ncatted -a units,sliding_r,o,c,"1" -a units,tau_r,o,c,"1" -a units,tau_rel,o,c,"1" ${tl_dir}/${nc_dir}/${filepre}.nc
fi



EOF
