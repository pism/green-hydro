#!/bin/bash

# Copyright (C) 2009-2014 Andy Aschwanden and Ed Bueler
#
# *****************************************************************************
# Pre-Spinup
# *****************************************************************************
#
#
# Preparatory stage
#
# - short smoothing run
# - SIA-only -no_mass run
# - full-physics run
#
# using temperatures (air_temp) and climatic mass balance (climatic_mass_balance)
# from RACMO2/GR

# before using this script, run preprocess.sh to download and adjust metadata
# on input files

# recommended way to run with N processors is " ./prespinup.sh N >& out.prespinup & "
# which gives a viewable (with "less", for example) transcript in out.prespinup

SCRIPTNAME="#(prespinup.sh)"

echo
echo "# =================================================================================="
echo "# PISM pre-spinup "
echo "# =================================================================================="
echo

set -e  # exit on error

NN=2  # default number of processors
if [ $# -gt 0 ] ; then  # if user says "psearise.sh 8" then NN = 8
  NN="$1"
fi

echo "$SCRIPTNAME              NN = $NN"

# set MPIDO if using different MPI execution command, for example:
#  $ export PISM_MPIDO="aprun -n "
if [ -n "${PISM_MPIDO:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME      PISM_MPIDO = $PISM_MPIDO  (already set)"
else
  PISM_MPIDO="mpiexec -n "
  echo "$SCRIPTNAME      PISM_MPIDO = $PISM_MPIDO"
fi

# check if env var PISM_DO was set (i.e. PISM_DO=echo for a 'dry' run)
if [ -n "${PISM_DO:+1}" ] ; then  # check if env var DO is already set
  echo "$SCRIPTNAME         PISM_DO = $PISM_DO  (already set)"
else
  PISM_DO="" 
fi

# prefix to pism (not to executables)
if [ -n "${PISM_PREFIX:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME     PISM_PREFIX = $PISM_PREFIX  (already set)"
else
  PISM_PREFIX=""    # just a guess
  echo "$SCRIPTNAME     PISM_PREFIX = $PISM_PREFIX"
fi

# set PISM_EXEC if using different executables, for example:
#  $ export PISM_EXEC="pismr -cold"
if [ -n "${PISM_EXEC:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME       PISM_EXEC = $PISM_EXEC  (already set)"
else
  PISM_EXEC="pismr"
  echo "$SCRIPTNAME       PISM_EXEC = $PISM_EXEC"
fi

echo

# preprocess.sh generates pism_*.nc files; run it first
if [ -n "${PISM_DATANAME:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME   PISM_DATANAME = $PISM_DATANAME  (already set)"
else
  PISM_DATANAME=pism_Greenland_20km_v2_hotspot.nc
fi


PISM_CONFIG=hydro_config.nc
#PISM_BCFILE=RACMO_CLRUN_10KM_CON_MM_baseline.nc

for INPUT in $PISM_DATANAME $PISM_CONFIG; do
  if [ -e "$INPUT" ] ; then  # check if file exist
    echo "$SCRIPTNAME           input   $INPUT (found)"
  else
    echo "$SCRIPTNAME           input   $INPUT (MISSING!!)"
    echo
    echo "     !!!!   RUN  preprocess.sh  TO GENERATE  $INPUT   !!!!"
    echo
  fi
done

BOOTNAME=$PISM_DATANAME

# run lengths 
SMOOTHRUNLENGTH=100
NOMASSSIARUNLENGTH=47500
SSARUNLENGTH=2500

# grids
GRID20KM="-Mx 76 -My 141 -Lz 4000 -Lbz 2000 -Mz 111 -Mbz 51 -z_spacing equal"
GRID10KM="-Mx 151 -My 281 -Lz 4000 -Lbz 2000 -Mz 211 -Mbz 101 -z_spacing equal"

# skips
SKIP20KM=20
SKIP10KM=100

# default grid choices
GRID=$GRID20KM
SKIP=$SKIP20KM
GS=20 # km

echo ""
if [ $# -gt 1 ] ; then
  if [ $2 -eq "1" ] ; then  # if user says "prespinup.sh N 1" then use 10km:
    echo "$SCRIPTNAME grid: ALL RUNS ON 10km"
    echo "$SCRIPTNAME       WARNING: LARGE COMPUTATIONAL TIME"
    GRID=$GRID10KM
    SKIP=$SKIP10KM
    GS=10 # km
  fi
else
    echo "$SCRIPTNAME grid: ALL RUNS ON 20km"
fi
echo ""

echo "$SCRIPTNAME            grid = '$GRID' (= $GS km)"

# cat prefix and exec together
PISM="${PISM_PREFIX}${PISM_EXEC} -config_override $PISM_CONFIG"

# coupler settings for pre-spinup
COUPLER="-atmosphere searise_greenland -surface pdd -ocean constant"
PHYS="-calving ocean_kill -ocean_kill_file ${PISM_DATANAME} -sia_e 3.0"
PARAM_TTPHI="15.0,40.0,-300.0,700.0"
PARAM_PPQ="0.25"
PARAM_TEFO="0.02"
SGL="-tauc_slippery_grounding_lines"
HYDRO="-hydrology null"

PHYSSIA="${PHYS} -stress_balance sia $HYDRO"
PHYSHYBRID="${PHYS} -stress_balance ssa+sia -topg_to_phi ${PARAM_TTPHI} -pseudo_plastic -pseudo_plastic_q ${PARAM_PPQ} -till_effective_fraction_overburden ${PARAM_TEFO} $HYDRO"

# time step for exvars to save
EXSTEP=500
# extra variables saved every EXSTEP
EXVARS="temppabase,hardav,cbase,csurf,diffusivity" 

OUTNAME=g${GS}km_steady_sia.nc
EXNAME=ex_$OUTNAME
EXTIMES=0:$EXSTEP:${NOMASSSIARUNLENGTH}
echo
echo "$SCRIPTNAME  -no_mass (no surface change) SIA run to achieve approximate temperature equilibrium, for ${NOMASSSIARUNLENGTH}a"
cmd="$PISM_MPIDO $NN $PISM -boot_file $PISM_DATANAME $GRID $COUPLER \
  -no_mass -ys 0 -y ${NOMASSSIARUNLENGTH} $PHYSSIA\
  -extra_file $EXNAME -extra_vars $EXVARS -extra_times $EXTIMES -o $OUTNAME"
$PISM_DO $cmd

# run with full physics
INNAME=$OUTNAME
OUTNAME=g${GS}km_steady_ssa.nc
TSNAME=ts_$OUTNAME
TSTIMES=0:$TSSTEP:$SSARUNLENGTH
EXNAME=ex_$OUTNAME
EXTIMES=0:$EXSTEP:$SSARUNLENGTH
EXSTEP=100
echo
echo "$SCRIPTNAME  full physics run ${SSARUNLENGTH}a"
cmd="$PISM_MPIDO $NN $PISM -i $INNAME $COUPLER \
  -no_mass -ys 0 -y ${SSARUNLENGTH} $PHYSHYBRID \
  -extra_file $EXNAME -extra_vars $EXVARS -extra_times $EXTIMES -o $OUTNAME"
$PISM_DO $cmd


echo
echo "$SCRIPTNAME  Pre spinup done"
