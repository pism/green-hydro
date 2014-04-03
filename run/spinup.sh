#!/bin/bash

# Copyright (C) 2014 Andy Aschwanden and Ed Bueler

set -e  # exit on error

#  creates spinup scripts using grid sequencing 20->10->5km.
#  scripts are suitable for PBS job scheduler
#  (see  http://www.adaptivecomputing.com/products/open-source/torque/)
#
#     $ ./spinup.sh paleo 970mW_hs    ## do paleo-climate spinup with 970mW hotspot
#     or
#     $ ./spinup.sh const     ## do constant -climate spinup
#  then, assuming you like the resulting scripts:
#     $ qsub do-climate-spinup.sh      ### <--- REALLY SUBMITS using qsub


set -e # exit on error

CLIMLIST="{const, paleo}"
TYPELIST="{ctrl, 970mW_hs}"
if [ $# -lt 2 ] ; then
  echo "spinup.sh ERROR: needs 2 positional arguments ... ENDING NOW"
  echo
  echo "usage:"
  echo
  echo "    spinup.sh CLIMATE TYPE"
  echo
  echo "  where:"
  echo "    CLIMATE   in $CLIMLIST"
  echo "    TYPE      in $TYPELIST"
  echo
  echo
  exit
fi

if [ -n "${PROC_PER_NODE:+1}" ] ; then  # check if env var is already set
    PROC_PER_NODE=$PROC_PER_NODE
else
    PROC_PER_NODE=4
fi

if [ -n "${QUEUE:+1}" ] ; then  # check if env var is already set
    QUEUE=$QUEUE
else
    QUEUE=standard_4
fi

# set CLIMATE from argument 1
if [ "$1" = "const" ]; then
    CLIMATE=$1
elif [ "$1" = "paleo" ]; then
    CLIMATE=$1
else
  echo "invalid second argument; must be in $CLIMLIST"
  exit
fi

# set TYPE from argument 2
if [ "$2" = "ctrl" ]; then
    TYPE=$2
elif [ "$2" = "970mW_hs" ]; then
    TYPE=$2
else
  echo "invalid second argument; must be in $TYPELIST"
  exit
fi

SCRIPTNAME=${CLIMATE}-spinup-${TYPE}.sh
export PISM_EXPERIMENT=$EXPERIMENT
export PISM_TITLE="Greenland Parameter Study"

# ###############################
# 20 km run
# ###############################

GRID=20
INFILE=pism_Greenland_${GRID}km_v2_${TYPE}.nc
PISM_DATANAME=$INFILE
DURA=100000
START=-125000
END=-25000
MKA=$(($END/-1000))

WALLTIME=12:00:00
NN=16
NODES=$(( $NN/$PROC_PER_NODE))

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROC_PER_NODE"
  MPIOUTLINE="#PBS -j oe"

SCRIPT="do_${GRID}km_m${MKA}ka_${CLIMATE}-spinup-${TYPE}.sh"
rm -f $SCRIPT
EXPERIMENT="${DURAKA}ka ${CLIMATE}-climate initialization $TYPE"

OUTFILE=g${GRID}km_m${MKA}ka_${CLIMATE}_${TYPE}.nc

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

# ###############################
# 10 km run
# ###############################

GRID=10
SCRIPTNAME=${GRID}km_${CLIMATE}-spinup-${TYPE}.sh
INFILE=pism_Greenland_${GRID}km_v2_${TYPE}.nc
REGRIDFILE=$OUTFILE
PISM_DATANAME=$INFILE
DURA=20000
START=-25000
END=-5000
MKA=$(($END/-1000))

WALLTIME=24:00:00
NN=32
NODES=$(( $NN/$PROC_PER_NODE))

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROC_PER_NODE"
  MPIOUTLINE="#PBS -j oe"

SCRIPT="do_${GRID}km_m${MKA}ka_${CLIMATE}-spinup-${TYPE}.sh"
rm -f $SCRIPT
EXPERIMENT="${DURAKA}ka ${CLIMATE}-climate initialization $TYPE"

OUTFILE=g${GRID}km_m${MKA}ka_${CLIMATE}_${TYPE}.nc

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

# this needs to be the same for 10 and 5km
REGRIDFILE=$OUTFILE

GRID=10
SCRIPTNAME=${GRID}km_${CLIMATE}-spinup-${TYPE}.sh
INFILE=pism_Greenland_${GRID}km_v2_${TYPE}.nc
REGRIDFILE=$OUTFILE
PISM_DATANAME=$INFILE
DURA=5000
START=-5000
END=0

WALLTIME=06:00:00
NN=32
NODES=$(( $NN/$PROC_PER_NODE))

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROC_PER_NODE"
  MPIOUTLINE="#PBS -j oe"

SCRIPT="do_${GRID}km_0_${CLIMATE}-spinup-${TYPE}.sh"
rm -f $SCRIPT
EXPERIMENT="${DURAKA}ka ${CLIMATE}-climate initialization with hotspot"

OUTFILE=g${GRID}km_0_${CLIMATE}_${TYPE}.nc

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

# ###############################
# 5 km run
# ###############################
	      
GRID=5
SCRIPTNAME=${GRID}km_${CLIMATE}-spinup-${TYPE}.sh
INFILE=pism_Greenland_${GRID}km_v2_${TYPE}.nc
PISM_DATANAME=$INFILE
DURA=5000
START=-5000
END=0

WALLTIME=96:00:00
NN=64
NODES=$(( $NN/$PROC_PER_NODE))

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROC_PER_NODE"
  MPIOUTLINE="#PBS -j oe"

SCRIPT="do_${GRID}km_0_${CLIMATE}-spinup-${TYPE}.sh"
rm -f $SCRIPT
EXPERIMENT="${DURAKA}ka ${CLIMATE}-climate initialization with hotspot"

OUTFILE=g${GRID}km_0_${CLIMATE}_${TYPE}.nc

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
