
 MYSHEBANGLINE="#!/bin/bash"
MYMPIQUEUELINE="#PBS -q transfer"
 MYMPITIMELINE="#PBS -l walltime=2:00:00"
 MYMPISIZELINE="#PBS -l nodes=1:ppn=1"
  MYMPIOUTLINE="#PBS -j oe"

geotiff="--geotiff_file MODISGreenland1kmclean_cut.tif"
#geotiff=""
fluxgates=greenland-flux-gates-250m.shp
res=300
mres=l
fill=-2e9
filepre=g${GRID}m_${EXPERIMENT}

tl_dir=${GRID}m_${CLIMATE}_${TYPE}
nc_dir=processed
fig_dir=figures
spc_dir=speed_contours
pr_dir=profiles

cat - > $POST <<EOF
$MYSHEBANGLINE
$MYMPIQUEUELINE
$MYMPITIMELINE
$MYMPISIZELINE
$MYMPIOUTLINE

source ~/python/bin/activate

cd \$PBS_O_WORKDIR
  
if [ ! -d ${tl_dir} ]; then
    mkdir ${tl_dir}
fi

if [ ! -d ${tl_dir}/${nc_dir} ]; then
    mkdir ${tl_dir}/${nc_dir}
fi

if [ ! -d ${tl_dir}/${fig_dir} ]; then
    mkdir ${tl_dir}/${fig_dir}
fi

if [ ! -d ${tl_dir}/${spc_dir} ]; then
    mkdir ${tl_dir}/${spc_dir}
fi

if [ -f ${filepre}_1.nc ]; then
    # because QGIS doesn't like (x,y) ordering
    sh add_epsg3413_mapping.sh ${filepre}_1.nc
    ncpdq -O -3 -v enthalpy,litho_temp,temp_pa,liqfrac -x -a time,y,x ${filepre}_1.nc ${tl_dir}/${nc_dir}/${filepre}_1.nc
    ncap2 -O -s "velshear_mag=velsurf_mag-velbase_mag; where(thk<50) {velshear_mag=$fill; velbase_mag=$fill; velsurf_mag=$fill; flux_mag=$fill;}; sliding_r = velbase_mag/velsurf_mag; tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag)" ${tl_dir}/${nc_dir}/${filepre}_1.nc ${tl_dir}/${nc_dir}/${filepre}_1.nc
    ncatted -a units,sliding_r,o,c,"1" -a units,tau_r,o,c,"1" -a units,tau_rel,o,c,"1" ${tl_dir}/${nc_dir}/${filepre}_1.nc
fi

if [ -f ${filepre}_2.nc ]; then
    # because QGIS doesn't like (x,y) ordering
    sh add_epsg3413_mapping.sh ${filepre}_2.nc
    ncpdq -O -3 -v enthalpy,litho_temp,temp_pa,liqfrac -x -a time,y,x ${filepre}_2.nc ${tl_dir}/${nc_dir}/${filepre}_2.nc
    ncap2 -O -s "velshear_mag=velsurf_mag-velbase_mag; where(thk<50) {velshear_mag=$fill; velbase_mag=$fill; velsurf_mag=$fill; flux_mag=$fill;}; sliding_r = velbase_mag/velsurf_mag; tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag)" ${tl_dir}/${nc_dir}/${filepre}_2.nc ${tl_dir}/${nc_dir}/${filepre}_2.nc
    ncatted -a units,sliding_r,o,c,"1" -a units,tau_r,o,c,"1" -a units,tau_rel,o,c,"1" ${tl_dir}/${nc_dir}/${filepre}_2.nc
fi

if [ -f ${filepre}_3.nc ]; then
    # because QGIS doesn't like (x,y) ordering
    sh add_epsg3413_mapping.sh ${filepre}_3.nc
    ncpdq -O -3 -v enthalpy,litho_temp,temp_pa,liqfrac -x -a time,y,x ${filepre}_3.nc ${tl_dir}/${nc_dir}/${filepre}_3.nc
    ncap2 -O -s "velshear_mag=velsurf_mag-velbase_mag; where(thk<50) {velshear_mag=$fill; velbase_mag=$fill; velsurf_mag=$fill; flux_mag=$fill;}; sliding_r = velbase_mag/velsurf_mag; tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag)" ${tl_dir}/${nc_dir}/${filepre}_3.nc ${tl_dir}/${nc_dir}/${filepre}_3.nc
    ncatted -a units,sliding_r,o,c,"1" -a units,tau_r,o,c,"1" -a units,tau_rel,o,c,"1" ${tl_dir}/${nc_dir}/${filepre}_3.nc
fi

EOF

