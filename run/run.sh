#!/bin/bash

# Copyright (C) 2014 The PISM Authors

# PISM Greenland spinup using either constant present-day climate or modeled
# paleoclimate.

# Before using this script, run preprocess.sh to download and 
# prepare data sets.

set -e  # exit on error

GRIDLIST="{36000, 18000, 9000, 4500, 3600, 1800, 1500, 1200, 900, 600, 450}"
CLIMLIST="{const, paleo, pdd, forcing}"
DYNALIST="{sia, hybrid}"
HYDROLIST="{null, routing, distributed}"

# preprocess.sh generates pism_*.nc files; run it first
if [ -n "${PISM_DATANAME:+1}" ] ; then  # check if env var is already set
    PISM_DATANAME=$PISM_DATANAME
else
    PISM_DATANAME=pism_Greenland_5km_v3_ctrl.nc
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
  echo "    GRID      in $GRIDLIST (m)"
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
  echo "    PARAM_K      sets -hydraulic_conductivity \$PARAM_K"
  echo "                 [default=0.01] for [routing,distributed]"
  echo "    PARAM_ALPHA   sets -hydrology_thickness_power_in_flux \$PARAM_ALPHA"
  echo "                 [default=0.5] for [routing, distributed]"
  echo "    PARAM_OMEGA  sets -tauc_add_transportable_water -till_log_factor_transportable_water \$PARAM_OMEGA"
  echo "                 [default=0.04] for [routing, distributed]"
  echo "    PARAM_SSA_N  sets -sia_n \$PARAM_SIA_N"
  echo "                 [default=3] for Glen exponent in SIA"
  echo "    PARAM_SSA_N  sets -ssa_n \$PARAM_SSA_N"
  echo "                 [default=3] for Glen exponent in SSA"
  echo "    PISM_DO      set to 'echo' if no run desired; defaults to empty"
  echo "    PISM_OFORMAT set -o_format; defaults to netcdf3"
  echo "    PISM_MPIDO   defaults to 'mpiexec -n'"
  echo "    PISM_PREFIX  set to path to pismr executable if desired; defaults to empty"
  echo "    PISM_EXEC    defaults to 'pismr'"
  echo "    PISM_CONFIG  config file, defaults to hydro_config.nc"
  echo "    PISM_SAVE    set -save_times, defaults to None"
  echo "    REGRIDFILE   set to file name to regrid from; defaults to empty (no regrid)"
  echo "    REGRIDVARS   desired -regrid_vars; applies *if* REGRIDFILE set;"
  echo "                   defaults to 'bmelt,enthalpy,litho_temp,thk,tillwat,Href'"
  echo "    STARTEND     sets START and END year of a simulation. If used, overwrites DURA. e.g. -50000,2500 for a run from -50000 to 2500 years"
  echo
  echo "example usage 1:"
  echo
  echo "    $ ./run.sh 4 const 1000 18000 sia"
  echo
  echo "  Does spinup with 4 processors, constant-climate, 1000 year run, 18 km"
  echo "  grid, and non-sliding SIA stress balance.  Bootstraps from and outputs to"
  echo "  default files."
  echo
  echo "example usage 2:"
  echo
  echo "    $ PISM_DO=echo ./run.sh 128 paleo 100.0 4500 hybrid out.nc boot.nc &> foo.sh"
  echo
  echo "  Creates a script foo.sh for spinup with 128 processors, simulated paleo-climate,"
  echo "  4.5 km grid, sliding with SIA+SSA hybrid, output to {out.nc,ts_out.nc,ex_out.nc},"
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

# are we doing force to thickness?
PISM_FTT_FILE=$PISM_DATANAME
if [ -z "${PARAM_FTT}" ] ; then  # check if env var is NOT set
    FTT=""
else
    FTT=",forcing -force_to_thickness_file $PISM_FTT_FILE"
fi


# are we using a time file for forcing?
if [ -z "${PISM_BCFILE}" ] ; then  # check if env var is NOT set
    PISM_BCFILE=RACMO_CLRUN_10KM_CON_MM_EPSG3413.nc
else
    PISM_BCFILE=$PISM_BCFILE
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
  # use this if you want constant-climate with force-to-thickness
  COUPLER="-surface given$FTT -surface_given_file $PISM_DATANAME"
  # COUPLER="-surface given -surface_given_file $PISM_DATANAME"
elif [ "$2" = "paleo" ]; then
  climname="paleo-climate"
  INLIST="$PISM_TEMPSERIES $PISM_SLSERIES"
  COUPLER=" -atmosphere searise_greenland,delta_T,paleo_precip -surface pdd$FTT -atmosphere_paleo_precip_file $PISM_TEMPSERIES -atmosphere_delta_T_file $PISM_TEMPSERIES -ocean constant,delta_SL -ocean_delta_SL_file $PISM_SLSERIES"
