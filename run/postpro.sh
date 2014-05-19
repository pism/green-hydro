#!/bin/bash

set -x -e

GRID=2

for ppq in 0.1 0.25 0.33 0.8; do
    for e in 1 2 3; do
        for glacier in "Jakobshavn" "Helheim" "Kangerdlugssuaq"; do
            ~/base/pypismtools/scripts/basemap-plot.py -v velsurf_mag --singlerow -p height --bounds -250 250 --colormap PiYG --obs_file surf_vels_${GRID}km_searise.nc --geotiff_file MODIS${glacier}250m.tif -o ${glacier}_e_${e}_ppq_${ppq}_velsurf_mag_diff.pdf ${GRID}km_pdd_ctrl/processed/g${GRID}km_pdd_ctrl_e_${e}_ppq_${ppq}_tefo_*.nc
        done
    done
done
