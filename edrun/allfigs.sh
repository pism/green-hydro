#!/bin/bash

# generate all figures

./genGreenfig.sh g2km-init Greenland_5km_v1.1
mv -v g2km-init-velbase_mag.png g2km-init-velbase-mag.png
mv -v g2km-init-velsurf_mag.png g2km-init-velsurf-mag.png
mv -v Greenland_5km_v1.1-surfvelmag.png Greenland-surfvelmag.png

./basemapfigs.py routing-decoupled bwat
./basemapfigs.py distributed-decoupled bwat
./basemapfigs.py distributed-decoupled bwprel
./genscatfig.sh ex_distributed-decoupled.nc g2km.png

for name in distributed-decoupled-bwprel.png distributed-decoupled-bwat.png routing-decoupled-bwat.png g2km-init-bmelt.png g2km-init-velbase-mag.png g2km-init-velsurf-mag.png Greenland-surfvelmag.png; do
  echo "autocropping ${name} ..."
  mogrify -trim +repage $name
done
