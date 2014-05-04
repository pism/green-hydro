

SCRIPT=do_g${GRID}km_${EXPERIMENT}_post.sh
rm -f $SCRIPT

 MYSHEBANGLINE="#!/bin/bash"
MYMPIQUEUELINE="#PBS -q shared"
 MYMPITIMELINE="#PBS -l walltime=12:00:00"
 MYMPISIZELINE="#PBS -l nodes=1:ppn=1"
  MYMPIOUTLINE="#PBS -j oe"

geotiff="--geotiff_file MODISGreenland1kmclean_cut.tif"
#geotiff=""
res=300
mres=l
fill=-2e9
filepre=g${GRID}km_${EXPERIMENT}

nc_dir=processed
if [ ! -d $nc_dir ]; then
    mkdir $nc_dir
fi

fig_dir=figures
if [ ! -d $fig_dir ]; then
    mkdir $fig_dir
fi

spc_dir=speed_contours
if [ ! -d $spc_dir ]; then
    mkdir $spc_dir
fi

cat - > $SCRIPT <<EOF

$MYSHEBANGLINE
$MYMPIQUEUELINE
$MYMPITIMELINE
$MYMPISIZELINE
$MYMPIOUTLINE

source ~/python/bin/activate

cd \$PBS_O_WORKDIR
  
if [ ! -d $nc_dir ]; then
    mkdir $nc_dir
fi

if [ ! -d $fig_dir ]; then
    mkdir $fig_dir
fi

if [ ! -d $spc_dir ]; then
    mkdir $spc_dir
fi


if [ -f ${filepre}.nc ]; then
    # because QGIS doesn't like (x,y) ordering
    ncpdq -O -a time,y,x,z,zb ${filepre}.nc ${nc_dir}/${filepre}.nc
    ncap2 -O -s "where(thk<25) {velbase_mag=$fill; velsurf_mag=$fill; flux_mag=$fill;}; tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag)" ${nc_dir}/${filepre}.nc ${nc_dir}/${filepre}.nc
    ncatted -a units,tau_rel,o,c,"1" ${nc_dir}/${filepre}.nc
    # remove files, gdal_contour can't overwrite?
    if [ -f ${spc_dir}/${filepre}_speed_contours.shp ]; then
        rm ${spc_dir}/${filepre}_speed_contours.*
    fi

    gdal_contour -a speed -fl 100 200 1000 NETCDF:${nc_dir}/${filepre}.nc:velsurf_mag ${spc_dir}/${filepre}_speed_contours.shp

    ogr2ogr -overwrite -t_srs EPSG:4326 ${spc_dir}/${filepre}_speed_contours_epsg4326.shp ${spc_dir}/${filepre}_speed_contours.shp

    basemap-plot.py -v velsurf_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --shape_file surf_vels_mag_contours_epsg4326.shp ${spc_dir}/${filepre}_speed_contours_epsg4326.shp --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISJakobshavn1km.tif -o ${fig_dir}/Jakobshavn_${filepre}_velsurf_mag.pdf ${nc_dir}/${filepre}.nc

    basemap-plot.py -v velsurf_mag --inner_titles "$title" --colorbar_label -p medium --singlerow --shape_file surf_vels_mag_contours_epsg4326.shp ${spc_dir}/${filepre}_speed_contours_epsg4326.shp --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res --map_resolution $mres --geotiff_file MODISKangerdlugssuaq1km.tif -o ${fig_dir}/Kangerdlugssuaq_${filepre}_velsurf_mag.pdf ${nc_dir}/${filepre}.nc

    basemap-plot.py -v velsurf_mag --inner_titles velsurf_mag --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res  $geotiff -o ${fig_dir}/Greenland_${filepre}_velsurf_mag.pdf ${nc_dir}/${filepre}.nc

    basemap-plot.py -v velbase_mag --inner_titles velsurf_mag --colorbar_label -p medium --singlerow --colormap Full_saturation_spectrum_CCW_orange.cpt -r $res  $geotiff -o ${fig_dir}/Greenland_${filepre}_velbase_mag.pdf ${nc_dir}/${filepre}.nc

    basemap-plot.py -v tau_r --inner_titles tau_r --colorbar_label -p medium --singlerow -r $res  $geotiff -o ${fig_dir}/Greenland_${filepre}_tau_r.pdf ${nc_dir}/${filepre}.nc

    # create latex file
    rm -f Greenland_${filepre}.tex
    cat - > Greenland_${filepre}.tex <<EOLF
\documentclass[a4paper]{article}
\usepackage[margin=2mm,nohead,nofoot]{geometry}
\usepackage{pdfpages}
\usepackage[multidot]{grffile}
\parindent0pt
\\begin{document}
\includepdfmerge[nup=1x3,pagecommand={\thispagestyle{myheadings}\markright{\huge{$title}}}]{${fig_dir}/Greenland_${filepre}_velsurf_mag.pdf,1,${fig_dir}/Greenland_${filepre}_velbase_mag.pdf,1,${fig_dir}/Greenland_${filepre}_tau_r.pdf,1}
\end{document}
EOLF
    pdflatex Greenland_${filepre}
    rm Greenland_${filepre}.tex
    convert -density 400 Greenland_${filepre}.pdf -quality 100 ${fig_dir}/Greenland_${filepre}.png
fi

EOF

 echo "$SCRIPT written"
