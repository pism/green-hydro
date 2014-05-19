#!/bin/bash

# Copyright (C) 2009-2014 Ed Bueler and Andy Aschwanden

#  creates a bunch of scripts, each with NN processors, for a parameter study
#  scripts are suitable for PBS job scheduler
#  (see  http://www.adaptivecomputing.com/products/open-source/torque/)
#
#  usage: to use NN=8 processors, 2 4-core nodes, and duration 4:00:00,
#     $ export PISM_WALLTIME=4:00:00
#     $ export PISM_PROCS_PER_NODE=4
#     $ export PISM_QUEUE=standard_4


set -e # exit on error
SCRIPTNAME=hindcast.sh

CLIMLIST=(forcing)
GRIDLIST=(20 10 5 2.5 2 1)
if [ $# -lt 4 ] ; then
  echo "paramspawn.sh ERROR: needs 4 positional arguments ... ENDING NOW"
  echo
  echo "usage:"
  echo
  echo "    paramspawn.sh NN GRID CLIMATE TYPE REGRIDFILE"
  echo
  echo "  where:"
  echo "    PROCSS       = 1,2,3,... is number of MPI processes"
  echo "    GRID      in (${GRIDLIST[@]})"
  echo "    CLIMATE   in (${CLIMLIST[@]})"
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
  PISM_WALLTIME=12:00:00
  echo "$SCRIPTNAME                     PISM_WALLTIME = $PISM_WALLTIME"
fi
WALLTIME=$PISM_WALLTIME

if [ -n "${PISM_PROCS_PER_NODE:+1}" ] ; then  # check if env var is already set
    PISM_PROCS_PER_NODE=$PISM_PROCS_PER_NODE
else
    PISM_PROCS_PER_NODE=4
fi
PROCS_PER_NODE=$PISM_PROCS_PER_NODE

if [ -n "${PISM_QUEUE:+1}" ] ; then  # check if env var is already set
    PISM_QUEUE=$PISM_QUEUE
else
    PISM_QUEUE=standard_4
fi
QUEUE=$PISM_QUEUE

# set output format:
#  $ export PISM_OFORMAT="netcdf4_parallel "
if [ -n "${PISM_OFORMAT:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME                      PISM_OFORMAT = $PISM_OFORMAT  (already set)"
else
  PISM_OFORMAT="netcdf3"
  echo "$SCRIPTNAME                      PISM_OFORMAT = $PISM_OFORMAT"
fi
OFORMAT=$PISM_OFORMAT


# set GRID from argument 2
if [ "$2" = "20" ]; then
    GRID=$2
elif [ "$2" = "10" ]; then
    GRID=$2
elif [ "$2" = "5" ]; then
    GRID=$2
elif [ "$2" = "2.5" ]; then
    GRID=$2
elif [ "$2" = "2" ]; then
    GRID=$2
elif [ "$2" = "1" ]; then
    GRID=$2
else
  echo "invalid second argument; must be in (${GRIDLIST[@]})"
  exit
fi

# set CLIMATE from argument 3
if [ "$3" = "forcing" ]; then
    CLIMATE=$3
else
  echo "invalid third argument; must be in (${CLIMLIST[@]})"
  exit
fi

# make this resolution dependent
PISM_BCFILE=RACMO_CLRUN_10KM_CON_MM_06.nc
STARTYEAR=1985
ENDYEAR=2012
PISM_TIMEFILE=time_${STARTYEAR}-${ENDYEAR}.nc
create_timeline.py -a ${STARTYEAR}-1-1 -e ${ENDYAR}-1-1 $PISM_TIMEFILE

TYPE=jak_1985

REGRIDFILE=$4
PISM_DATANAME=pism_Greenland_${GRID}km_v3_${TYPE}.nc
NODES=$(( $NN/$PROCS_PER_NODE))

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROCS_PER_NODE"
  MPIOUTLINE="#PBS -j oe"

# ########################################################
# set up hindcast
# ########################################################

HYDRO=null
E=1
PPQ=0.33
TEFO=0.02
PHILOW=5
PARAM_TTPHI="${PHILOW}.0,40.0,-700.0,700.0"
            
EXPERIMENT=hydro_${HYDRO}_${START}-${END}
SCRIPT=do_g${GRID}km_${EXPERIMENT}.sh
POST=do_g${GRID}km_${EXPERIMENT}_post.sh
PLOT=do_g${GRID}km_${EXPERIMENT}_plot.sh
rm -f $SCRIPT $$POST $PLOT

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

cmd="PISM_DO="" PISM_BCFILE=$PISM_BCFILE PISM_TIMEFILE=$PISM_TIMEFILE PISM_OFORMAT=$OFORMAT PISM_DATANAME=$PISM_DATANAME TSSTEP=daily EXSTEP=monthly SAVE=yearly   PARAM_SIAE=$E PARAM_PPQ=$PPQ PARAM_TEFO=$TEFO PARAM_TTPHI=$PARAM_TTPHI ./run.sh $NN $CLIMATE 30 $GRID hybrid $HYDRO $OUTFILE $INFILE"
echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT

echo >> $SCRIPT
echo "# $SCRIPT written"
echo
title="hindcast"
source run-postpro.sh
echo "## $POST written"
echo "### $PLOT written"
echo
echo

SUBMIT=submit_g${GRID}km_hindcast.sh
rm -f $SUBMIT
cat - > $SUBMIT <<EOF
$SHEBANGLINE
for FILE in do_g${GRID}km_${CLIMATE}_${TYPE}_*${HYDRO}.sh; do
  JOBID=\$(qsub \$FILE)
  fbname=\$(basename "\$FILE" .sh)
  POST=\${fbname}_post.sh
  ID=\$(qsub -W depend=afterok:\${JOBID} \$POST)
  PLOT=\${fbname}_plot.sh
  qsub -W depend=afterok:\${ID} \$PLOT
done
EOF

echo
echo
echo "Run $SUBMIT to submit all jobs to the scheduler"
echo
echo

