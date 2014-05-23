#!/bin/bash

# uses 3 files:
#    pism_Greenland_5km_v1.1.nc  from examples/std-greenland/
#    g5km_gridseq.nc             ditto
#    g5km_m1ka_const_ctrl.nc     beauregard.gi.alaska.edu:
#                                   /home2/tmp/green-hydro/g5km_m1ka_const_ctrl.nc/
# the first two files are documented in the PISM User's Manual, chapter 1
# the only significance of the last file is the new bedrock (topg)

set -e  # exit on error

MPIDO="mpiexec -n 6"

CLIMATE="-surface given -surface_given_file pism_Greenland_5km_v1.1.nc"
PHYS="-sia_e 3.0 -stress_balance ssa+sia -topg_to_phi 15.0,40.0,-300.0,700.0 -pseudo_plastic -pseudo_plastic_q 0.5 -till_effective_fraction_overburden 0.02 -tauc_slippery_grounding_lines"
CALVING="-calving ocean_kill -ocean_kill_file pism_Greenland_5km_v1.1.nc"

# these suffice for -hydrology null runs
EXVAR="diffusivity,temppabase,tempicethk_basal,bmelt,tillwat,velsurf_mag,mask,thk,topg,usurf,velbase_mag,tauc"

# continue g5km_gridseq.nc run with old bedrock (check for no shock):
DURATION=2
NAME=cont.nc
cmd="$MPIDO pismr -i g5km_gridseq.nc -skip -skip_max 20 $CLIMATE $PHYS $CALVING -ts_file ts_$NAME -ts_times 0:yearly:$DURATION -extra_file ex_$NAME -extra_times 0:10:$DURATION -extra_vars $EXVAR -y $DURATION -o $NAME"
echo $cmd
#$cmd
echo

# extend g5km_gridseq.nc run using new bedrock:
DURATION=200
NAME=g5km_v2bed.nc
cmd="$MPIDO pismr -i g5km_gridseq.nc -skip -skip_max 20 $CLIMATE $PHYS $CALVING -ts_file ts_$NAME -ts_times 0:yearly:$DURATION -extra_file ex_$NAME -extra_times 0:10:$DURATION -extra_vars $EXVAR -regrid_file g5km_m1ka_const_ctrl.nc -regrid_vars topg -y $DURATION -o $NAME"
echo $cmd
#$cmd
echo

INNAME=$NAME

# now try -hydrology routing with default params
DURATION=10
NAME=routing.nc
cmd="$MPIDO pismr -i $INNAME -no_mass $CLIMATE $PHYS -ts_file ts_$NAME -ts_times 0:1:$DURATION -extra_file ex_$NAME -extra_times 0:1:$DURATION -extra_vars ${EXVAR},bwat,bwp,bwprel,bwatvel -hydrology routing -report_mass_accounting -ys 0 -y $DURATION -o $NAME"
#echo $cmd
$cmd
echo

# now try -hydrology distributed with default params
DURATION=10
NAME=distributed.nc
cmd="$MPIDO pismr -i $INNAME -no_mass $CLIMATE $PHYS -ts_file ts_$NAME -ts_times 0:1:$DURATION -extra_file ex_$NAME -extra_times 0:1:$DURATION -extra_vars $EXVAR,bwat,bwp,bwprel,bwatvel -hydrology distributed -report_mass_accounting -ys 0 -y $DURATION -o $NAME"
#echo $cmd
$cmd
echo