elif [ "$2" = "pdd" ]; then
  climname="pdd-climate"
  COUPLER=" -atmosphere searise_greenland -surface pdd$FTT -ocean constant"
elif [ "$2" = "forcing" ]; then
  climname="rcm-forcing"
  INLIST=""
  # RACMO forcing not yet ready for ocean.
  # COUPLER="-surface given -surface_given_file $PISM_BCFILE -ocean given -ocean_given_file $PISM_BCFILE"
  COUPLER="-surface given -surface_given_file $PISM_BCFILE"

else
  echo "invalid second argument; must be in $CLIMLIST"
  exit
fi

# decide on grid and skip from argument 4
COARSESKIP=10
MEDIUMSKIP=20
FINESKIP=50
FINESTSKIP=200
VDIMS="-Lz 4000 -Lbz 2000 -skip -skip_max "
COARSEVGRID="-Mz 101 -Mbz 11 -z_spacing equal ${VDIMS} ${COARSESKIP}"
MEDIUMVGRID="-Mz 201 -Mbz 21 -z_spacing equal ${VDIMS} ${MEDIUMSKIP}"
FINEVGRID="-Mz 201 -Mbz 21 -z_spacing equal ${VDIMS} ${FINESKIP}"
FINESTVGRID="-Mz 401 -Mbz 41 -z_spacing equal ${VDIMS} ${FINESTSKIP}"
if [ "$4" == "36000" ]; then
  dx=$4
  myMx=44
  myMy=76
  vgrid=$COARSEVGRID
elif [ "$4" == "18000" ]; then
  dx=$4
  myMx=88
  myMy=152
  vgrid=$COARSEVGRID
elif [ "$4" == "9000" ]; then
  dx=$4
  myMx=176
  myMy=304
  vgrid=$MEDIUMVGRID
elif [ "$4" == "4500" ]; then
  dx=$4
  myMx=352
  myMy=608
  vgrid=$MEDIUMVGRID
elif [ "$4" == "3600" ]; then
  dx=$4
  myMx=440
  myMy=760
  vgrid=$FINEVGRID
elif [ "$4" == "1800" ]; then
  dx=$4
  myMx=880
  myMy=1520
  vgrid=$FINEVGRID
elif [ "$4" == "1500" ]; then
  dx=$4
  myMx=1056
  myMy=1824
  vgrid=$FINEVGRID
elif [ "$4" == "1200" ]; then
  dx=$4
  myMx=1320
  myMy=2280
  vgrid=$FINEVGRID
elif [ "$4" == "900" ]; then
  dx=$4
  myMx=1760
  myMy=3040
  vgrid=$FINESTVGRID
elif [ "$4" == "600" ]; then
  dx=$4
  myMx=2640
  myMy=4560
  vgrid=$FINESTVGRID
elif [ "$4" == "450" ]; then
  dx=$4
  myMx=3520
  myMy=6080
  vgrid=$FINESTVGRID
else
  echo "invalid fourth argument: must be in $GRIDLIST"
  exit
fi

# set stress balance from argument 5
if [ -n "${PARAM_SIA_N:+1}" ] ; then  # check if env var is NOT set
    SIA_N="-sia_n ${PARAM_SIA_N}"
else
    SIA_N="-sia_n 1.25"
fi
if [ -n "${PARAM_SIAE:+1}" ] ; then  # check if env var is already set
  PHYS="-calving ocean_kill -ocean_kill_file ${PISM_DATANAME} -sia_e ${PARAM_SIAE} ${SIA_N}"
else
  PHYS="-calving ocean_kill -ocean_kill_file ${PISM_DATANAME} -sia_e ${SIA_N}"
fi
# done forming $PHYS if "$5" = "sia"
if [ "$5" = "hybrid" ]; then
  if [ -z "${PARAM_TTPHI}" ] ; then  # check if env var is NOT set
    PARAM_TTPHI="5.0,40.0,-300.0,700.0"
  fi
  if [ -z "${PARAM_PPQ}" ] ; then  # check if env var is NOT set
    PARAM_PPQ="0.5"
  fi
  if [ -z "${PARAM_TEFO}" ] ; then  # check if env var is NOT set
    PARAM_TEFO="0.02"
  fi
  if [ -z "${PARAM_NOSGL}" ] ; then  # check if env var is NOT set
    SGL="-tauc_slippery_grounding_lines"
  else
    SGL=""
  fi
  if [ -n "${PARAM_SSA_N:+1}" ] ; then  # check if env var is NOT set
    SSA_N="-ssa_n ${PARAM_SSA_N}"
  else
    SSA_N="-ssa_n 3.25"
  fi
  PHYS="${PHYS} -stress_balance ssa+sia -cfbc -topg_to_phi ${PARAM_TTPHI} -pseudo_plastic -pseudo_plastic_q ${PARAM_PPQ} -till_effective_fraction_overburden ${PARAM_TEFO} ${SGL} ${SSA_N}"
