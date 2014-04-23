#!/bin/bash

# Copyright (C) 2014 Andy Aschwanden and Ed Bueler

set -e  # exit on error

#  creates spinup scripts using grid sequencing 20->10->5->2.5->2->1km.
#  scripts are suitable for PBS job scheduler
#  (see  http://www.adaptivecomputing.com/products/open-source/torque/)
#
#     $ ./spinup.sh 16 20 paleo 970mW_hs    ## do paleo-climate spinup with 970mW hotspot on 20km grid
#     and 16 processors
#     or
#     $ ./spinup.sh 128 1 const ctrl    ## do constant-climate ctrl spinup on 1km and 128 processors
#     or you can also choose nodes and walltime to do runs on different queues on pacman and fish
#     $ PISM_WALLTIME=12:00:00 PISM_QUEUE=standard_16 PISM_PROC_PER_NODE=16 ./spinup.sh 16 20 const ctrl
#  then, assuming you like the resulting scripts:
#     $ qsub do-climate-spinup.sh      ### <--- REALLY SUBMITS using qsub
#
#  For high-resolution (1km < GRID < 5km) runs 'PISM_OFORMAT=pnetcdf' is recommended,
#  and for GRID = 1km, make sure to use 'PISM_OFORMAT=netcdf4_parallel' (slow) or 
#  'PISM_OFORMAT=quilt' (fast, but needs messy postprocessing)
#

set -e # exit on error

