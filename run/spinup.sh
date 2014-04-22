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

if [ -n "${PISM_PROC_PER_NODE:+1}" ] ; then  # check if env var is already set
    PISM_PROC_PER_NODE=$PISM_PROC_PER_NODE
else
    PISM_PROC_PER_NODE=4
fi
PROC_PER_NODE=$PISM_PROC_PER_NODE

if [ -n "${PISM_QUEUE:+1}" ] ; then  # check if env var is already set
    PISM_QUEUE=$PISM_QUEUE
else
    PISM_QUEUE=standard_4
fi
QUEUE=$PISM_QUEUE

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
PISM_SAVE="-25000,-10000,-5000,-2000,-1000,-500,-100"
DURA=125000
START=-125000
END=0

WALLTIME=12:00:00
NN=16
NODES=$(( $NN/$PROC_PER_NODE))

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROC_PER_NODE"
  MPIOUTLINE="#PBS -j oe"

SCRIPT="do_${GRID}km_${CLIMATE}-spinup-${TYPE}.sh"
rm -f $SCRIPT
EXPERIMENT="${CLIMATE}-climate initialization $TYPE"

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
      
cmd="PISM_DO="" STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME PISM_SAVE=$PISM_SAVE ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT

echo "($SPAWNSCRIPT)  $SCRIPT written"

# ###############################
# 10 km run
# ###############################

GRID=10
SCRIPTNAME=${GRID}km_${CLIMATE}-spinup-${TYPE}.sh
INFILE=pism_Greenland_${GRID}km_v2_${TYPE}.nc
FILE=`basename $OUTFILE .nc`
REGRIDFILE=snap_${FILE}_-25000.nc
PISM_DATANAME=$INFILE
PISM_SAVE="-10000,-5000,-2000,-1000,-500,-100"
DUAR=25000
START=-25000
END=0

WALLTIME=24:00:00
NN=32
NODES=$(( $NN/$PROC_PER_NODE))

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROC_PER_NODE"
  MPIOUTLINE="#PBS -j oe"

SCRIPT="do_${GRID}km_${CLIMATE}-spinup-${TYPE}.sh"
rm -f $SCRIPT
EXPERIMENT="${CLIMATE}-climate initialization $TYPE"

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
cmd="PISM_DO="" STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME REGRIDFILE=$REGRIDFILE PISM_SAVE=$PISM_SAVE ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
echo "($SPAWNSCRIPT)  $SCRIPT written"


# ###############################
# 5 km run
# ###############################
	      
GRID=5
SCRIPTNAME=${GRID}km_${CLIMATE}-spinup-${TYPE}.sh
INFILE=pism_Greenland_${GRID}km_v2_${TYPE}.nc
FILE=`basename $OUTFILE .nc`
REGRIDFILE=snap_${FILE}_-5000.nc
PISM_DATANAME=$INFILE
PISM_SAVE="-2000,-1000,-500,-100"
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

SCRIPT="do_${GRID}km_${CLIMATE}-spinup-${TYPE}.sh"
rm -f $SCRIPT
EXPERIMENT="${CLIMATE}-climate initialization with hotspot"

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
# 3 km run
# ###############################
	      
GRID=3
SCRIPTNAME=${GRID}km_${CLIMATE}-spinup-${TYPE}.sh
INFILE=pism_Greenland_${GRID}km_v2_${TYPE}.nc
FILE=`basename $OUTFILE .nc`
REGRIDFILE=snap_${FILE}_-1000.nc
PISM_DATANAME=$INFILE
PISM_SAVE="-500,-100"
DURA=1000
START=-1000
END=0

WALLTIME=96:00:00
NN=96
NODES=$(( $NN/$PROC_PER_NODE))

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROC_PER_NODE"
  MPIOUTLINE="#PBS -j oe"

SCRIPT="do_${GRID}km_${CLIMATE}-spinup-${TYPE}.sh"
rm -f $SCRIPT
EXPERIMENT="${CLIMATE}-climate initialization with hotspot"

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
# 2 km run
# ###############################
	      
GRID=2
SCRIPTNAME=${GRID}km_${CLIMATE}-spinup-${TYPE}.sh
INFILE=pism_Greenland_${GRID}km_v2_${TYPE}.nc
FILE=`basename $OUTFILE .nc`
REGRIDFILE=snap_${FILE}_-1000.nc
PISM_DATANAME=$INFILE
PISM_SAVE="-100"
DURA=500
START=-500
END=0

WALLTIME=96:00:00
NN=128
NODES=$(( $NN/$PROC_PER_NODE))

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROC_PER_NODE"
  MPIOUTLINE="#PBS -j oe"

SCRIPT="do_${GRID}km_${CLIMATE}-spinup-${TYPE}.sh"
rm -f $SCRIPT
EXPERIMENT="${CLIMATE}-climate initialization with hotspot"

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