else
  if [ "$5" = "sia" ]; then
    echo "$SCRIPTNAME  sia-only case: ignoring PARAM_TTPHI, PARAM_PPQ, PARAM_TEFO ..."
  else
    echo "invalid fifth argument; must be in $DYNALIST"
    exit
  fi
fi

if [ -n "${PARAM_ALPHA+1}" ] ; then  # check if env var is set
  PARAM_ALPHA=$PARAM_ALPHA
else
  PARAM_ALPHA="1.25"
fi
if [ -n "${PARAM_OMEGA+1}" ] ; then  # check if env var is set
  PARAM_OMEGA=$PARAM_OMEGA
else
  PARAM_OMEGA="0.1"
fi
if [ -n "${PARAM_K+1}" ] ; then  # check if env var is set
  PARAM_K=$PARAM_K
else
  PARAM_K="0.01"
fi

HYDROPARAMS="-hydrology_thickness_power_in_flux ${PARAM_ALPHA} -tauc_add_transportable_water -till_log_factor_transportable_water ${PARAM_OMEGA} -hydrology_hydraulic_conductivity ${PARAM_K}"

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
OUTNAMESANS=`basename $OUTNAME .nc`

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
echo "# PISM Greenland run:"
echo "#    $NN processors, $DURATION a run, $dx m grid, $climname, $5 dynamics"
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

# set output format:
#  $ export PISM_OFORMAT="netcdf4_parallel "
if [ -n "${PISM_OFORMAT:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME                      PISM_OFORMAT = $PISM_OFORMAT  (already set)"
else
  PISM_OFORMAT="netcdf3"
  echo "$SCRIPTNAME                      PISM_OFORMAT = $PISM_OFORMAT"
fi
OFORMAT=$PISM_OFORMAT

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
  EXVARS="bwat,bwatvel,diffusivity,temppabase,tempicethk_basal,bmelt,tillwat,velsurf_mag,mask,thk,topg,usurf,taud_mag,flux_divergence,velsurf,climatic_mass_balance,climatic_mass_balance_original"
  if [ "$5" = "hybrid" ]; then
    EXVARS="${EXVARS},hardav,velbase_mag,tauc,taub_mag"
  fi
  echo "$SCRIPTNAME          EXVARS = $EXVARS"
fi

# if REGRIDFILE set then form regridcommand
if [ -n "${REGRIDFILE:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME      REGRIDFILE = $REGRIDFILE"
  if [ -n "${REGRIDVARS:+1}" ] ; then  # check if env var is already set
    echo "$SCRIPTNAME      REGRIDVARS = $REGRIDVARS  (already set)"
  else
    REGRIDVARS='litho_temp,thk,enthalpy,tillwat,bmelt,Href'
    echo "$SCRIPTNAME      REGRIDVARS = $REGRIDVARS"
  fi
  regridcommand="-regrid_file $REGRIDFILE -regrid_vars $REGRIDVARS"
else
  regridcommand=""
fi

# set save times:
if [ -n "${PISM_SAVE:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME                      PISM_SAVE = $PISM_SAVE  (already set)"
  OUTNAMESANS=`basename $OUTNAME .nc`
  SAVE="-save_times $PISM_SAVE -save_split -save_file snap_$OUTNAMESANS"
else
  SAVE=""
fi


# show remaining setup options:
PISM="${PISM_PREFIX}${PISM_EXEC}"
echo "$SCRIPTNAME      executable = '$PISM'"
echo "$SCRIPTNAME         coupler = '$COUPLER'"
echo "$SCRIPTNAME        dynamics = '$PHYS'"

# set up diagnostics
if [ -z "${NODIAGS}" ] ; then  # check if env var is NOT set

    # are we using a time file for forcing?
    if [ -z "${PISM_TIMEFILE}" ] ; then  # check if env var is NOT set
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
        TSTIMES=$START:$TSSTEP:$END
        EXTIMES=$START:$EXSTEP:$END
    else
        TSTIMES=$TSSTEP
        EXTIMES=$EXSTEP
        RUNSTARTEND="-time_file $PISM_TIMEFILE"
    fi
    TSNAME=ts_$OUTNAME
    EXNAME=ex_$OUTNAME
    # check_stationarity.py can be applied to $EXNAME
    DIAGNOSTICS="-ts_file $TSNAME -ts_times $TSTIMES -extra_file $EXNAME -extra_times $EXTIMES -extra_vars $EXVARS"
else
  DIAGNOSTICS=""
fi

# construct command
cmd="$PISM_MPIDO $NN $PISM -config_override $CONFIG -boot_file $INNAME -Mx $myMx -My $myMy $vgrid $RUNSTARTEND $regridcommand $COUPLER $PHYS $HYDRO $DIAGNOSTICS $SAVE -o_format $OFORMAT -o $OUTNAME"
echo
$PISM_DO $cmd

