#!/bin/bash

# Copyright (C) 2014 Andy Aschwanden and Ed Bueler

set -e  # exit on error

#  creates a bunch of scripts, each with NN processors, for a parameter study
#  scripts are suitable for PBS job scheduler
#  (see  http://www.adaptivecomputing.com/products/open-source/torque/)
#
#  usage: to use NN=8 processors, 2 4-core nodes, and duration 4:00:00,
#     $ export PISM_WALLTIME=4:00:00
#     $ export PISM_NODES=2
#     $ ./ 8
#  then, assuming you like the resulting scripts:
#     $ qsub do-climate-spinup-hotspot.sh      ### <--- REALLY SUBMITS using qsub


set -e # exit on error
CLIMATE=paleo
SCRIPTNAME=${CLIMATE}-spinup-hotspot.sh

NN=32  # default number of processors
if [ $# -gt 0 ] ; then  # if user says "paramspawn.sh 8" then NN = 8
  NN="$1"
fi

# set wallclock time
if [ -n "${PISM_WALLTIME:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME                    PISM_WALLTIME = $PISM_WALLTIME  (already set)"
else
  PISM_WALLTIME=72:00:00
  echo "$SCRIPTNAME                     PISM_WALLTIME = $PISM_WALLTIME"
fi
WALLTIME=$PISM_WALLTIME

# set number of nodes
if [ -n "${PISM_NODES:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME                    PISM_NODES = $PISM_NODES  (already set)"
else
  PISM_NODES=8
  echo "$SCRIPTNAME                     PISM_NODES = $PISM_NODES"
fi
NODES=$PISM_NODES

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q standard_4"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=4"
  MPIOUTLINE="#PBS -j oe"

GRID=20
INFILE=pism_Greenland_${GRID}km_v2_hotspot.nc
PISM_DATANAME=$INFILE
DURA=125000
START=-125000
FTTTIME=-5000
END=0

SCRIPT="do_${CLIMATE}-spinup-hotspot.sh"
rm -f $SCRIPT
EXPERIMENT="${DURAKA}ka ${CLIMATE}-climate initialization with hotspot"
FTTTIMEMKA=$(($FTTTIME/-1000))

OUTFILE=g${GRID}km_m${FTTTIMEMKA}ka_${CLIMATE}_hotspot.nc

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

export PISM_EXPERIMENT=$EXPERIMENT
export PISM_TITLE="Greenland Parameter Study"
      
cmd="PISM_DO="" STARTEND=$START,$FTTTIME PISM_DATANAME=$PISM_DATANAME  ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT

INFILE=$OUTFILE
OUTFILE=g${GRID}km_0_${CLIMATE}_hotspot.nc

echo >> $SCRIPT
cmd="PISM_DO="" STARTEND=$FTTTIME,$END PISM_DATANAME=$PISM_DATANAME PARAM_FTT="foo" ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
	      
echo "($SPAWNSCRIPT)  $SCRIPT written"


