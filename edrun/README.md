green-hydro/edrun/
===========

The idea here is to have something very simple and based on the well-documented
runs in chapter 1 of the PISM User's Manual.

These scripts are in support of the paper `gmd-hydro.tex` in https://github.com/bueler/hydrolakes

Do

    $ ln -s ~/pism/examples/std-greenland/pism_Greenland_5km_v1.1.nc
    $ ln -s ~/pism/examples/std-greenland/Greenland_5km_v1.1.nc

Run a grid sequencing like in Chapter 1 of User's Manual to get
`g2km_gridseq.nc`.  Then do

    $ ./run-decoupled.sh 5 g2km_gridseq.nc                  # 5 year runs

This run produces four files of importance, namely `routing-decoupled.nc`,
`ex_routing-decoupled.nc`, `distributed-decoupled.nc`, `ex_distributed-decoupled.nc`.

To generate figures do:

    $ ./allfigs.sh g2km_gridseq

Then move all *.png into hydrolakes/figs.

