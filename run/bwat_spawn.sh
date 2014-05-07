#!/bin/bash

# Copyright (C) 2009-2014 Ed Bueler and Andy Aschwanden

#  creates a bunch of scripts, each with NN processors, for a parameter study
#  scripts are suitable for PBS job scheduler
#  (see  http://www.adaptivecomputing.com/products/open-source/torque/)
#
#  usage: to use NN=8 processors, 2 4-core nodes, and duration 4:00:00,
#     $ export PISM_WALLTIME=4:00:00
#     $ export PISM_NODES=2
#     $ ./paramspawn.sh 8 FIXME
#  then, assuming you like the resulting scripts:
#     $ ./paramsubmit.sh      ### <--- REALLY SUBMITS using qsub


set -e # exit on error
SCRIPTNAME=paramspawn.sh

CLIMLIST=(const, pdd)
TYPELIST=(ctrl, 970mW_hs)
GRIDLIST=(20 10 5 2.5 2 1)
if [ $# -lt 5 ] ; then
  echo "paramspawn.sh ERROR: needs 5 positional arguments ... ENDING NOW"
  echo
  echo "usage:"
  echo
  echo "    paramspawn.sh NN GRID CLIMATE TYPE REGRIDFILE"
  echo
  echo "  where:"
  echo "    PROCS       = 1,2,3,... is number of MPI processes"
  echo "    GRID      in (${GRIDLIST[@]})"
  echo "    CLIMATE   in (${CLIMLIST[@]})"
  echo "    TYPE      in (${TYPELIST[@]})"
  echo "    REGRIDFILE  name of regrid file"
  echo
  echo
  exit
fi

NN=64  # default number of processors
if [ $# -gt 0 ] ; then  # if user says "paramspawn.sh 8" then NN = 8
  NN="$1"
fi

# set wallclock time
if [ -n "${PISM_WALLTIME:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME                    PISM_WALLTIME = $PISM_WALLTIME  (already set)"
else
  PISM_WALLTIME=48:00:00
  echo "$SCRIPTNAME                     PISM_WALLTIME = $PISM_WALLTIME"
fi
WALLTIME=$PISM_WALLTIME

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

GRID=$2
CLIMATE=$3
TYPE=$4
REGRIDFILE=$5
PISM_DATANAME=pism_Greenland_${GRID}km_v3_${TYPE}.nc
DURA=100
NODES=$(( $NN/$PROC_PER_NODE))

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROC_PER_NODE"
  MPIOUTLINE="#PBS -j oe"



# ########################################################
# set up parameter sensitivity study: distributed
# ########################################################

for PPQ in 0.25; do
  for TEFO in 0.02; do
      for PHILOW in 5; do
          PARAM_TTPHI="${PHILOW}.0,40.0,-300.0,700.0"
          for RATE in 1e-6; do
	      for PROP in 100 1000 ; do
                  for OPEN in 0.5; do
                      for CLOSE in 0.04; do
                          for COND in 0.0001 0.001 0.01 0.1; do
                              HYDRO=distributed
                              
	                      EXPERIMENT=${CLIMATE}_${TYPE}_ppq_${PPQ}_tefo_${TEFO}_philow_${PHILOW}_rate_${RATE}_prop_${PROP}_open_${OPEN}_close_${CLOSE}_cond_${COND}_hydro_${HYDRO}_bwatfrac0.01
                              SCRIPT=do_${EXPERIMENT}.sh
	                      rm -f $SCRIPT

	                      OUTFILE=g${GRID}km_${EXPERIMENT}.nc

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
	                      cmd="PISM_DO="" REGRIDFILE=$REGRIDFILE PISM_DATANAME=$PISM_DATANAME TSSTEP=daily EXSTEP=yearly PARAM_PPQ=$PPQ PARAM_TEFO=$TEFO PARAM_TTPHI=$PARAM_TTPHI PARAM_TWRATE=$RATE PARAM_TWPROP=$PROP PARAM_COND=$COND PARAM_OPEN=$OPEN PARAM_CLOSE=$CLOSE PARAM_ADDBWAT=foo ./run.sh $NN $CLIMATE $DURA $GRID hybrid $HYDRO $OUTFILE"
	                      echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT

	                      echo "($SPAWNSCRIPT)  $SCRIPT written"

                          done
                      done
                  done
	      done
          done
      done

      HYDRO=null

      EXPERIMENT=${CLIMATE}_${TYPE}_ppq_${PPQ}_tefo_${TEFO}_hydro_${HYDRO}
      SCRIPT=do_${EXPERIMENT}.sh
      rm -f $SCRIPT
      OUTFILE=g${GRID}km_${EXPERIMENT}.nc

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
      
      cmd="PISM_DO="" REGRIDFILE=$REGRIDFILE PISM_DATANAME=$PISM_DATANAME TSSTEP=daily EXSTEP=yearly PARAM_PPQ=$PPQ PARAM_TEFO=$TEFO ./run.sh $NN const $DURA $GRID hybrid $HYDRO $OUTFILE $INFILE"
      echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
      
      echo "($SPAWNSCRIPT)  $SCRIPT written"

  done
done

echo
echo "($SPAWNSCRIPT)  use paramsubmit.sh to submit the scripts"
echo

