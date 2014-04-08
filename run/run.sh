#!/bin/bash

# Copyright (C) 2009-2014 The PISM Authors

# PISM Greenland spinup using either constant present-day climate or modeled
# paleoclimate.  See README.md.

# Before using this script, run preprocess.sh to download and adjust metadata
# in the SeaRISE "Present Day Greenland" master dataset.

set -e  # exit on error

GRIDLIST="{40, 20, 10, 5, 3, 2}"
CLIMLIST="{const, paleo, pdd}"
DYNALIST="{sia, hybrid}"
HYDROLIST="{null, routing, distributed}"

# preprocess.sh generates pism_*.nc files; run it first
if [ -n "${PISM_DATANAME:+1}" ] ; then  # check if env var is already set
    PISM_DATANAME=$PISM_DATANAME
else
    PISM_DATANAME=pism_Greenland_5km_v2_ctrl.nc
fi

PISM_TEMPSERIES=pism_dT.nc
PISM_SLSERIES=pism_dSL.nc

if [ $# -lt 5 ] ; then
  echo "run.sh ERROR: needs 5 or 6 or 7 or 8 positional arguments ... ENDING NOW"
  echo
  echo "usage:"
  echo
  echo "    run.sh PROCS CLIMATE DURATION GRID DYNAMICS HYRDRO [OUTFILE] [BOOTFILE]"
  echo
  echo "  where:"
  echo "    PROCS     = 1,2,3,... is number of MPI processes"
  echo "    CLIMATE   in $CLIMLIST"
  echo "    DURATION  = model run time in years; does '-ys -DURATION -ye 0'"
  echo "    GRID      in $GRIDLIST (km)"
  echo "    DYNAMICS  in $DYNALIST; sia is non-sliding; default = sia"
  echo "    HYDRO     in $HYDROLIST; default = null"
  echo "    OUTFILE   optional name of output file; default = unnamed.nc"
  echo "    BOOTFILE  optional name of input file; default = $PISM_DATANAME"
  echo
  echo "consider setting optional environment variables (see script for meaning):"
  echo "    PISM_DATANAME sets DATANAME file used for input data"
  echo "    TSSTEP       spacing between -ts_files outputs; defaults to yearly"
  echo "    EXSTEP       spacing in years between -extra_files outputs; defaults to 100"
  echo "    EXVARS       desired -extra_vars; defaults to 'diffusivity,temppabase,"
  echo "                   tempicethk_basal,bmelt,tillwat,csurf,mask,thk,topg,usurf'"
  echo "                   plus ',hardav,cbase,tauc' if DYNAMICS=hybrid"
  echo "    NODIAGS      if set, DON'T use -ts_file or -extra_file"
  echo "    PARAM_PPQ    sets (hybrid-only) option -pseudo_plastic_q \$PARAM_PPQ"
  echo "                   [default=0.25]"
  echo "    PARAM_SIAE   sets option -sia_e \$PARAM_SIAE   [default=3.0]"
  echo "    PARAM_TEFO   sets (hybrid-only) option -till_effective_fraction_overburden"
  echo "                   \$PARAM_TEFO   [default=0.02]"
  echo "    PARAM_TTPHI  sets (hybrid-only) option -topg_to_phi \$PARAM_TTPHI"
  echo "                   [default=15.0,40.0,-300.0,700.0]"
  echo "    PARAM_NOSGL  if set, DON'T use -tauc_slippery_grounding_lines"
  echo "    PARAM_FTT    if set, use force-to-thickness method"
  echo "    PARAM_TWRATE sets option -hydrology_tillwat_rate \$PARAM_TWRATE"
  echo "                   [default=1e-6] for [routing, distributed]"
  echo "    PARAM_TWPROP sets -hydrology_tillwat_transfer_proportion \$PARAM_TWPROP"
  echo "                 [default=100] for [routing, distributed]"
  echo "    PARAM_OPEN   sets -hydrology_cavitation_opening_coefficient \$PARAM_OPEN"
  echo "                 [default=0.5] for [distributed]"
  echo "    PARAM_CLOSE  sets -hydrology_creep_closure_coefficient \$PARAM_CLOSE"
  echo "                 [default=0.04] for [distributed]"
  echo "    PISM_DO      set to 'echo' if no run desired; defaults to empty"
  echo "    PISM_MPIDO   defaults to 'mpiexec -n'"
  echo "    PISM_PREFIX  set to path to pismr executable if desired; defaults to empty"
  echo "    PISM_EXEC    defaults to 'pismr'"
  echo "    PISM_CONFIG  config file, defaults to hydro_config.nc"
  echo "    REGRIDFILE   set to file name to regrid from; defaults to empty (no regrid)"
  echo "    REGRIDVARS   desired -regrid_vars; applies *if* REGRIDFILE set;"
  echo "                   defaults to 'bmelt,enthalpy,litho_temp,thk,tillwat'"
  echo "    STARTEND     sets START and END year of a simulation. If used, overwrites DURA. e.g. -50000,2500 for a run from -50000 to 2500 years"
  echo
  echo "example usage 1:"
  echo
  echo "    $ ./spinup.sh 4 const 1000 20 sia"
  echo
  echo "  Does spinup with 4 processors, constant-climate, 1000 year run, 20 km"
  echo "  grid, and non-sliding SIA stress balance.  Bootstraps from and outputs to"
  echo "  default files."
  echo
  echo "example usage 2:"
  echo
  echo "    $ PISM_DO=echo ./spinup.sh 128 paleo 100.0 5 hybrid out.nc boot.nc &> foo.sh"
  echo
  echo "  Creates a script foo.sh for spinup with 128 processors, simulated paleo-climate,"
  echo "  5 km grid, sliding with SIA+SSA hybrid, output to {out.nc,ts_out.nc,ex_out.nc},"
  echo "  and bootstrapping from boot.nc."
  echo
  exit
fi

if [ -n "${SCRIPTNAME:+1}" ] ; then
  echo "[SCRIPTNAME=$SCRIPTNAME (already set)]"
  echo ""
else
  SCRIPTNAME="#(run.sh)"
fi

if [ $# -gt 8 ] ; then
  echo "$SCRIPTNAME WARNING: ignoring arguments after argument 7 ..."
fi

NN="$1" # first arg is number of processes

if [ -z "${STARTEND}" ] ; then  # check if env var is NOT set
    DURATION=$3
    START=-$(($DURATION))
    END=0
    RUNSTARTEND="-ys $START -ye $END"
else
    STARTEND=$STARTEND
    IFS=',' read START END <<<"$STARTEND"
    RUNSTARTEND="-ys $START -ye $END"
fi

# are we doing force to thickness?
PISM_FTT_FILE=$PISM_DATANAME
if [ -z "${PARAM_FTT}" ] ; then  # check if env var is NOT set
    FTT=""
else
    FTT=",forcing -force_to_thk $PISM_FTT_FILE"
fi

# override config file?
if [ -z "${PISM_CONFIG}" ] ; then  # check if env var is NOT set
    CONFIG=hydro_config.nc
else
    CONFIG=$PISM_CONFIG
fi

# set coupler from argument 2
if [ "$2" = "const" ]; then
  climname="constant-climate"
  INLIST=""
  COUPLER="-surface given$FTT -surface_given_file $PISM_DATANAME"
elif [ "$2" = "paleo" ]; then
  climname="paleo-climate"
  INLIST="$PISM_TEMPSERIES $PISM_SLSERIES"
  COUPLER=" -atmosphere searise_greenland,delta_T,paleo_precip -surface pdd$FTT -atmosphere_paleo_precip_file $PISM_TEMPSERIES -atmosphere_delta_T_file $PISM_TEMPSERIES -ocean constant,delta_SL -ocean_delta_SL_file $PISM_SLSERIES"
elif [ "$2" = "pdd" ]; then
  climname="pdd-climate"
  COUPLER=" -atmosphere searise_greenland -surface pdd$FTT -ocean constant"
else
  echo "invalid second argument; must be in $CLIMLIST"
  exit
fi

# decide on grid and skip from argument 4
COARSESKIP=10
FINESKIP=20
FINESTSKIP=50
VDIMS="-Lz 4000 -Lbz 2000 -skip -skip_max "
COARSEVGRID="-Mz 101 -Mbz 11 -z_spacing equal ${VDIMS} ${COARSESKIP}"
FINEVGRID="-Mz 201 -Mbz 21 -z_spacing equal ${VDIMS} ${FINESKIP}"
FINESTVGRID="-Mz 401 -Mbz 41 -z_spacing equal ${VDIMS} ${FINESTSKIP}"
if [ "$4" -eq "40" ]; then
  dx=40
  myMx=38
  myMy=71
  vgrid=$COARSEVGRID
elif [ "$4" -eq "20" ]; then
  dx=20
  myMx=76
  myMy=141
  vgrid=$COARSEVGRID
elif [ "$4" -eq "10" ]; then
  dx=10
  myMx=151
  myMy=281
  vgrid=$FINEVGRID
elif [ "$4" -eq "5" ]; then
  # "native" resolution in data file, with 561 x 301 grid
  dx=5
  myMx=301
  myMy=561
  vgrid=$FINEVGRID
elif [ "$4" -eq "3" ]; then
  dx=3
  myMx=501
  myMy=934
  vgrid=$FINESTVGRID
elif [ "$4" -eq "2" ]; then
  dx=2
  myMx=750
  myMy=1400
  vgrid=$FINESTVGRID
else
  echo "invalid fourth argument: must be in $GRIDLIST"
  exit
fi

# set stress balance from argument 5
if [ -n "${PARAM_SIAE:+1}" ] ; then  # check if env var is already set
  PHYS="-calving ocean_kill -ocean_kill_file ${PISM_DATANAME} -sia_e ${PARAM_SIAE}"
else
  PHYS="-calving ocean_kill -ocean_kill_file ${PISM_DATANAME} -sia_e 3.0"
fi
# done forming $PHYS if "$5" = "sia"
if [ "$5" = "hybrid" ]; then
  if [ -z "${PARAM_TTPHI}" ] ; then  # check if env var is NOT set
    PARAM_TTPHI="15.0,40.0,-300.0,700.0"
  fi
  if [ -z "${PARAM_PPQ}" ] ; then  # check if env var is NOT set
    PARAM_PPQ="0.25"
  fi
  if [ -z "${PARAM_TEFO}" ] ; then  # check if env var is NOT set
    PARAM_TEFO="0.02"
  fi
  if [ -z "${PARAM_NOSGL}" ] ; then  # check if env var is NOT set
    SGL="-tauc_slippery_grounding_lines"
  else
    SGL=""
  fi
  PHYS="${PHYS} -stress_balance ssa+sia -topg_to_phi ${PARAM_TTPHI} -pseudo_plastic -pseudo_plastic_q ${PARAM_PPQ} -till_effective_fraction_overburden ${PARAM_TEFO} ${SGL}"
else
  if [ "$5" = "sia" ]; then
    echo "$SCRIPTNAME  sia-only case: ignoring PARAM_TTPHI, PARAM_PPQ, PARAM_TEFO ..."
  else
    echo "invalid fifth argument; must be in $DYNALIST"
    exit
  fi
fi


if [ -n "${PARAM_TWRATE+1}" ] ; then  # check if env var is set
  PARAM_TWRATE=$PARAM_TWRATE
else
  PARAM_TWRATE="1e-6"
fi
if [ -n "${PARAM_TWPROP+1}" ] ; then  # check if env var is set
  PARAM_TWPROP=$PARAM_TWPROP
else
  PARAM_TWPROP="100"
fi
if [ -n "${PARAM_OPEN+1}" ] ; then  # check if env var is set
  PARAM_OPEN=$PARAM_OPEN
else
  PARAM_OPEN="0.5"
fi
if [ -n "${PARAM_CLOSE+1}" ] ; then  # check if env var is set
  PARAM_CLOSE=$PARAM_CLOSE
else
  PARAM_CLOSE="0.04"
fi

HYDROPARAMS="-hydrology_tillwat_rate ${PARAM_TWRATE} -hydrology_tillwat_transfer_proportion ${PARAM_TWPROP} -hydrology_cavitation_opening_coefficient ${PARAM_OPEN} -hydrology_creep_closure_coefficient ${PARAM_CLOSE}"

# set output filename from argument 6
if [ "$6" = "null" ]; then
  HYDRO="-hydrology null"
elif [ "$6" = "routing" ]; then
  HYDRO="-hydrology routing $HYDROPARAMS"
elif [ "$6" = "distributed" ]; then
  HYDRO="-hydrology distributed $HYDROPARAMS"
else
  echo "invalid sixt argument, must be in $HYDROLIST"
fi

# set output filename from argument 7
if [ -z "$7" ]; then
  OUTNAME=unnamed.nc
else
  OUTNAME=$7
fi

# set bootstrapping input filename from argument 8
if [ -z "$8" ]; then
  INNAME=$PISM_DATANAME
else
  INNAME=$8
fi
INLIST="${INLIST} $INNAME $REGRIDFILE $CONFIG"

# now we have read options ... we know enough to report to user ...
echo
echo "# ======================================================================="
echo "# PISM std Greenland spinup:"
echo "#    $NN processors, $DURATION a run, $dx km grid, $climname, $5 dynamics"
echo "# ======================================================================="

# actually check for input files
for INPUT in $INLIST; do
  if [ -e "$INPUT" ] ; then  # check if file exist
    echo "$SCRIPTNAME           input   $INPUT (found)"
  else
    echo "$SCRIPTNAME           input   $INPUT (MISSING!!)"
    echo
    echo "$SCRIPTNAME  ***WARNING***  you may need to run ./preprocess.sh to generate standard input files!"
    echo
  fi
done

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
#  $ export PISM_EXEC="pismr -energy cold"
if [ -n "${PISM_EXEC:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME       PISM_EXEC = $PISM_EXEC  (already set)"
else
  PISM_EXEC="pismr"
  echo "$SCRIPTNAME       PISM_EXEC = $PISM_EXEC"
fi

# set TSSTEP to default if not set
if [ -n "${TSSTEP:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME          TSSTEP = $TSSTEP  (already set)"
else
  TSSTEP=yearly
  echo "$SCRIPTNAME          TSSTEP = $TSSTEP"
fi

# set EXSTEP to default if not set
if [ -n "${EXSTEP:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME          EXSTEP = $EXSTEP  (already set)"
else
  EXSTEP="100"
  echo "$SCRIPTNAME          EXSTEP = $EXSTEP"
fi

# set EXVARS list to defaults if not set
if [ -n "${EXVARS:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME          EXVARS = $EXVARS  (already set)"
else
  EXVARS="bwat,bwatvel,wallmelt,diffusivity,temppabase,tempicethk_basal,bmelt,tillwat,csurf,mask,thk,topg,usurf"
  if [ "$5" = "hybrid" ]; then
    EXVARS="${EXVARS},hardav,cbase,tauc"
  fi
  echo "$SCRIPTNAME          EXVARS = $EXVARS"
fi

# if REGRIDFILE set then form regridcommand
if [ -n "${REGRIDFILE:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME      REGRIDFILE = $REGRIDFILE"
  if [ -n "${REGRIDVARS:+1}" ] ; then  # check if env var is already set
    echo "$SCRIPTNAME      REGRIDVARS = $REGRIDVARS  (already set)"
  else
    REGRIDVARS='litho_temp,thk,enthalpy,tillwat,bmelt'
    # note: other vars which are "state":  Href, dbdt, shelfbtemp, shelfbmassflux
    echo "$SCRIPTNAME      REGRIDVARS = $REGRIDVARS"
  fi
  regridcommand="-regrid_file $REGRIDFILE -regrid_vars $REGRIDVARS"
else
  regridcommand=""
fi

# show remaining setup options:
PISM="${PISM_PREFIX}${PISM_EXEC}"
echo "$SCRIPTNAME      executable = '$PISM'"
echo "$SCRIPTNAME         coupler = '$COUPLER'"
echo "$SCRIPTNAME        dynamics = '$PHYS'"

# set up diagnostics
if [ -z "${NODIAGS}" ] ; then  # check if env var is NOT set
  TSNAME=ts_$OUTNAME
  TSTIMES=$START:$TSSTEP:$END
  EXNAME=ex_$OUTNAME
  EXTIMES=$START:$EXSTEP:$END
  # check_stationarity.py can be applied to $EXNAME
  DIAGNOSTICS="-ts_file $TSNAME -ts_times $TSTIMES -extra_file $EXNAME -extra_times $EXTIMES -extra_vars $EXVARS"
else
  DIAGNOSTICS=""
fi

# construct command
cmd="$PISM_MPIDO $NN $PISM -config_override $CONFIG -boot_file $INNAME -Mx $myMx -My $myMy $vgrid $RUNSTARTEND $regridcommand $COUPLER $PHYS $HYDRO $DIAGNOSTICS -o $OUTNAME"
echo
$PISM_DO $cmd

