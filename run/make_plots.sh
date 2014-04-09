#!/bin/bash

set -x -e

GRID=10
CLIMATE=pdd
TYPE=970mW_hs
#geotiff="--geotiff_file MODISGreenland1kmclean_cut.tif"
geotiff=""
res=100

hydro=distributed
for q in 0.25; do
    for delta in 0.02; do
        for mu in 1e-6; do
            for omega in 100 500 1000; do
                for open in 0.4 0.5 0.6; do
                    for close in 0.03 0.04 0.05; do
                        filepre=g${GRID}km_${CLIMATE}_${TYPE}_${q}_${delta}_${mu}_${omega}_${open}_${close}_${hydro}
		        if [ -f ${filepre}.nc ]; then
		            # because QGIS doesn't like (x,y) ordering
		            ncpdq -O -a time,y,x,z,zb ${filepre}.nc ${filepre}.nc
                            title="q=$q;"'$\delta$'"=$delta;"'$\omega$'"=$omega;"'$\mu$'"=$mu,"'$c_1$'"=$open;"'$c_2$'"=$close"
                            for var in  "cbase" "csurf"; do
			        echo "plotting $var from ${filepre}.nc"
			        ~/base/pypismtools/scripts/basemap-plot.py -v $var --inner_titles $var --colorbar_label -p medium --singlerow --colormap ~/base/pypismtools/colormaps/Full_saturation_spectrum_CCW_orange.cpt -r $res $geotiff -o ${filepre}_${var}.pdf ${filepre}.nc
                            done
                            for var in  "bwat" "tillwat"; do
			        echo "plotting $var from ${filepre}.nc"
			        ~/base/pypismtools/scripts/basemap-plot.py -v $var --inner_titles $var --colorbar_label -p medium --singlerow -r $res $geotiff -o ${filepre}_${var}.pdf ${filepre}.nc
                            done
                            # create latex file
                            FILE=${filepre}.tex
                            rm -f $FILE
                            cat - > $FILE <<EOF
\documentclass[a4paper]{article}
\usepackage[margin=0mm,nohead,nofoot]{geometry}
\usepackage{pdfpages}
\usepackage[multidot]{grffile}
\parindent0pt
\\begin{document}
\includepdfmerge[nup=2x2,pagecommand={\thispagestyle{myheadings}\markright{\Huge{$title}}}]{${filepre}_csurf.pdf,1,${filepre}_cbase.pdf,1,${filepre}_bwat.pdf,1,${filepre}_tillwat.pdf,1}
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
            done
        done
    done
done

exit

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
			~/base/pypismtools/scripts/basemap-plot.py -v $var --inner_titles $var --colorbar_label -p medium --singlerow --colormap ~/base/pypismtools/colormaps/Full_saturation_spectrum_CCW_orange.cpt -r $res $geotiff -o ${filepre}_${var}.pdf ${filepre}.nc
                    done
                    for var in  "bwat" "tillwat"; do
			echo "plotting $var from ${filepre}.nc"
			~/base/pypismtools/scripts/basemap-plot.py -v $var --inner_titles $var --colorbar_label -p medium --singlerow -r $res $geotiff -o ${filepre}_${var}.pdf ${filepre}.nc
                    done
                    # create latex file
                    FILE=${filepre}.tex
                    rm -f $FILE
                    cat - > $FILE <<EOF
\documentclass[a4paper]{article}
\usepackage[margin=0mm,nohead,nofoot]{geometry}
\usepackage{pdfpages}
\usepackage[multidot]{grffile}
\parindent0pt
\\begin{document}
\includepdfmerge[nup=2x2,pagecommand={\thispagestyle{myheadings}\markright{\Huge{$title}}}]{${filepre}_csurf.pdf,1,${filepre}_cbase.pdf,1,${filepre}_bwat.pdf,1,${filepre}_tillwat.pdf,1}
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
	    ncpdq -O -a time,y,x,z,zb ${filepre}.nc ${filepre}.nc
            title="q=$q;"'$\delta$'"=$delta;ctrl"
            for var in "cbase" "csurf"; do
		echo "plotting $var from ${filepre}.nc"
		~/base/pypismtools/scripts/basemap-plot.py -v $var --inner_titles $title --colorbar_label -p medium --singlerow --colormap ~/base/pypismtools/colormaps/Full_saturation_spectrum_CCW_orange.cpt -r $res $geotiff  -o ${filepre}_${var}.pdf ${filepre}.nc
            done
	else
	    echo "file ${filepre}.nc does not exist, skipping"
	fi
    done
done

#--geotiff_file MODISGreenland1kmclean_cut.tif
