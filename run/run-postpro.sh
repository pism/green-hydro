
 MYSHEBANGLINE="#!/bin/bash"
MYMPIQUEUELINE="#PBS -q transfer"
 MYMPITIMELINE="#PBS -l walltime=12:00:00"
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

if [ -f ${filepre}.nc ]; then
    # because QGIS doesn't like (x,y) ordering
    sh add_epsg3413_mapping.sh ${filepre}.nc
    ncpdq -O -v enthalpy,litho_temp,temp_pa,liqfrac -x -a time,y,x ${filepre}.nc ${tl_dir}/${nc_dir}/${filepre}.nc
    ncap2 -O -s "where(thk<1) {velbase_mag=$fill; velsurf_mag=$fill; flux_mag=$fill;}; tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag)" ${tl_dir}/${nc_dir}/${filepre}.nc ${tl_dir}/${nc_dir}/${filepre}.nc
    ncatted -a units,tau_rel,o,c,"1" ${tl_dir}/${nc_dir}/${filepre}.nc
    extract-profiles.py $fluxgates ${filepre}.nc ${tl_dir}/${pr_dir}/profiles_${filepre}.nc
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
if [ -f ${tl_dir}/${nc_dir}/${filepre}.nc ]; then
    rm -f ${tl_dir}/${spc_dir}/${filepre}_speed_contours.*
 
    gdal_contour -a speed -fl 100 200 1000 NETCDF:${tl_dir}/${nc_dir}/${filepre}.nc:velsurf_mag ${tl_dir}/${spc_dir}/${filepre}_speed_contours.shp

    ogr2ogr -overwrite -t_srs EPSG:4326 ${tl_dir}/${spc_dir}/${filepre}_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_speed_contours.shp

    rm -f ${tl_dir}/${spc_dir}/${filepre}_speed_contours.*

    basemap-plot.py -v velsurf_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --shape_file greenland_sar_velocities_500m_2005-2009_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_speed_contours_epsg4326.shp --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISJakobshavn250m.tif -o ${tl_dir}/${fig_dir}/Jakobshavn_${filepre}_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}.nc

    basemap-plot.py -v velsurf_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --shape_file greenland_sar_velocities_500m_2005-2009_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_speed_contours_epsg4326.shp --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISKangerdlugssuaq250m.tif -o ${tl_dir}/${fig_dir}/Kangerdlugssuaq_${filepre}_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}.nc

   basemap-plot.py -v velsurf_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --shape_file greenland_sar_velocities_500m_2005-2009_speed_contours_epsg4326.shp ${tl_dir}/${spc_dir}/${filepre}_speed_contours_epsg4326.shp --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISHelheim250m.tif -o ${tl_dir}/${fig_dir}/Helheim_${filepre}_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}.nc

    basemap-plot.py -v velbase_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISJakobshavn250m.tif -o ${tl_dir}/${fig_dir}/Jakobshavn_${filepre}_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}.nc

    basemap-plot.py -v velbase_mag --inner_titles "$title" --colorbar_label -p medium --singlerow  --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISKangerdlugssuaq250m.tif -o ${tl_dir}/${fig_dir}/Kangerdlugssuaq_${filepre}_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}.nc

    basemap-plot.py -v velbase_mag --inner_titles "$title" --colorbar_label -p medium --singlerow  --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISHelheim250m.tif -o ${tl_dir}/${fig_dir}/Helheim_${filepre}_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}.nc

    basemap-plot.py -v velsurf_mag --inner_titles velsurf_mag --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_velsurf_mag.pdf ${tl_dir}/${nc_dir}/${filepre}.nc

    basemap-plot.py -v velbase_mag --inner_titles velsurf_mag --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_velbase_mag.pdf ${tl_dir}/${nc_dir}/${filepre}.nc

    basemap-plot.py -v tau_r --inner_titles tau_r --colorbar_label -p medium --singlerow -r $res  $geotiff -o ${tl_dir}/${fig_dir}/Greenland_${filepre}_tau_r.pdf ${tl_dir}/${nc_dir}/${filepre}.nc

    # create latex file
    rm -f Greenland_${filepre}.tex
    cat - > Greenland_${filepre}.tex <<EOLF
\documentclass[a4paper,landscape]{article}
\usepackage[margin=2mm,nohead,nofoot]{geometry}
\usepackage{pdfpages}
\usepackage[multidot]{grffile}
\parindent0pt
\\begin{document}
\includepdfmerge[nup=1x3,landscape,pagecommand={\thispagestyle{myheadings}\markright{\huge{$title}}}]{${tl_dir}/${fig_dir}/Greenland_${filepre}_velsurf_mag.pdf,1,${tl_dir}/${fig_dir}/Greenland_${filepre}_velbase_mag.pdf,1,${tl_dir}/${fig_dir}/Greenland_${filepre}_tau_r.pdf,1}
\end{document}
EOLF
    pdflatex Greenland_${filepre}
    rm Greenland_${filepre}.tex
    convert -density 400 Greenland_${filepre}.pdf -quality 100 ${tl_dir}/${fig_dir}/Greenland_${filepre}.png
fi

EOF
