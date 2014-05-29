green-hydro/edrun/
===========

The idea here is to have something very simple and based on the well-documented
runs in chapter 1 of the PISM User's Manual.

All content is highly experimental.

Do

    $ ln -s ~/pism/examples/std-greenland/pism_Greenland_5km_v1.1.nc
    $ ln -s ~/pism/examples/std-greenland/g5km_gridseq.nc
    $ ./preprocess.sh
    $ ./run.sh

For analysis I am using

    $ ln -s ~/pism/examples/nbreen/showPvsW.py
