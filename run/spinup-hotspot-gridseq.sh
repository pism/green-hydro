#!/bin/bash

# Copyright (C) 2014 Andy Aschwanden and Ed Bueler

set -e  # exit on error

#  creates spinup scripts using grid sequencing 20->10->5km.
#  scripts are suitable for PBS job scheduler
#  (see  http://www.adaptivecomputing.com/products/open-source/torque/)
#
#     $ ./spinup-hotspot-gridseq.sh paleo     ## do paleo-climate spinup
#     or
#     $ ./spinup-hotspot-gridseq.sh const     ## do paleo-climate spinup
#  then, assuming you like the resulting scripts:
#     $ qsub do-climate-spinup-hotspot.sh      ### <--- REALLY SUBMITS using qsub


set -e # exit on error
CLIMLIST="{const, paleo}"
# set coupler from argument 2
if [ "$1" = "const" ]; then
    CLIMATE=$1
elif [ "$1" = "paleo" ]; then
    CLIMATE=$1
else
  echo "invalid second argument; must be in $CLIMLIST"
  exit
fi

SCRIPTNAME=${CLIMATE}-spinup-hotspot-gridref.sh
export PISM_EXPERIMENT=$EXPERIMENT
export PISM_TITLE="Greenland Parameter Study"

GRID=20
INFILE=pism_Greenland_${GRID}km_v2_hotspot.nc
#INFILE=g20km_steady_ssa.nc
PISM_DATANAME=$INFILE
DURA=100000
START=-125000
END=-25000

WALLTIME=12:00:00
NODES=2
NN=8

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q standard_4"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=4"
  MPIOUTLINE="#PBS -j oe"

SCRIPT="do_${GRID}km_${CLIMATE}-spinup-hotspot.sh"
rm -f $SCRIPT
EXPERIMENT="${DURAKA}ka ${CLIMATE}-climate initialization with hotspot"
MKA=$(($END/-1000))

OUTFILE=g${GRID}km_m${MKA}ka_${CLIMATE}_hotspot.nc

# insert preamble
echo $SHEBANGLINE >> $SCRIPT
echo >> $SCRIPT # add newline
echo $MPIQUEUELINE >> $SCRIPT
echo $MPITIMELINE >> $SCRIPT
echo $MPISIZELINE >> $SCRIPT
echo $MPIOUTLINE >> $SCRIPT
echo >> $SCRIPT # add newline
echo "cd \$PBS_O_WORKDIR" >> $SCRIPT
echo >> $SCRIPT # add newline
      
cmd="PISM_DO="" STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME  ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT

echo "($SPAWNSCRIPT)  $SCRIPT written"

GRID=10
SCRIPTNAME=${GRID}km_${CLIMATE}-spinup-hotspot-gridref.sh
INFILE=pism_Greenland_${GRID}km_v2_hotspot.nc
REGRIDFILE=$OUTFILE
PISM_DATANAME=$INFILE
DURA=20000
START=-25000
END=-5000

WALLTIME=24:00:00
NODES=8
NN=32

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q standard_4"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=4"
  MPIOUTLINE="#PBS -j oe"

SCRIPT="do_${GRID}km_${CLIMATE}-spinup-hotspot.sh"
rm -f $SCRIPT
EXPERIMENT="${DURAKA}ka ${CLIMATE}-climate initialization with hotspot"
MKA=$(($END/-1000))

OUTFILE=g${GRID}km_m${MKA}ka_${CLIMATE}_hotspot.nc

# insert preamble
echo $SHEBANGLINE >> $SCRIPT
echo >> $SCRIPT # add newline
echo $MPIQUEUELINE >> $SCRIPT
echo $MPITIMELINE >> $SCRIPT
echo $MPISIZELINE >> $SCRIPT
echo $MPIOUTLINE >> $SCRIPT
echo >> $SCRIPT # add newline
echo "cd \$PBS_O_WORKDIR" >> $SCRIPT
echo >> $SCRIPT # add newline
      
echo >> $SCRIPT
cmd="PISM_DO="" STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME REGRIDFILE=$REGRIDFILE ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
echo "($SPAWNSCRIPT)  $SCRIPT written"
	      
GRID=5
SCRIPTNAME=${GRID}km_${CLIMATE}-spinup-hotspot-gridref.sh
INFILE=pism_Greenland_${GRID}km_v2_hotspot.nc
REGRIDFILE=$OUTFILE
PISM_DATANAME=$INFILE
DURA=5000
START=-5000
END=0

WALLTIME=96:00:00
NODES=16
NN=64

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q standard_4"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=4"
  MPIOUTLINE="#PBS -j oe"

SCRIPT="do_${GRID}km_${CLIMATE}-spinup-hotspot.sh"
rm -f $SCRIPT
EXPERIMENT="${DURAKA}ka ${CLIMATE}-climate initialization with hotspot"
MKA=$(($END/-1000))

OUTFILE=g${GRID}km_0_${CLIMATE}_hotspot.nc

# insert preamble
echo $SHEBANGLINE >> $SCRIPT
echo >> $SCRIPT # add newline
echo $MPIQUEUELINE >> $SCRIPT
echo $MPITIMELINE >> $SCRIPT
echo $MPISIZELINE >> $SCRIPT
echo $MPIOUTLINE >> $SCRIPT
echo >> $SCRIPT # add newline
echo "cd \$PBS_O_WORKDIR" >> $SCRIPT
echo >> $SCRIPT # add newline
      
echo >> $SCRIPT
cmd="PISM_DO="" STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME REGRIDFILE=$REGRIDFILE PARAM_FTT="foo" ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
echo "($SPAWNSCRIPT)  $SCRIPT written"
