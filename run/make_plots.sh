#!/bin/bash

set -x -e

GRID=10
CLIMATE=pdd
TYPE=970mW_hs
#TYPE=ctrl

#geotiff="--geotiff_file MODISGreenland1kmclean_cut.tif"
geotiff=""
res=100
mres=l

hydro=distributed
for q in 0.25; do
    for delta in 0.02; do
        for philow in 5 10 15; do
            for mu in 1e-6; do
                for omega in 100 1000; do
                    for open in 0.5; do
                        for close in 0.04; do
                            for cond in 0.0001 0.001 0.01; do
#                                for addbwat in "_lnbwat" "" "_addbwat"; do
                                for addbwat in "_lnbwat"; do
                                    filepre=g${GRID}km_${CLIMATE}_${TYPE}_ppq_${q}_tefo_${delta}_philow_${philow}_rate_${mu}_prop_${omega}_open_${open}_close_${close}_cond_${cond}_hydro_${hydro}${addbwat}
		                    if [ -f ${filepre}.nc ]; then
		                        # because QGIS doesn't like (x,y) ordering
 		                        ncpdq -O -a time,y,x,z,zb ${filepre}.nc ${filepre}.nc
                                        ncap2 -O -s "taub_mag = tauc*cbase/(100^$q*cbase^(1-$q)); tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag)" ${filepre}.nc ${filepre}.nc
                                        ncatted -a units,tau_rel,o,c,"1" ${filepre}.nc
                                        title="q=$q;"'$\delta$'"=$delta;"'$\phi_{l}$'"=$philow"'$\omega$'"=$omega;"'$\mu$'"=$mu;"'$c_1$'"=$open;"'$c_2$'"=$close;k=$cond"
                                        for var in  "cbase" "csurf"; do
 			                    echo "plotting $var from ${filepre}.nc"
 			                    basemap-plot.py -v $var --inner_titles $var --colorbar_label -p medium --singlerow --colormap ~/base/pypismtools/colormaps/Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --coastlines $geotiff -o ${filepre}_${var}.pdf ${filepre}.nc
                                        done
                                        for var in  "bwat" "tillwat"; do
 			                    echo "plotting $var from ${filepre}.nc"
 			                    basemap-plot.py -v $var --inner_titles $var --colorbar_label -p medium --singlerow -r $res --map_resolution $mres --coastlines $geotiff -o ${filepre}_${var}.pdf ${filepre}.nc
                                        done
                                        for var in  "tau_r"; do
 			                    echo "plotting $var from ${filepre}.nc"
 			                    basemap-plot.py -v $var --inner_titles $var --colorbar_label -p medium --singlerow -r $res --map_resolution $mres --coastlines $geotiff -o ${filepre}_${var}.pdf ${filepre}.nc
                                        done
                                        for var in "tau_rel"; do
 			                    echo "plotting $var from ${filepre}.nc"
 			                    basemap-plot.py -v $var --inner_titles $var -p medium --singlerow -r $res --map_resolution $mres --coastlines $geotiff -o ${filepre}_${var}.pdf ${filepre}.nc
                                        done
                                        # create latex file
                                        FILE=${filepre}.tex
                                        rm -f $FILE
                                        cat - > $FILE <<EOF
\documentclass[a4paper,landscape]{article}
\usepackage[margin=2mm,nohead,nofoot]{geometry}
\usepackage{pdfpages}
\usepackage[multidot]{grffile}
\parindent0pt
\\begin{document}
\includepdfmerge[nup=3x2,landscape,pagecommand={\thispagestyle{myheadings}\markright{\huge{$title}}}]{${filepre}_csurf.pdf,1,${filepre}_cbase.pdf,1,${filepre}_bwat.pdf,1,${filepre}_tillwat.pdf,1,${filepre}_tau_rel.pdf,1,${filepre}_tau_r.pdf,1}
\end{document}
EOF
                                        pdflatex $FILE
                                        rm $FILE
                                        convert -density 400 ${filepre}.pdf -quality 100 ${filepre}.png
		                    else
		                        echo "file ${filepre}.nc does not exist, skipping"
		                    fi
                                done
                            done
                        done
                    done
                done
            done
        done
    done
done
exit
