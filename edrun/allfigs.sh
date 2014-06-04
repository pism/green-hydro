#!/bin/bash

# generate all figures

./genGreenfig.sh g2km-init Greenland_5km_v1.1
mv -v g2km-init-velbase_mag.png g2km-init-velbase-mag.png
mv -v g2km-init-velsurf_mag.png g2km-init-velsurf-mag.png
mv -v Greenland_5km_v1.1-surfvelmag.png Greenland-surfvelmag.png

./basemapfigs.py routing-decoupled tillwat
./basemapfigs.py routing-decoupled bwat

./basemapfigs.py distributed-decoupled tillwat
./basemapfigs.py distributed-decoupled bwat
./basemapfigs.py distributed-decoupled bwprel

./genscatfig.sh ex_distributed-decoupled.nc g2km.png

rm -rf listpng.txt
ls *.png > listpng.txt

for name in `cat listpng.txt`; do
  echo "autocropping ${name} ..."
  mogrify -trim +repage $name
done