cat - > $PLOT <<EOF
$MYSHEBANGLINE
$MYMPIQUEUELINE
$MYMPITIMELINE
$MYMPISIZELINE
$MYMPIOUTLINE

source ~/python/bin/activate

cd \$PBS_O_WORKDIR
  
if [ ! -d ${tl_dir} ]; then
    mkdir ${tl_dir}
fi

if [ ! -d ${tl_dir}/${nc_dir} ]; then
    mkdir ${tl_dir}/${nc_dir}
fi

if [ ! -d ${tl_dir}/${fig_dir} ]; then
    mkdir ${tl_dir}/${fig_dir}
fi

if [ ! -d ${tl_dir}/${spc_dir} ]; then
    mkdir ${tl_dir}/${spc_dir}
fi

if [ -f ${tl_dir}/${nc_dir}/${filepre}_1.nc ]; then
    rm -f ${tl_dir}/${spc_dir}/${filepre}_speed_contours.*
 
    gdal_contour -a speed -fl 100 200 1000 NETCDF:${tl_dir}/${nc_dir}/${filepre}_1.nc:velsurf_mag ${tl_dir}/${spc_dir}/${filepre}_1_speed_contours.shp

    ogr2ogr -overwrite -t_srs EPSG:4326 ${tl_dir}/${spc_dir}/${filepre}_1_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_1_speed_contours_1.shp

    rm -f ${tl_dir}/${spc_dir}/${filepre}_1_speed_contours.*

    basemap-plot.py -v velsurf_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --shape_file greenland_sar_velocities_500m_2005-2009_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_1_speed_contours_epsg4326.shp --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISJakobshavn250m.tif -o ${tl_dir}/${fig_dir}/Jakobshavn_${filepre}_1_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_1.nc

    basemap-plot.py -v velsurf_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --shape_file greenland_sar_velocities_500m_2005-2009_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_1_speed_contours_epsg4326.shp --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISKangerdlugssuaq250m.tif -o ${tl_dir}/${fig_dir}/Kangerdlugssuaq_${filepre}_1_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_1.nc

   basemap-plot.py -v velsurf_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --shape_file greenland_sar_velocities_500m_2005-2009_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_1_speed_contours_epsg4326.shp --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISHelheim250m.tif -o ${tl_dir}/${fig_dir}/Helheim_${filepre}_1_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_1.nc

    basemap-plot.py -v velbase_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISJakobshavn250m.tif -o ${tl_dir}/${fig_dir}/Jakobshavn_${filepre}_1_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_1.nc

    basemap-plot.py -v velbase_mag --inner_titles "$title" --colorbar_label -p medium --singlerow  --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISKangerdlugssuaq250m.tif -o ${tl_dir}/${fig_dir}/Kangerdlugssuaq_${filepre}_1_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_1.nc

    basemap-plot.py -v velbase_mag --inner_titles "$title" --colorbar_label -p medium --singlerow  --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISHelheim250m.tif -o ${tl_dir}/${fig_dir}/Helheim_${filepre}_1_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_1.nc

    basemap-plot.py -v velsurf_mag --inner_titles velsurf_mag --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_1_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_1.nc

    basemap-plot.py -v velbase_mag --inner_titles velbase_mag --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_1_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_1.nc

    basemap-plot.py -v velshear_mag --inner_titles velshear_mag --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_1_velshear_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_1.nc

    basemap-plot.py -v tau_r --inner_titles tau_r --colorbar_label -p medium --singlerow -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_1_tau_r.pdf ${tl_dir}/${nc_dir}/${filepre}_1.nc

    basemap-plot.py -v sliding_r --inner_titles sliding_r --colorbar_label -p medium --singlerow -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_1_sliding_r.pdf ${tl_dir}/${nc_dir}/${filepre}_1.nc

    # create latex file
    rm -f Greenland_${filepre}_1.tex
    cat - > Greenland_${filepre}_1.tex <<EOLF
\documentclass[a4paper,landscape]{article}
\usepackage[margin=2mm,nohead,nofoot]{geometry}
\usepackage{pdfpages}
\usepackage[multidot]{grffile}
\parindent0pt
\\begin{document}
\includepdfmerge[nup=2x3,landscape,pagecommand={\thispagestyle{myheadings}\markright{\huge{$title}}}]{${tl_dir}/${fig_dir}/Greenland_${filepre}_1_velsurf_mag.pdf,1,${tl_dir}/${fig_dir}/Greenland_${filepre}_1_velbase_mag.pdf,${tl_dir}/${fig_dir}/Greenland_${filepre}_1_velshear_mag.pdf,1,${tl_dir}/${fig_dir}/Greenland_${filepre}_1_sliding_r.pdf,1,${tl_dir}/${fig_dir}/Greenland_${filepre}_1_tau_r.pdf,1,${tl_dir}/${fig_dir}/Greenland_${filepre}_1_tau_r.pdf,1}
\end{document}
EOLF
    pdflatex Greenland_${filepre}_1
    rm Greenland_${filepre}_1.tex
    convert -density 400 Greenland_${filepre}_1.pdf -quality 100 ${tl_dir}/${fig_dir}/Greenland_${filepre}_1.png
