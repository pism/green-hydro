#!/bin/bash

 MYSHEBANGLINE="#!/bin/bash"
MYMPIQUEUELINE="#PBS -q transfer"
 MYMPITIMELINE="#PBS -l walltime=8:00:00"
 MYMPISIZELINE="#PBS -l nodes=1:ppn=1"
  MYMPIOUTLINE="#PBS -j oe"

out_dir=1500m_hindcast/processed/greenland/yearly
reg_dir=1500m_hindcast/processed/regional/yearly

start=2000
while [ $start -lt 2007 ]; do
    echo $start
    end=$[$start+1]
    
    POST=post_${start}-${end}.sh

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
  ncpdq -O -4 -L 3 -a time,y,x -d x,-222000.,-60000. -d y,-2330000.,-2230000. ex_g1500m_hydro_null_${start}-${end}.nc ${reg_dir}/Jakobshavn_ex_g1500m_hydro_null_${start}-${end}.nc
  nc2cdo.py --srs "+init=epsg:3413" ${reg_dir}/Jakobshavn_ex_g1500m_hydro_null_${start}-${end}.nc

EOF

    qsub $POST
			  
    start=$[$start+1]
done


