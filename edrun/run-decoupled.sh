#!/bin/bash

# uses 2 files:
#    pism_Greenland_5km_v1.1.nc  from examples/std-greenland/
#    g5km_gridseq.nc             ditto
# these files are documented in the PISM User's Manual, chapter 1
#
# run preprocess.sh first
#
# it would be reasonable to re-generate g5km_gridseq.nc so that it is closer
# to steady state
#
# it would be reasonable to generate g3km_gridseq.nc or even g1km_gridseq.nc

set -e  # exit on error

# check if env var PISM_DO was set (i.e. set PISM_DO=echo for a 'dry' run)
if [ -n "${PISM_DO:+1}" ] ; then  # check if env var is already set
  echo "#   PISM_DO = $PISM_DO  (already set)"
else
  PISM_DO=""
fi

MPIDO="mpiexec -n 6"

CLIMATE="-surface given -surface_given_file pism_Greenland_5km_v1.1.nc"
PHYS="-sia_e 3.0 -stress_balance ssa+sia -topg_to_phi 15.0,40.0,-300.0,700.0 -pseudo_plastic -pseudo_plastic_q 0.5 -till_effective_fraction_overburden 0.02 -tauc_slippery_grounding_lines"
CALVING="-calving ocean_kill -ocean_kill_file pism_Greenland_5km_v1.1.nc"

# these suffice for -hydrology null runs
EXVAR="diffusivity,temppabase,tempicethk_basal,bmelt,tillwat,velsurf_mag,mask,thk,topg,usurf,velbase_mag,tauc"

INNAME=g5km-init.nc

# run this to check for no shock: continue g5km_gridseq.nc run
DURATION=2
NAME=cont.nc
cmd="$MPIDO pismr -i $INNAME -skip -skip_max 20 $CLIMATE $PHYS $CALVING -ts_file ts_$NAME -ts_times 0:yearly:$DURATION -extra_file ex_$NAME -extra_times 0:10:$DURATION -extra_vars $EXVAR -y $DURATION -o $NAME"
#$PISM_DO $cmd
echo

# suitable for -hydrology routing,distributed runs which are decoupled:
EXVAR="mask,thk,topg,usurf,tillwat,bwat,hydrobmelt,bwatvel"

# -hydrology routing with   k=0.001
DURATION=5
NAME=routing-decoupled.nc
cmd="$MPIDO pismr -i $INNAME -no_mass -energy none -stress_balance none $CLIMATE -extra_file ex_$NAME -extra_times 0:monthly:$DURATION -extra_vars ${EXVAR} -hydrology_hydraulic_conductivity 0.001 -hydrology routing -hydrology_bmelt_file $INNAME -report_mass_accounting -ys 0 -y $DURATION -max_dt 0.05 -o $NAME"
$PISM_DO $cmd
echo

# -hydrology distributed with   k=0.001, Wr=1.0
DURATION=5
NAME=distributed-decoupled.nc
cmd="$MPIDO pismr -i $INNAME -no_mass -energy none -stress_balance none $CLIMATE -extra_file ex_$NAME -extra_times 0:monthly:$DURATION -extra_vars ${EXVAR},bwp,bwprel,hydrovelbase_mag -hydrology_hydraulic_conductivity 0.001 -hydrology_roughness_scale 1.0 -hydrology distributed -hydrology_bmelt_file $INNAME -hydrology_velbase_mag_file $INNAME -report_mass_accounting -ys 0 -y $DURATION -max_dt 0.05 -o $NAME"
$PISM_DO $cmd
echo