fi

if [ -f ${tl_dir}/${nc_dir}/${filepre}_2.nc ]; then
    rm -f ${tl_dir}/${spc_dir}/${filepre}_speed_contours.*
 
    gdal_contour -a speed -fl 100 200 1000 NETCDF:${tl_dir}/${nc_dir}/${filepre}_2.nc:velsurf_mag ${tl_dir}/${spc_dir}/${filepre}_2_speed_contours.shp

    ogr2ogr -overwrite -t_srs EPSG:4326 ${tl_dir}/${spc_dir}/${filepre}_2_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_2_speed_contours_2.shp

    rm -f ${tl_dir}/${spc_dir}/${filepre}_2_speed_contours.*

    basemap-plot.py -v velsurf_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --shape_file greenland_sar_velocities_500m_2005-2009_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_2_speed_contours_epsg4326.shp --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISJakobshavn250m.tif -o ${tl_dir}/${fig_dir}/Jakobshavn_${filepre}_2_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_2.nc

    basemap-plot.py -v velsurf_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --shape_file greenland_sar_velocities_500m_2005-2009_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_2_speed_contours_epsg4326.shp --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISKangerdlugssuaq250m.tif -o ${tl_dir}/${fig_dir}/Kangerdlugssuaq_${filepre}_2_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_2.nc

   basemap-plot.py -v velsurf_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --shape_file greenland_sar_velocities_500m_2005-2009_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_2_speed_contours_epsg4326.shp --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISHelheim250m.tif -o ${tl_dir}/${fig_dir}/Helheim_${filepre}_2_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_2.nc

    basemap-plot.py -v velbase_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISJakobshavn250m.tif -o ${tl_dir}/${fig_dir}/Jakobshavn_${filepre}_2_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_2.nc

    basemap-plot.py -v velbase_mag --inner_titles "$title" --colorbar_label -p medium --singlerow  --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISKangerdlugssuaq250m.tif -o ${tl_dir}/${fig_dir}/Kangerdlugssuaq_${filepre}_2_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_2.nc

    basemap-plot.py -v velbase_mag --inner_titles "$title" --colorbar_label -p medium --singlerow  --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISHelheim250m.tif -o ${tl_dir}/${fig_dir}/Helheim_${filepre}_2_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_2.nc

    basemap-plot.py -v velsurf_mag --inner_titles velsurf_mag --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_2_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_2.nc

    basemap-plot.py -v velbase_mag --inner_titles velbase_mag --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_2_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_2.nc

    basemap-plot.py -v velshear_mag --inner_titles velshear_mag --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_2_velshear_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_2.nc

    basemap-plot.py -v tau_r --inner_titles tau_r --colorbar_label -p medium --singlerow -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_2_tau_r.pdf ${tl_dir}/${nc_dir}/${filepre}_2.nc

    basemap-plot.py -v sliding_r --inner_titles sliding_r --colorbar_label -p medium --singlerow -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_2_sliding_r.pdf ${tl_dir}/${nc_dir}/${filepre}_2.nc

    # create latex file
    rm -f Greenland_${filepre}_2.tex
    cat - > Greenland_${filepre}_2.tex <<EOLF
\documentclass[a4paper,landscape]{article}
\usepackage[margin=2mm,nohead,nofoot]{geometry}
\usepackage{pdfpages}
\usepackage[multidot]{grffile}
\parindent0pt
\\begin{document}
\includepdfmerge[nup=2x3,landscape,pagecommand={\thispagestyle{myheadings}\markright{\huge{$title}}}]{${tl_dir}/${fig_dir}/Greenland_${filepre}_2_velsurf_mag.pdf,1,${tl_dir}/${fig_dir}/Greenland_${filepre}_2_velbase_mag.pdf,${tl_dir}/${fig_dir}/Greenland_${filepre}_2_velshear_mag.pdf,1,${tl_dir}/${fig_dir}/Greenland_${filepre}_2_sliding_r.pdf,1,${tl_dir}/${fig_dir}/Greenland_${filepre}_2_tau_r.pdf,1,${tl_dir}/${fig_dir}/Greenland_${filepre}_2_tau_r.pdf,1}
\end{document}
EOLF
    pdflatex Greenland_${filepre}_2
    rm Greenland_${filepre}_2.tex
    convert -density 400 Greenland_${filepre}_2.pdf -quality 100 ${tl_dir}/${fig_dir}/Greenland_${filepre}_2.png
