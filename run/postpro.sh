#!/bin/bash

set -x -e

GRID=5
CLIMATE=$1
TYPE=ctrl
#TYPE=ctrl

PPQ=$2

#geotiff="--geotiff_file MODISGreenland1kmclean_cut.tif"
geotiff=""
res=100
mres=l

hydro=null
for E in 1 2 3 ; do
#    for PPQ in 0.1 0.25 0.33 0.8 ; do
        for TEFO in 0.01 0.02 0.25 0.05 ; do
            filepre=g${GRID}km_${CLIMATE}_${TYPE}_e_${E}_ppq_${PPQ}_tefo_${TEFO}_hydro_null
	    if [ -f ${filepre}.nc ]; then
		# because QGIS doesn't like (x,y) ordering
 		ncpdq -O -a time,y,x,z,zb ${filepre}.nc ${filepre}.nc
                ncap2 -O -s "tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag)" ${filepre}.nc ${filepre}.nc
                ncatted -a units,tau_rel,o,c,"1" ${filepre}.nc
                # remove files, gdal_contour can't overwrite?
                if [ -f speed_contours/${filepre}_speed_contours.shp ]; then
                    rm speed_contours/${filepre}_speed_contours.*
                fi
                gdal_contour -a speed -fl 100 200 1000 NETCDF:${filepre}.nc:velsurf_mag speed_contours/${filepre}_speed_contours.shp
                ogr2ogr -overwrite -t_srs EPSG:4326 speed_contours/${filepre}_speed_contours_epsg4326.shp speed_contours/${filepre}_speed_contours.shp
                title="q=$q;"'$\delta$'"=$delta;"'$\phi_{l}$'"=$philow"'$\omega$'"=$omega;"'$\mu$'"=$mu;"'$c_1$'"=$open;"'$c_2$'"=$close;k=$cond"
                for glacier in "Jakobshavn" "Kangerdlugssuaq"; do
                    var=velsurf_mag
 		    basemap-plot.py -v $var --inner_titles $var --colorbar_label -p medium --singlerow --shape_file ~/data/data_sets/GreenlandSAR/surf_vels_mag_contours_epsg4326.shp speed_contours/${filepre}_speed_contours_epsg4326.shp --colormap ~/base/pypismtools/colormaps/Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution l --geotiff_file MODIS${glacier}1km.tif -o ${glacier}_${filepre}_${var}.pdf ${filepre}.nc
                done
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
#    done
done
exit
