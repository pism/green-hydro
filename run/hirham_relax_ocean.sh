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
SCRIPTNAME=relax
CLIMATE=const

TYPELIST=(ctrl, old_bed, 970mW_hs, 1985)
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
  echo "    CALVING   in (${CALVINGLIST[@]})"
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
  PISM_WALLTIME=160:00:00
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
  PISM_OFORMAT="pnetcdf"
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
elif [ "$3" = "1985" ]; then
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

REGRIDFILE=$5
STARTYEAR=1989
ENDYEAR=2011
PISM_SURFACE_BCFILE=GR6b_ERAI_1989_2011_4800M_BIL_1989_baseline.nc
CONFIG=hindcast_config.nc
EXSTEP=yearly
RELAXYEARS=30

VERSION=2
PISM_DATANAME=pism_Greenland_${GRID}m_mcb_jpl_v${VERSION}_${TYPE}.nc

NODES=$(( $NN/$PROCS_PER_NODE))
TYPE=${TYPE}_v${VERSION}

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROCS_PER_NODE"
  MPIOUTLINE="#PBS -j oe"

# ########################################################
# set up relaxation run
# ########################################################

HYDRO=null
philow=5
TEFO=0.02
SSA_N=3.25
E=1.25
PPQ=0.6
for K in 1e14 1e15 1e16 1e17; do
    for THK in 100 200 300; do
        
        PARAM_TTPHI="${philow}.0,40.0,-700.0,700.0"
        PISM_OCEAN_BCFILE=ocean_forcing_${GRID}m_1989-2011_1989_baseline.nc
        OTYPE=ctrl
        EXPERIMENT=${CLIMATE}_${TYPE}_${RELAXYEARS}a_k_${K}_calving_${CALVING}_${THK}_ocean_${OTYPE}
        SCRIPT=hirham_relax_${RELAXYEARS}a_g${GRID}m_${EXPERIMENT}.sh
        POST=hirham_relax_${RELAXYEARS}a_g${GRID}m_${EXPERIMENT}_post.sh
        rm -f $SCRIPT $POST
        
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
        
        cmd="PISM_DO="" PISM_CONFIG=$CONFIG REGRIDVARS="litho_temp,enthalpy,tillwat,bmelt,Href,age" PARAM_NOAGE=foo PARAM_FRACTURE=foo PARAM_CALVING=$CALVING PARAM_CALVING_K=$K PARAM_CALVING_THK=$THK REGRIDFILE=$REGRIDFILE PISM_SURFACE_BCFILE=$PISM_SURFACE_BCFILE PISM_OCEAN_BCFILE=$PISM_OCEAN_BCFILE PISM_OFORMAT=$OFORMAT PISM_DATANAME=$PISM_DATANAME TSSTEP=daily EXSTEP=$EXSTEP PARAM_SIA_E=$E PARAM_PPQ=$PPQ PARAM_TEFO=$TEFO PARAM_TTPHI=$PARAM_TTPHI PARAM_SSA_N=$SSA_N PISM_PARAM=\"$PISM_PARAM\" ./run.sh $NN $CLIMATE $RELAXYEARS $GRID hybrid $HYDRO $OUTFILE $INFILE"
        echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
        
        echo >> $SCRIPT
        echo "# $SCRIPT written"
        
        source run-postpro-relax.sh
        echo "# $POST written"
        echo
        
        OTYPE=lm
        PISM_OCEAN_BCFILE=ocean_forcing_${GRID}m_1989-2011_${OTYPE}_1989_baseline.nc
        EXPERIMENT=${CLIMATE}_${TYPE}_${RELAXYEARS}a_k_${K}_calving_${CALVING}_${THK}_ocean_${OTYPE}
        SCRIPT=hirham_relax_${RELAXYEARS}a_g${GRID}m_${EXPERIMENT}.sh
        POST=hirham_relax_${RELAXYEARS}a_g${GRID}m_${EXPERIMENT}_post.sh
        rm -f $SCRIPT $POST
        
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
            
        cmd="PISM_DO="" PISM_CONFIG=$CONFIG REGRIDVARS="litho_temp,enthalpy,tillwat,bmelt,Href,age" PARAM_NOAGE=foo PARAM_FRACTURE=foo PARAM_CALVING=$CALVING PARAM_CALVING_K=$K PARAM_CALVING_THK=$THK REGRIDFILE=$REGRIDFILE PISM_SURFACE_BCFILE=$PISM_SURFACE_BCFILE PISM_OCEAN_BCFILE=$PISM_OCEAN_BCFILE PISM_OFORMAT=$OFORMAT PISM_DATANAME=$PISM_DATANAME TSSTEP=daily EXSTEP=$EXSTEP PARAM_SIA_E=$E PARAM_PPQ=$PPQ PARAM_TEFO=$TEFO PARAM_TTPHI=$PARAM_TTPHI PARAM_SSA_N=$SSA_N PISM_PARAM=\"$PISM_PARAM\" ./run.sh $NN $CLIMATE $RELAXYEARS $GRID hybrid $HYDRO $OUTFILE $INFILE"
        echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
        
        echo >> $SCRIPT
        echo "# $SCRIPT written"
        
        source run-postpro-relax.sh
        echo "# $POST written"
        echo
        
        OTYPE=lm2
        PISM_OCEAN_BCFILE=ocean_forcing_${GRID}m_1989-2011_${OTYPE}_1989_baseline.nc
        EXPERIMENT=${CLIMATE}_${TYPE}_${RELAXYEARS}a_k_${K}_calving_${CALVING}_${THK}_ocean_${OTYPE}
        SCRIPT=hirham_relax_${RELAXYEARS}a_g${GRID}m_${EXPERIMENT}.sh
        POST=hirham_relax_${RELAXYEARS}a_g${GRID}m_${EXPERIMENT}_post.sh
        rm -f $SCRIPT $POST
        
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
            
        cmd="PISM_DO="" PISM_CONFIG=$CONFIG REGRIDVARS="litho_temp,enthalpy,tillwat,bmelt,Href,age" PARAM_NOAGE=foo PARAM_FRACTURE=foo PARAM_CALVING=$CALVING PARAM_CALVING_K=$K PARAM_CALVING_THK=$THK REGRIDFILE=$REGRIDFILE PISM_SURFACE_BCFILE=$PISM_SURFACE_BCFILE PISM_OCEAN_BCFILE=$PISM_OCEAN_BCFILE PISM_OFORMAT=$OFORMAT PISM_DATANAME=$PISM_DATANAME TSSTEP=daily EXSTEP=$EXSTEP PARAM_SIA_E=$E PARAM_PPQ=$PPQ PARAM_TEFO=$TEFO PARAM_TTPHI=$PARAM_TTPHI PARAM_SSA_N=$SSA_N PISM_PARAM=\"$PISM_PARAM\" ./run.sh $NN $CLIMATE $RELAXYEARS $GRID hybrid $HYDRO $OUTFILE $INFILE"
        echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
        
        echo >> $SCRIPT
        echo "# $SCRIPT written"
        
        source run-postpro-relax.sh
        echo "# $POST written"
        echo

        OTYPE=lm3
        PISM_OCEAN_BCFILE=ocean_forcing_${GRID}m_1989-2011_${OTYPE}_1989_baseline.nc
        EXPERIMENT=${CLIMATE}_${TYPE}_${RELAXYEARS}a_k_${K}_calving_${CALVING}_${THK}_ocean_${OTYPE}
        SCRIPT=hirham_relax_${RELAXYEARS}a_g${GRID}m_${EXPERIMENT}.sh
        POST=hirham_relax_${RELAXYEARS}a_g${GRID}m_${EXPERIMENT}_post.sh
        rm -f $SCRIPT $POST
        
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
            
        cmd="PISM_DO="" PISM_CONFIG=$CONFIG REGRIDVARS="litho_temp,enthalpy,tillwat,bmelt,Href,age" PARAM_NOAGE=foo PARAM_FRACTURE=foo PARAM_CALVING=$CALVING PARAM_CALVING_K=$K PARAM_CALVING_THK=$THK REGRIDFILE=$REGRIDFILE PISM_SURFACE_BCFILE=$PISM_SURFACE_BCFILE PISM_OCEAN_BCFILE=$PISM_OCEAN_BCFILE PISM_OFORMAT=$OFORMAT PISM_DATANAME=$PISM_DATANAME TSSTEP=daily EXSTEP=$EXSTEP PARAM_SIA_E=$E PARAM_PPQ=$PPQ PARAM_TEFO=$TEFO PARAM_TTPHI=$PARAM_TTPHI PARAM_SSA_N=$SSA_N PISM_PARAM=\"$PISM_PARAM\" ./run.sh $NN $CLIMATE $RELAXYEARS $GRID hybrid $HYDRO $OUTFILE $INFILE"
        echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
        
        echo >> $SCRIPT
        echo "# $SCRIPT written"
        
        source run-postpro-relax.sh
        echo "# $POST written"
        echo

        OTYPE=sb
        PISM_OCEAN_BCFILE=ocean_forcing_${GRID}m_1989-2011_${OTYPE}_1989_baseline.nc
        EXPERIMENT=${CLIMATE}_${TYPE}_${RELAXYEARS}a_k_${K}_calving_${CALVING}_${THK}_ocean_${OTYPE}        SCRIPT=hirham_relax_${RELAXYEARS}a_g${GRID}m_${EXPERIMENT}.sh
        POST=hirham_relax_${RELAXYEARS}a_g${GRID}m_${EXPERIMENT}_post.sh
        rm -f $SCRIPT $POST
        
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
            
        cmd="PISM_DO="" PISM_CONFIG=$CONFIG REGRIDVARS="litho_temp,enthalpy,tillwat,bmelt,Href,age" PARAM_NOAGE=foo PARAM_FRACTURE=foo PARAM_CALVING=$CALVING PARAM_CALVING_K=$K PARAM_CALVING_THK=$THK REGRIDFILE=$REGRIDFILE PISM_SURFACE_BCFILE=$PISM_SURFACE_BCFILE PISM_OCEAN_BCFILE=$PISM_OCEAN_BCFILE PISM_OFORMAT=$OFORMAT PISM_DATANAME=$PISM_DATANAME TSSTEP=daily EXSTEP=$EXSTEP PARAM_SIA_E=$E PARAM_PPQ=$PPQ PARAM_TEFO=$TEFO PARAM_TTPHI=$PARAM_TTPHI PARAM_SSA_N=$SSA_N PISM_PARAM=\"$PISM_PARAM\" ./run.sh $NN $CLIMATE $RELAXYEARS $GRID hybrid $HYDRO $OUTFILE $INFILE"
        echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
        
        echo >> $SCRIPT
        echo "# $SCRIPT written"
        
        source run-postpro-relax.sh
        echo "# $POST written"
        echo
        
        OTYPE=m20
        PISM_OCEAN_BCFILE=ocean_forcing_${GRID}m_1989-2011_${OTYPE}_1989_baseline.nc
        EXPERIMENT=${CLIMATE}_${TYPE}_${RELAXYEARS}a_k_${K}_calving_${CALVING}_${THK}_ocean_${OTYPE}
        SCRIPT=hirham_relax_${RELAXYEARS}a_g${GRID}m_${EXPERIMENT}.sh
        POST=hirham_relax_${RELAXYEARS}a_g${GRID}m_${EXPERIMENT}_post.sh
        rm -f $SCRIPT $POST
        
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
        
        cmd="PISM_DO="" PISM_CONFIG=$CONFIG REGRIDVARS="litho_temp,enthalpy,tillwat,bmelt,Href,age" PARAM_NOAGE=foo PARAM_FRACTURE=foo PARAM_CALVING=$CALVING PARAM_CALVING_K=$K PARAM_CALVING_THK=$THK REGRIDFILE=$REGRIDFILE PISM_SURFACE_BCFILE=$PISM_SURFACE_BCFILE PISM_OCEAN_BCFILE=$PISM_OCEAN_BCFILE PISM_OFORMAT=$OFORMAT PISM_DATANAME=$PISM_DATANAME TSSTEP=daily EXSTEP=$EXSTEP  PARAM_SIA_E=$E PARAM_PPQ=$PPQ PARAM_TEFO=$TEFO PARAM_TTPHI=$PARAM_TTPHI PARAM_SSA_N=$SSA_N PISM_PARAM=\"$PISM_PARAM\" ./run.sh $NN $CLIMATE $RELAXYEARS $GRID hybrid $HYDRO $OUTFILE $INFILE"
        echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT

        echo >> $SCRIPT
        echo "# $SCRIPT written"
        
        source run-postpro-relax.sh
        echo "# $POST written"
        echo


        OTYPE=p20
        PISM_OCEAN_BCFILE=ocean_forcing_${GRID}m_1989-2011_${OTYPE}_1989_baseline.nc
        EXPERIMENT=${CLIMATE}_${TYPE}_${RELAXYEARS}a_k_${K}_calving_${CALVING}_${THK}_ocean_${OTYPE}
        SCRIPT=hirham_relax_${RELAXYEARS}a_g${GRID}m_${EXPERIMENT}.sh
        POST=hirham_relax_${RELAXYEARS}a_g${GRID}m_${EXPERIMENT}_post.sh
        rm -f $SCRIPT $POST
        
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
        
        cmd="PISM_DO="" PISM_CONFIG=$CONFIG REGRIDVARS="litho_temp,enthalpy,tillwat,bmelt,Href,age" PARAM_NOAGE=foo PARAM_FRACTURE=foo PARAM_CALVING=$CALVING PARAM_CALVING_K=$K PARAM_CALVING_THK=$THK REGRIDFILE=$REGRIDFILE PISM_SURFACE_BCFILE=$PISM_SURFACE_BCFILE PISM_OCEAN_BCFILE=$PISM_OCEAN_BCFILE PISM_OFORMAT=$OFORMAT PISM_DATANAME=$PISM_DATANAME TSSTEP=daily EXSTEP=$EXSTEP PARAM_SIA_E=$E PARAM_PPQ=$PPQ PARAM_TEFO=$TEFO PARAM_TTPHI=$PARAM_TTPHI PARAM_SSA_N=$SSA_N PISM_PARAM=\"$PISM_PARAM\" ./run.sh $NN $CLIMATE $RELAXYEARS $GRID hybrid $HYDRO $OUTFILE $INFILE"
        echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT
                
        echo >> $SCRIPT
        echo "# $SCRIPT written"
        
        source run-postpro-relax.sh
        echo "# $POST written"            
        echo
    done
done

