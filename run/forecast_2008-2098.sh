#!/bin/bash

# Copyright (C) 2009-2015 Ed Bueler and Andy Aschwanden

#  creates a bunch of scripts, each with NN processors, for a parameter study
#  scripts are suitable for PBS job scheduler
#  (see  http://www.adaptivecomputing.com/products/open-source/torque/)
#
#  usage: to use NN=8 processors, 2 4-core nodes, and duration 4:00:00,
#     $ export PISM_WALLTIME=4:00:00
#     $ export PISM_PROCS_PER_NODE=4
#     $ export PISM_QUEUE=standard_4


set -e # exit on error
SCRIPTNAME=forecast
CLIMATE=forcing
TYPELIST=(ctrl, old_bed, 970mW_hs, jak_1985)
CALVINGLIST=(float_kill, ocean_kill, eigen_calving)
GRIDLIST=(18000 9000 4500 3600 1800 1500 1200 900)
if [ $# -lt 4 ] ; then
  echo "paramspawn.sh ERROR: needs 5 positional arguments ... ENDING NOW"
  echo
  echo "usage:"
  echo
  echo "    paramspawn.sh NN GRID TYPE CALVING REGRIDFILE"
  echo
  echo "  where:"
  echo "    PROCSS       = 1,2,3,... is number of MPI processes"
  echo "    GRID      in (${GRIDLIST[@]})"
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

# set output format:
#  $ export PISM_OSIZE="netcdf4_parallel "
if [ -n "${PISM_OSIZE:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME                      PISM_OSIZE = $PISM_OSIZE  (already set)"
else
  PISM_OSIZE="big"
  echo "$SCRIPTNAME                      PISM_OSIZE = $PISM_OSIZE"
fi
OSIZE=$PISM_OSIZE

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
elif [ "$2" = "600" ]; then
    GRID=$2
elif [ "$2" = "450" ]; then
    GRID=$2
else
  echo "invalid second argument; must be in (${GRIDLIST[@]})"
  exit
fi


# set TYPE from argument 3
if [ "$3" = "ctrl" ]; then
    TYPE=$3
elif [ "$3" = "old_bed" ]; then
    TYPE=$3
elif [ "$3" = "ba01_bed" ]; then
    TYPE=$3
elif [ "$3" = "970mW_hs" ]; then
    TYPE=$3
elif [ "$3" = "jak_1985" ]; then
    TYPE=$3
else
  echo "invalid forth argument; must be in (${TYPELIST[@]})"
  exit
fi

# set CALVING from argument 4
if [ "$4" = "float_kill" ]; then
    CALVING=$4
elif [ "$4" = "ocean_kill" ]; then
    CALVING=$4
elif [ "$4" = "eigen_calving" ]; then
    CALVING=$4
else
  echo "invalid forth argument; must be in (${CALVINGLIST[@]})"
  exit
fi

STARTYEAR=2008
ENDYEAR=2099
PISM_TIMEFILE=time_${STARTYEAR}-${ENDYEAR}.nc
create_timeline.py -a ${STARTYEAR}-1-1 -e ${ENDYEAR}-1-1 $PISM_TIMEFILE

EXSTEP=yearly
SAVESTEP=yearly

REGRIDFILE=$5
PISM_BCFILE=RACMO_HadGEM2_RCP45_10000M_BIL_MM_EPSG314.nc
PISM_CONST_BCFILE=RACMO_CLRUN_10000M_BIL_MM_EPSG314_1960-1990_baseline.nc
VERSION=1.2
PISM_DATANAME=pism_Greenland_${GRID}m_mcb_jpl_v${VERSION}_${TYPE}.nc
NODES=$(( $NN/$PROCS_PER_NODE))
TYPE=${TYPE}_v${VERSION}

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROCS_PER_NODE"
  MPIOUTLINE="#PBS -j oe"

# ########################################################
# set up forecast
# ########################################################

HYDRO=null
philow=5
for E in 1.25; do
    for PPQ in 0.6 0.7; do
        for TEFO in 0.02; do
	    for SSA_N in 3.25; do
                PARAM_TTPHI="${philow}.0,40.0,-700.0,700.0"
                EXPERIMENT=${CLIMATE}_${TYPE}_${STARTYEAR}_${ENDYEAR}_e_${E}_ppq_${PPQ}_tefo_${TEFO}_ssa_n_${SSA_N}_philow_${philow}_hydro_${HYDRO}_calving_${CALVING}_CONST
                SCRIPT=forecast_g${GRID}m_${EXPERIMENT}.sh
                rm -f $SCRIPT
                
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
                export PISM_TITLE="Greenland Prognostic Study"
                
                cmd="PISM_DO="" PARAM_CALVING=$CALVING REGRIDFILE=$REGRIDFILE PISM_BCFILE=$PISM_CONST_BCFILE PISM_TIMEFILE=$PISM_TIMEFILE PISM_OFORMAT=$OFORMAT PISM_DATANAME=$PISM_DATANAME TSSTEP=daily EXSTEP=$EXSTEP SAVE=$SAVESTEP REGRIDVARS=litho_temp,enthalpy,tillwat,bmelt,Href,thk PARAM_SIAE=$E PARAM_PPQ=$PPQ PARAM_TEFO=$TEFO PARAM_TTPHI=$PARAM_TTPHI PARAM_SSA_N=$SSA_N ./run.sh $NN $CLIMATE 30 $GRID hybrid $HYDRO $OUTFILE $INFILE"
                echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
                
                echo >> $SCRIPT
                echo "# $SCRIPT written"
                echo

                EXPERIMENT=${CLIMATE}_${TYPE}_${STARTYEAR}_${ENDYEAR}_e_${E}_ppq_${PPQ}_tefo_${TEFO}_ssa_n_${SSA_N}_philow_${philow}_hydro_${HYDRO}_calving_${CALVING}_CTRL
                SCRIPT=forecast_g${GRID}m_${EXPERIMENT}.sh
                rm -f $SCRIPT
                
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
                export PISM_TITLE="Greenland Prognostic Study"
                
                cmd="PISM_DO="" PARAM_CALVING=$CALVING REGRIDFILE=$REGRIDFILE PISM_BCFILE=$PISM_BCFILE PISM_TIMEFILE=$PISM_TIMEFILE PISM_OFORMAT=$OFORMAT PISM_DATANAME=$PISM_DATANAME TSSTEP=daily EXSTEP=$EXSTEP SAVE=$SAVESTEP REGRIDVARS=litho_temp,enthalpy,tillwat,bmelt,Href,thk PARAM_SIAE=$E PARAM_PPQ=$PPQ PARAM_TEFO=$TEFO PARAM_TTPHI=$PARAM_TTPHI PARAM_SSA_N=$SSA_N ./run.sh $NN $CLIMATE 30 $GRID hybrid $HYDRO $OUTFILE $INFILE"
                echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
                
                echo >> $SCRIPT
                echo "# $SCRIPT written"
                echo


                EXPERIMENT=${CLIMATE}_${TYPE}_${STARTYEAR}_${ENDYEAR}_e_${E}_ppq_${PPQ}_tefo_${TEFO}_ssa_n_${SSA_N}_philow_${philow}_hydro_${HYDRO}_calving_${CALVING}_E1
                SCRIPT=forecast_g${GRID}m_${EXPERIMENT}.sh
                rm -f $SCRIPT
                
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
                export PISM_TITLE="Greenland Prognostic Study"
                
                cmd="PISM_DO="" PARAM_CALVING=$CALVING PISM_PARAM='-sliding_scale_factor_reduces_tauc 2' REGRIDFILE=$REGRIDFILE PISM_BCFILE=$PISM_BCFILE PISM_TIMEFILE=$PISM_TIMEFILE PISM_OFORMAT=$OFORMAT PISM_DATANAME=$PISM_DATANAME TSSTEP=daily EXSTEP=yearly SAVE=yearly REGRIDVARS=litho_temp,enthalpy,tillwat,bmelt,Href,thk PARAM_SIAE=$E PARAM_PPQ=$PPQ PARAM_TEFO=$TEFO PARAM_TTPHI=$PARAM_TTPHI PARAM_SSA_N=$SSA_N ./run.sh $NN $CLIMATE 30 $GRID hybrid $HYDRO $OUTFILE $INFILE"
                echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
                
                echo >> $SCRIPT
                echo "# $SCRIPT written"
                echo
            done
        done
    done
done

echo
echo
echo "Run $SUBMIT to submit all jobs to the scheduler"
echo
echo