CLIMLIST=(const, paleo)
TYPELIST=(ctrl, 970mW_hs)
GRIDLIST=(20 10 5 2.5 2 1)
if [ $# -lt 2 ] ; then
  echo "spinup.sh ERROR: needs 4 positional arguments ... ENDING NOW"
  echo
  echo "usage:"
  echo
  echo "    spinup.sh PROCS GRID CLIMATE TYPE"
  echo
  echo "  where:"
  echo "    PROCS     = 1,2,3,... is number of MPI processes"
  echo "    GRID      in (${GRIDLIST[@]})"
  echo "    CLIMATE   in (${CLIMLIST[@]})"
  echo "    TYPE      in (${TYPELIST[@]})"
  echo
  echo
  exit
fi

if [ -n "${PISM_PROC_PER_NODE:+1}" ] ; then  # check if env var is already set
    PROC_PER_NODE=$PISM_PROC_PER_NODE
else
    PROC_PER_NODE=4
fi

if [ -n "${PISM_QUEUE:+1}" ] ; then  # check if env var is already set
    QUEUE=$PISM_QUEUE
else
    QUEUE=standard_4
fi

if [ -n "${PISM_WALLTIME:+1}" ] ; then  # check if env var is already set
    WALLTIME=$PISM_WALLTIME
else
    WALLTIME=12:00:00
fi

# first arg is number of processes
NN="$1"

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
  echo "invalid first argument; must be in (${GRIDLIST[@]})"
  exit
fi

# set CLIMATE from argument 3
if [ "$3" = "const" ]; then
    CLIMATE=$3
elif [ "$3" = "paleo" ]; then
    CLIMATE=$3
else
  echo "invalid second argument; must be in (${CLIMLIST[@]})"
  exit
fi

# set TYPE from argument 4
if [ "$4" = "ctrl" ]; then
    TYPE=$4
elif [ "$4" = "970mW_hs" ]; then
    TYPE=$4
else
  echo "invalid third argument; must be in (${TYPELIST[@]})"
  exit
fi

SCRIPTNAME=${CLIMATE}-spinup-${TYPE}.sh
export PISM_EXPERIMENT=$EXPERIMENT
export PISM_TITLE="Greenland Parameter Study"


INFILE=pism_Greenland_${GRID}km_v2_${TYPE}.nc
PISM_DATANAME=$INFILE
DURA=100000
START=-125000
END=-25000
MKA=$(($END/-1000))

NODES=$(( $NN/$PROC_PER_NODE))

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROC_PER_NODE"
  MPIOUTLINE="#PBS -j oe"

SCRIPT="do_${GRID}km_${CLIMATE}-spinup-${TYPE}.sh"
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

# NOTE
#
# The first 'if' statement ensure that only runs that are on the grid
# refinement path 20->10->5->2.5->2->1km are being written to the 'do' script.
# For example on the 10km grid the first run from -125ka to -25ka is not done.
# The second 'if' statment makes sure the appropriate file is chosen for regridding.
# I wish I knew a cleaner way to achieve this in bash.

 
if [ $GRID == "20" ]; then      
    cmd="PISM_DO="" STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME  ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
    echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
else
    echo "# not starting from -125ka" >> $SCRIPT
fi
echo >> $SCRIPT

if [ $GRID == "10" ]; then
    REGRIDFILE=g20km_m${MKA}ka_${CLIMATE}_${TYPE}.nc
else
    REGRIDFILE=$OUTFILE
fi

DURA=20000
START=-25000
END=-5000
MKA=$(($END/-1000))


OUTFILE=g${GRID}km_m${MKA}ka_${CLIMATE}_${TYPE}.nc

if [[ ($GRID == "20") || ($GRID == "10") ]]; then      
    cmd="PISM_DO="" STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME REGRIDFILE=$REGRIDFILE ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
    echo "$cmd 2>&1 | tee job_a.\${PBS_JOBID}" >> $SCRIPT
else
    echo "# not starting from -25ka" >> $SCRIPT
fi
echo >> $SCRIPT


if [ $GRID == "5" ]; then
    REGRIDFILE=g10km_m${MKA}ka_${CLIMATE}_${TYPE}.nc
else
    REGRIDFILE=$OUTFILE
fi

DURA=4000
START=-5000
END=-1000
MKA=$(($END/-1000))


OUTFILE=g${GRID}km_m${MKA}ka_${CLIMATE}_${TYPE}.nc
      
if [[ ($GRID == "20") || ($GRID == "10") || ($GRID == "5") ]]; then      
    cmd="PISM_DO="" STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME REGRIDFILE=$REGRIDFILE PARAM_FTT="foo" ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
    echo "$cmd 2>&1 | tee job_b.\${PBS_JOBID}" >> $SCRIPT
else
    echo "# not starting from -5ka" >> $SCRIPT
fi
echo >> $SCRIPT

if [ $GRID == "2.5" ]; then
    REGRIDFILE=g5km_m${MKA}ka_${CLIMATE}_${TYPE}.nc
else
    REGRIDFILE=$OUTFILE
fi


DURA=500
START=-1000
END=-500
MA=$(($END/-1))


OUTFILE=g${GRID}km_m${MA}a_${CLIMATE}_${TYPE}.nc

if [[ ($GRID == "20") || ($GRID == "10") || ($GRID == "5") || ($GRID == "2.5") ]]; then      
    cmd="PISM_DO="" STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME REGRIDFILE=$REGRIDFILE PARAM_FTT="foo" ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
    echo "$cmd 2>&1 | tee job_c.\${PBS_JOBID}" >> $SCRIPT
else
    echo "# not starting from -1ka" >> $SCRIPT
fi
echo >> $SCRIPT

if [ $GRID == "2" ]; then
    REGRIDFILE=g2.5km_m${MA}a_${CLIMATE}_${TYPE}.nc
else
    REGRIDFILE=$OUTFILE
fi

DURA=400
START=-500
END=-100
MA=$(($END/-1))


OUTFILE=g${GRID}km_m${MA}a_${CLIMATE}_${TYPE}.nc
      
if [[ ($GRID == "20") || ($GRID == "10") || ($GRID == "5") || ($GRID == "2.5") || ($GRID == "2") ]]; then      
    cmd="PISM_DO="" STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME REGRIDFILE=$REGRIDFILE PARAM_FTT="foo" ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
    echo "$cmd 2>&1 | tee job_d.\${PBS_JOBID}" >> $SCRIPT
else
    echo "# not starting from -500a" >> $SCRIPT
fi
echo >> $SCRIPT

DURA=100
START=-100
END=0

if [ $GRID == "1" ]; then
    REGRIDFILE=g2km_m${MA}a_${CLIMATE}_${TYPE}.nc
else
    REGRIDFILE=$OUTFILE
fi

OUTFILE=g${GRID}km_0_${CLIMATE}_${TYPE}.nc
      
cmd="PISM_DO="" STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME REGRIDFILE=$REGRIDFILE PARAM_FTT="foo" ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
echo "$cmd 2>&1 | tee job_e.\${PBS_JOBID}" >> $SCRIPT
echo >> $SCRIPT


echo "($SPAWNSCRIPT)  $SCRIPT written"