fi

if [ -f ${tl_dir}/${nc_dir}/${filepre}_3.nc ]; then
    rm -f ${tl_dir}/${spc_dir}/${filepre}_speed_contours.*
 
    gdal_contour -a speed -fl 100 200 1000 NETCDF:${tl_dir}/${nc_dir}/${filepre}_3.nc:velsurf_mag ${tl_dir}/${spc_dir}/${filepre}_3_speed_contours.shp

    ogr2ogr -overwrite -t_srs EPSG:4326 ${tl_dir}/${spc_dir}/${filepre}_3_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_3_speed_contours_3.shp

    rm -f ${tl_dir}/${spc_dir}/${filepre}_3_speed_contours.*

    basemap-plot.py -v velsurf_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --shape_file greenland_sar_velocities_500m_2005-2009_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_3_speed_contours_epsg4326.shp --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISJakobshavn250m.tif -o ${tl_dir}/${fig_dir}/Jakobshavn_${filepre}_3_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_3.nc

    basemap-plot.py -v velsurf_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --shape_file greenland_sar_velocities_500m_2005-2009_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_3_speed_contours_epsg4326.shp --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISKangerdlugssuaq250m.tif -o ${tl_dir}/${fig_dir}/Kangerdlugssuaq_${filepre}_3_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_3.nc

   basemap-plot.py -v velsurf_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --shape_file greenland_sar_velocities_500m_2005-2009_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_3_speed_contours_epsg4326.shp --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISHelheim250m.tif -o ${tl_dir}/${fig_dir}/Helheim_${filepre}_3_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_3.nc

    basemap-plot.py -v velbase_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISJakobshavn250m.tif -o ${tl_dir}/${fig_dir}/Jakobshavn_${filepre}_3_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_3.nc

    basemap-plot.py -v velbase_mag --inner_titles "$title" --colorbar_label -p medium --singlerow  --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISKangerdlugssuaq250m.tif -o ${tl_dir}/${fig_dir}/Kangerdlugssuaq_${filepre}_3_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_3.nc

    basemap-plot.py -v velbase_mag --inner_titles "$title" --colorbar_label -p medium --singlerow  --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISHelheim250m.tif -o ${tl_dir}/${fig_dir}/Helheim_${filepre}_3_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_3.nc

    basemap-plot.py -v velsurf_mag --inner_titles velsurf_mag --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_3_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_3.nc

    basemap-plot.py -v velbase_mag --inner_titles velbase_mag --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_3_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_3.nc

    basemap-plot.py -v velshear_mag --inner_titles velshear_mag --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_3_velshear_mag.pdf ${tl_dir}/${nc_dir}/${filepre}_3.nc

    basemap-plot.py -v tau_r --inner_titles tau_r --colorbar_label -p medium --singlerow -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_3_tau_r.pdf ${tl_dir}/${nc_dir}/${filepre}_3.nc

    basemap-plot.py -v sliding_r --inner_titles sliding_r --colorbar_label -p medium --singlerow -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_3_sliding_r.pdf ${tl_dir}/${nc_dir}/${filepre}_3.nc

    # create latex file
    rm -f Greenland_${filepre}_3.tex
    cat - > Greenland_${filepre}_3.tex <<EOLF
\documentclass[a4paper,landscape]{article}
\usepackage[margin=2mm,nohead,nofoot]{geometry}
\usepackage{pdfpages}
\usepackage[multidot]{grffile}
\parindent0pt
\\begin{document}
\includepdfmerge[nup=2x3,landscape,pagecommand={\thispagestyle{myheadings}\markright{\huge{$title}}}]{${tl_dir}/${fig_dir}/Greenland_${filepre}_3_velsurf_mag.pdf,1,${tl_dir}/${fig_dir}/Greenland_${filepre}_3_velbase_mag.pdf,${tl_dir}/${fig_dir}/Greenland_${filepre}_3_velshear_mag.pdf,1,${tl_dir}/${fig_dir}/Greenland_${filepre}_3_sliding_r.pdf,1,${tl_dir}/${fig_dir}/Greenland_${filepre}_3_tau_r.pdf,1,${tl_dir}/${fig_dir}/Greenland_${filepre}_3_tau_r.pdf,1}
\end{document}
EOLF
    pdflatex Greenland_${filepre}_3
    rm Greenland_${filepre}_3.tex
    convert -density 400 Greenland_${filepre}_3.pdf -quality 100 ${tl_dir}/${fig_dir}/Greenland_${filepre}_3.png
fi

EOF
