green-hydro/edrun/
===========

The idea here is to have something very simple and based on the well-documented
runs in chapter 1 of the PISM User's Manual.

All content is highly experimental.

Do

    $ ln -s ~/pism/examples/std-greenland/pism_Greenland_5km_v1.1.nc
    $ ln -s ~/pism/examples/std-greenland/Greenland_5km_v1.1.nc

Run a grid sequencing like in Chapter 1 of User's Manual to get
`g2km_gridseq.nc`.  Then do

    $ ./preprocess.sh g2km_gridseq.nc g2km-init.nc
    $ ./run-decoupled.sh 5 g2km-init.nc                  # 5 year runs

For analysis I am using

    $ ln -s ~/pism/examples/nbreen/showPvsW.py

To generate figures do:

    $ ./genGreenfig.sh g2km-init Greenland_5km_v1.1
    $ ./genfig.sh ex_distributed-decoupled.nc g2km.png

