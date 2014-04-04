#!/bin/bash

set -x

GRID=10
CLIMATE=pdd
TYPE=970mW_hs

for q in 0.1 0.25 0.8; do
    for delta in 0.01 0.02 0.05; do
        for mu in 1e-5 5e-5 1e-6; do
            for omega in 1 10 100 1000; do
                filepre=g${GRID}km_${CLIMATE}_${TYPE}_${q}_${delta}_${mu}_${omega}
		if [ -f ${filepre}.nc ]; then
		    # because QGIS doesn't like (x,y) ordering
		    ncpdq -O -a time,y,x,z,zb ${filepre}.nc ${filepre}.nc
                    title="q=$q;"'$\delta$'"=$delta;"'$\omega$'"=$omega;"'$\mu$'"=$mu"
                    for var in  "cbase" "csurf"; do
			echo "plotting $var from ${filepre}.nc"
			~/base/pypismtools/scripts/basemap-plot.py -v $var --inner_titles $title --colorbar_label -p twocol --singlerow --colormap ~/base/pypismtools/colormaps/Full_saturation_spectrum_CCW_orange.cpt --geotiff_file MODISGreenland1kmclean_cut.tif -o ${filepre}_${var}.pdf ${filepre}.nc
                    done
                    for var in  "bwat"; do
			echo "plotting $var from ${filepre}.nc"
			~/base/pypismtools/scripts/basemap-plot.py -v $var --inner_titles $title --colorbar_label -p twocol --singlerow --geotiff_file MODISGreenland1kmclean_cut.tif -o ${filepre}_${var}.pdf ${filepre}.nc
                    done
                    # create latex file
                    FILE=${filepre}.tex
                    rm -f $FILE
                    cat - > $FILE <<EOF
\documentclass[a4paper]{article}
\usepackage[margin=0mm,nohead,nofoot]{geometry}
\usepackage{pdfpages}
\usepackage[multidot]{grffile}
\pagestyle{empty}
\parindent0pt
\\begin{document}
\includepdfmerge[nup=1x3,landscape]{${filepre}_csurf.pdf,1,${filepre}_cbase.pdf,1,${filepre}_bwat.pdf,1}
\end{document}
EOF
                    pdflatex $FILE
                    rm $FILE
                    mv ${filepre}.pdf ${filepre}_combined.pdf
		else
		    echo "file ${filepre}.nc does not exist, skipping"
		fi
            done
        done
        filepre=g${GRID}km_${CLIMATE}_${TYPE}_${q}_${delta}_hydro_null
	if [ -f ${filepre}.nc ]; then
	    ncpqdq -O -a time,y,x,z,zb ${filepre}.nc ${filepre}.nc
            title="q=$q;"'$\delta$'"=$delta;ctrl"
            for var in "cbase" "csurf"; do
		echo "plotting $var from ${filepre}.nc"
		~/base/pypismtools/scripts/basemap-plot.py -v $var --inner_titles $title --colorbar_label -p twocol --singlerow --colormap ~/base/pypismtools/colormaps/Full_saturation_spectrum_CCW_orange.cpt --geotiff_file MODISGreenland1kmclean_cut.tif  -o ${filepre}_${var}.pdf ${filepre}.nc
            done
	else
	    echo "file ${filepre}.nc does not exist, skipping"
	fi
    done
done

#--geotiff_file MODISGreenland1kmclean_cut.tif
