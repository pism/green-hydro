#!/bin/bash

# Copyright (C) 2014 Andy Aschwanden and Ed Bueler

set -e  # exit on error

#  creates spinup scripts using grid sequencing.
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

VERSION=1.2
CLIMLIST=(const, paleo)
TYPELIST=(ctrl, old_bed, 970mW_hs, jak_1985)
GRIDLIST="{36000, 18000, 9000, 4500, 3600, 1800, 1500, 1200, 900}"
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

if [ -n "${PISM_PROCS_PER_NODE:+1}" ] ; then  # check if env var is already set
    PROCS_PER_NODE=$PISM_PROCS_PER_NODE
else
    PROCS_PER_NODE=4
fi

if [ -n "${PISM_QUEUE:+1}" ] ; then  # check if env var is already set
    QUEUE=$PISM_QUEUE
else
    QUEUE=standard_4
fi

if [ -n "${PISM_WALLTIME:+1}" ] ; then  # check if env var is already set
    WALLTIME=$PISM_WALLTIME
else
    WALLTIME=16:00:00
fi

# set output format:
#  $ export PISM_OFORMAT="netcdf4_parallel "
if [ -n "${PISM_OFORMAT:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME                      PISM_OFORMAT = $PISM_OFORMAT  (already set)"
else
  PISM_OFORMAT="netcdf3"
  echo "$SCRIPTNAME                      PISM_OFORMAT = $PISM_OFORMAT"
fi
OFORMAT=$PISM_OFORMAT

# first arg is number of processes
NN="$1"

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
elif [ "$2" = "1500" ]; then
    GRID=$2
elif [ "$2" = "1200" ]; then
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
elif [ "$3" = "paleo" ]; then
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

SCRIPTNAME=${CLIMATE}-spinup-${TYPE}.sh
export PISM_EXPERIMENT=$EXPERIMENT
export PISM_TITLE="Greenland Parameter Study"


INFILE=pism_Greenland_${GRID}m_mcb_jpl_v${VERSION}_${TYPE}.nc
PISM_DATANAME=$INFILE
DURA=100000
START=-125000
END=-25000
MKA=$(($END/-1000))

NODES=$(( $NN/$PROCS_PER_NODE))

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROCS_PER_NODE"
  MPIOUTLINE="#PBS -j oe"

SCRIPT="do_g${GRID}m_${CLIMATE}-spinup-${TYPE}_v${VERSION}.sh"
rm -f $SCRIPT
EXPERIMENT="${DURAKA}ka ${CLIMATE}-climate initialization $TYPE"

OUTFILE=g${GRID}m_m${MKA}ka_${CLIMATE}_${TYPE}_v${VERSION}.nc

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
# refinement path 18000->9000->4500->3600->1800->900m are being written to the 'do' script.
# For example on the 9000m grid the first run from -125ka to -25ka is not done.
# The second 'if' statment makes sure the appropriate file is chosen for regridding.
# I wish I knew a cleaner way to achieve this in bash.

 
if [ $GRID == "18000" ]; then      
    cmd="PISM_DO="" PARAM_CALVING=ocean_kill PISM_OFORMAT=$OFORMAT STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME  PISM_CONFIG=spinup_config.nc ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
    echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
else
    echo "# not starting from -125ka" >> $SCRIPT
fi
echo >> $SCRIPT

if [ $GRID == "9000" ]; then
    REGRIDFILE=g18000m_m${MKA}ka_${CLIMATE}_${TYPE}_v${VERSION}.nc
else
    REGRIDFILE=$OUTFILE
fi

DURA=20000
START=-25000
END=-5000
MKA=$(($END/-1000))

OUTFILE=g${GRID}m_m${MKA}ka_${CLIMATE}_${TYPE}_v${VERSION}.nc

if [[ ($GRID == "18000") || ($GRID == "9000") ]]; then      
    cmd="PISM_DO="" PARAM_CALVING=ocean_kill PISM_OFORMAT=$OFORMAT STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME REGRIDFILE=$REGRIDFILE PARAM_SIAE=3 PARAM_PPQ=0.25 PISM_CONFIG=spinup_config.nc ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
    echo "$cmd 2>&1 | tee job_a.\${PBS_JOBID}" >> $SCRIPT
else
    echo "# not starting from -25ka" >> $SCRIPT
fi
echo >> $SCRIPT


if [ $GRID == "4500" ]; then
    REGRIDFILE=g9000m_m${MKA}ka_${CLIMATE}_${TYPE}_v${VERSION}.nc
else
    REGRIDFILE=$OUTFILE
fi

DURA=4000
START=-5000
END=-1000
MKA=$(($END/-1000))


OUTFILE=g${GRID}m_m${MKA}ka_${CLIMATE}_${TYPE}_v${VERSION}.nc
      
if [[ ($GRID == "18000") || ($GRID == "9000") || ($GRID == "4500") ]]; then      
    cmd="PISM_DO="" PARAM_CALVING=ocean_kill PISM_OFORMAT=$OFORMAT STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME REGRIDFILE=$REGRIDFILE PARAM_SIAE=3 PARAM_PPQ=0.25 PARAM_FTT="foo" PISM_CONFIG=spinup_config.nc ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
    echo "$cmd 2>&1 | tee job_b.\${PBS_JOBID}" >> $SCRIPT
else
    echo "# not starting from -5ka" >> $SCRIPT
fi
echo >> $SCRIPT

if [ $GRID == "3600" ]; then
    REGRIDFILE=g4500m_m${MKA}ka_${CLIMATE}_${TYPE}_v${VERSION}.nc
else
    REGRIDFILE=$OUTFILE
fi


DURA=500
START=-1000
END=-500
MA=$(($END/-1))


OUTFILE=g${GRID}m_m${MA}a_${CLIMATE}_${TYPE}_v${VERSION}.nc

if [[ ($GRID == "18000") || ($GRID == "9000") || ($GRID == "4500") || ($GRID == "3600") ]]; then      
    cmd="PISM_DO="" PARAM_CALVING=ocean_kill PISM_OFORMAT=$OFORMAT STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME REGRIDFILE=$REGRIDFILE PARAM_SIAE=3 PARAM_PPQ=0.25PARAM_SIAE=3 PARAM_PPQ=0.25 PARAM_FTT="foo" PISM_CONFIG=spinup_config.nc ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
    echo "$cmd 2>&1 | tee job_c.\${PBS_JOBID}" >> $SCRIPT
else
    echo "# not starting from -1ka" >> $SCRIPT
fi
echo >> $SCRIPT

if [ $GRID == "1800" ]; then
    REGRIDFILE=g3600m_m${MA}a_${CLIMATE}_${TYPE}_v${VERSION}.nc
else
    REGRIDFILE=$OUTFILE
fi

DURA=200
START=-500
END=-300
MA=$(($END/-1))


OUTFILE=g${GRID}m_m${MA}a_${CLIMATE}_${TYPE}_v${VERSION}.nc
      
if [[ ($GRID == "18000") || ($GRID == "9000") || ($GRID == "4500") || ($GRID == "3600") || ($GRID == "1800") ]]; then      
    cmd="PISM_DO="" PARAM_CALVING=ocean_kill PISM_OFORMAT=$OFORMAT STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME REGRIDFILE=$REGRIDFILE PARAM_SIAE=3 PARAM_PPQ=0.25 PARAM_FTT="foo" EXSTEP=20 PISM_CONFIG=spinup_config.nc ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
    echo "$cmd 2>&1 | tee job_d.\${PBS_JOBID}" >> $SCRIPT
else
    echo "# not starting from -500a" >> $SCRIPT
fi
echo >> $SCRIPT

if [ $GRID == "1500" ]; then
    REGRIDFILE=g1800m_m${MA}a_${CLIMATE}_${TYPE}_v${VERSION}.nc
else
    REGRIDFILE=$OUTFILE
fi

DURA=100
START=-300
END=-200
MA=$(($END/-1))


OUTFILE=g${GRID}m_m${MA}a_${CLIMATE}_${TYPE}_v${VERSION}.nc
      
if [[ ($GRID == "18000") || ($GRID == "9000") || ($GRID == "4500") || ($GRID == "3600") || ($GRID == "1800")  || ($GRID == "1500") ]]; then      
    cmd="PISM_DO="" PARAM_CALVING=ocean_kill PISM_OFORMAT=$OFORMAT STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME REGRIDFILE=$REGRIDFILE PARAM_SIAE=3 PARAM_PPQ=0.25 PARAM_FTT="foo" PISM_CONFIG=spinup_config.nc ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
    echo "$cmd 2>&1 | tee job_e.\${PBS_JOBID}" >> $SCRIPT
else
    echo "# not starting from -300a" >> $SCRIPT
fi
echo >> $SCRIPT

if [ $GRID == "1200" ]; then
    REGRIDFILE=g1500m_m${MA}a_${CLIMATE}_${TYPE}_v${VERSION}.nc
else
    REGRIDFILE=$OUTFILE
fi

DURA=100
START=-200
END=-100
MA=$(($END/-1))


OUTFILE=g${GRID}m_m${MA}a_${CLIMATE}_${TYPE}_v${VERSION}.nc
      
if [[ ($GRID == "18000") || ($GRID == "9000") || ($GRID == "4500") || ($GRID == "3600") || ($GRID == "1800")  || ($GRID == "1500") || ($GRID == "1200") ]]; then      
    cmd="PISM_DO="" PARAM_CALVING=ocean_kill PISM_OFORMAT=$OFORMAT STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME REGRIDFILE=$REGRIDFILE PARAM_SIAE=3 PARAM_PPQ=0.25 PARAM_FTT="foo" EXSTEP=10  PISM_CONFIG=spinup_config.nc ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
    echo "$cmd 2>&1 | tee job_f.\${PBS_JOBID}" >> $SCRIPT
else
    echo "# not starting from -200a" >> $SCRIPT
fi
echo >> $SCRIPT

DURA=100
START=-100
END=0

if [ $GRID == "900" ]; then
    REGRIDFILE=g1200m_m${MA}a_${CLIMATE}_${TYPE}_v${VERSION}.nc
else
    REGRIDFILE=$OUTFILE
fi

OUTFILE=g${GRID}m_0_${CLIMATE}_${TYPE}_v${VERSION}.nc
      
cmd="PISM_DO="" PARAM_CALVING=ocean_kill PISM_OFORMAT=$OFORMAT STARTEND=$START,$END PISM_DATANAME=$PISM_DATANAME REGRIDFILE=$REGRIDFILE PARAM_SIAE=3 PARAM_PPQ=0.25 PARAM_FTT="foo" EXSTEP=10 PISM_CONFIG=spinup_config.nc ./run.sh $NN $CLIMATE $DURA $GRID hybrid null $OUTFILE $INFILE"
echo "$cmd 2>&1 | tee job_g.\${PBS_JOBID}" >> $SCRIPT
echo >> $SCRIPT


echo "($SPAWNSCRIPT)  $SCRIPT written"
