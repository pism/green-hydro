#!/bin/bash

set -x -e

GRID=10
CLIMATE=paleo
TYPE=ctrl
#TYPE=ctrl

#geotiff="--geotiff_file MODISGreenland1kmclean_cut.tif"
geotiff=""
res=100
mres=l

hydro=null
for E in 1 2 3 ; do
    for PPQ in 0.1 0.25 0.33 0.8 ; do
        for TEFO in 0.01 0.02 0.25 0.05 ; do
                                    filepre=g${GRID}km_${CLIMATE}_${TYPE}_ppq_${PPQ}_tefo_${TEFO}_hydro_null
		                    if [ -f ${filepre}.nc ]; then
		                        # because QGIS doesn't like (x,y) ordering
 		                        ncpdq -O -a time,y,x,z,zb ${filepre}.nc ${filepre}.nc
                                        ncap2 -O -s "tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag)" ${Filepre}.nc ${filepre}.nc
                                        ncatted -a units,tau_rel,o,c,"1" ${filepre}.nc
                                        title="q=$q;"'$\delta$'"=$delta;"'$\phi_{l}$'"=$philow"'$\omega$'"=$omega;"'$\mu$'"=$mu;"'$c_1$'"=$open;"'$c_2$'"=$close;k=$cond"
                                        for var in  "velbase_mag" "velsurf_mag"; do
 			                    echo "plotting $var from ${filepre}.nc"
 			                    basemap-plot.py -v $var --inner_titles $var --colorbar_label -p medium --singlerow --colormap ~/base/pypismtools/colormaps/Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --coastlines $geotiff -o ${filepre}_${var}.pdf ${filepre}.nc
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
\includepdfmerge[nup=2x2,landscape,pagecommand={\thispagestyle{myheadings}\markright{\huge{$title}}}]{${filepre}_velsurf_mag.pdf,1,${filepre}_velbase_mag.pdf,1,${filepre}_tau_rel.pdf,1,${filepre}_tau_r.pdf,1}
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
