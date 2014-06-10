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
SCRIPTNAME=hydro_null_spawn.sh

CLIMLIST=(const, pdd)
TYPELIST=(ctrl, old_bed, 970mW_hs, jak_1985)
GRIDLIST=(18000 9000 4500 3600 1800 900)
if [ $# -lt 5 ] ; then
  echo "paramspawn.sh ERROR: needs 5 positional arguments ... ENDING NOW"
  echo
  echo "usage:"
  echo
  echo "    paramspawn.sh NN GRID CLIMATE TYPE REGRIDFILE"
  echo
  echo "  where:"
  echo "    PROCSS       = 1,2,3,... is number of MPI processes"
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
if [ "$2" = "18000" ]; then
    GRID=$2
elif [ "$2" = "9000" ]; then
    GRID=$2
elif [ "$2" = "4500" ]; then
    GRID=$2
elif [ "$2" = "3600" ]; then
    GRID=$2
elif [ "$2" = "1800" ]; then
    GRID=$2
elif [ "$2" = "900" ]; then
    GRID=$2
else
  echo "invalid second argument; must be in (${GRIDLIST[@]})"
  exit
fi

# set CLIMATE from argument 3
if [ "$3" = "const" ]; then
    CLIMATE=$3
elif [ "$3" = "pdd" ]; then
    CLIMATE=$3
else
  echo "invalid third argument; must be in (${CLIMLIST[@]})"
  exit
fi

# set TYPE from argument 4
if [ "$4" = "ctrl" ]; then
    TYPE=$4
elif [ "$4" = "old_bed" ]; then
    TYPE=$4
elif [ "$4" = "970mW_hs" ]; then
    TYPE=$4
elif [ "$4" = "jak_1985" ]; then
    TYPE=$4
else
  echo "invalid forth argument; must be in (${TYPELIST[@]})"
  exit
fi

REGRIDFILE=$5
PISM_DATANAME=pism_Greenland_${GRID}m_mcb_jpl_v1.1_${TYPE}.nc
DURA=100
NODES=$(( $NN/$PROCS_PER_NODE))

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROCS_PER_NODE"
  MPIOUTLINE="#PBS -j oe"

# ########################################################
# set up parameter sensitivity study: Shallow Ice Approximation
# ########################################################

for E in 1 2 3 ; do
    HYDRO=null
    
    EXPERIMENT=${CLIMATE}_${TYPE}_e_${E}_sia_hydro_${HYDRO}
    SCRIPT=do_g${GRID}m_${EXPERIMENT}.sh
    POST=${SCRIPT}_post.sh
    PLOT=${SCRIPT}_plot.sh
    rm -f $SCRIPT $$POST $PLOT
    
    OUTFILE=g${GRID}m_${EXPERIMENT}.nc
    
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

    cmd="PISM_DO="" PISM_OFORMAT=$OFORMAT REGRIDFILE=$REGRIDFILE PISM_DATANAME=$PISM_DATANAME TSSTEP=daily EXSTEP=yearly PARAM_FTT=foo REGRIDVARS=litho_temp,enthalpy,tillwat,bmelt,Href PARAM_SIAE=$E  ./run.sh $NN $CLIMATE $DURA $GRID sia $HYDRO $OUTFILE $INFILE"
    echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
    echo "($SPAWNSCRIPT)  $SCRIPT written"
    title="E=$E"
    source run-postpro.sh
    echo "## $POST written"
    echo "### $PLOT written"

done

SUBMIT=submit_g${GRID}m_${CLIMATE}_${TYPE}_sia_hydro_${HYDRO}.sh
rm -f $SUBMIT
cat - > $SUBMIT <<EOF
$SHEBANGLINE
for FILE in do_g${GRID}km_${CLIMATE}_${TYPE}_*sia_hydro_${HYDRO}.sh; do
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
