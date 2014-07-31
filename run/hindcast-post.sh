#!/bin/bash

 MYSHEBANGLINE="#!/bin/bash"
MYMPIQUEUELINE="#PBS -q transfer"
 MYMPITIMELINE="#PBS -l walltime=8:00:00"
 MYMPISIZELINE="#PBS -l nodes=1:ppn=1"
  MYMPIOUTLINE="#PBS -j oe"

out_dir=1500m_hindcast/processed/greenland/yearly
reg_dir=1500m_hindcast/processed/regional/yearly

start=1988
while [ $start -lt 1996 ]; do
    echo $start
    end=$[$start+1]
    for var in "bmelt" "bwat" "sigma_xx" "sigma_yy" "sigma_xy" "diffusivity" "h_x_i" "h_x_j" "h_y_i" "h_y_j" "mask" "eigen1" "eigen2" "taub_x" "taub_y" "taud_x" "taud_y" "taud_mag" "tempicethk_basal" "temppabase" "thk" "topg" "usurf" "uvelbase" "vvelbase" "uvelsurf" "vvelsurf" "velsurf_mag" "velbase_mag" "wvelbase" "wvelsurf" "tillwat"; do
        echo $var
        POST=post_${start}-${end}_${var}.sh

        cat - > $POST <<EOF

$MYSHEBANGLINE
$MYMPIQUEUELINE
$MYMPITIMELINE
$MYMPISIZELINE
$MYMPIOUTLINE

cd \$PBS_O_WORKDIR

if [ ! -d ${out_dir} ]; then
    mkdir -p ${out_dir}
fi

if [ ! -d ${reg_dir} ]; then
    mkdir -p ${reg_dir}
fi

  sh add_epsg3413_mapping.sh ex_g1500m_hydro_null_${start}-${end}.nc
  ncpdq -O -4 -L 3 -a time,y,x -v ${var} ex_g1500m_hydro_null_${start}-${end}.nc ${out_dir}/ex_g1500m_hydro_null_${start}-${end}_${var}.nc
  ncks -A -v pism_overrides,pism_config ex_g1500m_hydro_null_${start}-${end}.nc ${out_dir}/ex_g1500m_hydro_null_${start}-${end}_${var}.nc
  nc2cdo.py --srs "+init=epsg:3413" ${out_dir}/ex_g1500m_hydro_null_${start}-${end}_${var}.nc
  ncks -d x,-222000.,-60000. -d y,-2330000.,-2230000. ${out_dir}/ex_g1500m_hydro_null_${start}-${end}_${var}.nc ${reg_dir}/Jakobshavn_ex_g1500m_hydro_null_${start}-${end}_${var}.nc
EOF

        qsub $POST
    done			  
    start=$[$start+1]
done


