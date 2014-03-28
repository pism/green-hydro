#!/bin/bash

set -x -e

GRID=10

for q in 0.1 0.25 0.8; do
    for delta in 0.01 0.02 0.05; do
	for mu in 1e-5 5e-5 1e-6 5e-6; do
	    for omega in 1 10 100 1000 10000; do
		filepre=g${GRID}km_${q}_${delta}_${mu}_${omega}
		title="q=$q;"'$\delta$'"=$delta;"'$\omega$'"=$omega;"'$\mu$'"=$mu"
		for var in  "cbase" "csurf"; do
		    echo "plotting $var from ${filepre}.nc"
		    ~/base/pypismtools/scripts/basemap-plot.py -v $var --inner_titles $title --colorbar_label -p twocol --singlerow --colormap ~/base/pypismtools/colormaps/Full_saturation_spectrum_CCW_orange.cpt --geotiff_file MODISGreenland1kmclean_cut.tif -o ${filepre}_${var}.pdf ${filepre}.nc
		done
		for var in  "bwat"; do
		    echo "plotting $var from ${filepre}.nc"
		    ~/base/pypismtools/scripts/basemap-plot.py -v $var --inner_titles $title --colorbar_label -p twocol --singlerow --geotiff_file MODISGreenland1kmclean_cut.tif -o ${filepre}_${var}.pdf ${filepre}.nc
		done

	    done
	done
	filepre=g${GRID}km_${q}_${delta}_hydro_null
	title="q=$q;"'$\delta$'"=$delta;ctrl"
	for var in "cbase" "csurf"; do
	    echo "plotting $var from ${filepre}.nc"
	    ~/base/pypismtools/scripts/basemap-plot.py -v $var --inner_titles $title --colorbar_label -p twocol --singlerow --colormap ~/base/pypismtools/colormaps/Full_saturation_spectrum_CCW_orange.cpt --geotiff_file MODISGreenland1kmclean_cut.tif  -o ${filepre}_${var}.pdf ${filepre}.nc
	done
    done
done

#--geotiff_file MODISGreenland1kmclean_cut.tif
