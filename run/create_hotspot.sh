#!/bin/bash

# Produces geothermal hot spot in variable bheatflx in SeaRISE-Greenland data.

# Version 2:  instead of circular hot blob near divide, an elliptical blob
#   along the NE Greenland ice stream route; the ends of the long, narrow
#   ellipse were eye-balled to be at the original center (-32000m, -1751180m)
#   and at (103000m,-1544330) (in projection coords used by SeaRISE)
# here are relevant octave computations:
# > 0.5*(-32000+103000)
# ans =  35500  # x coord of new center
# > 0.5*(-1751180 + -1544330)
# ans = -1647755  # y coord center
# > theta = atan( (-1544330 - (-1647755)) / (103000 - 35500) )
# theta =  0.99256  # rotation angle; = 56.9 deg
# > cos(theta)
# ans =  0.54655
# > sin(theta)
# ans =  0.83743
# > a = sqrt( (103000 - 35500)^2 +  (-1544330 - (-1647755))^2 )
# a =  1.2350e+05
# > b = 50000^2 / a  #  set b so that ab=R^2 where R = 50 km is orig radius
# b =  2.0242e+04

# Version 1:  The spot is at the
# source area of the NE Greenland ice stream.  The spot has the location,
# magnitude and extent suggested by
#    M. Fahnestock, et al (2001).  High geothermal heat flow, basal melt, and 
#    the origin of rapid ice flow in central Greenland, Science vol 294, 2338--2342.
# Uses NCO (ncrename, ncap2, ncks, ncatted).
# Run preprocess.py first to generate $PISMVERSION.
# center of hot spot is  (-40 W lon, 74 deg N lat)  which is
#   (x,y) = (-32000m, -1751180m)  in projection already used in $DATANAME
# parameters: radius of spot = 50000m and heat is 970 mW m-2 from Fahnstock et al 2001

set -e  # exit on error

NN=1  # default no of processors
if [ $# -gt 0 ] ; then
  NN="$1"
fi

GRID=5  # default grid resolution in km
if [ $# -gt 1 ] ; then
  GRID="$2"
fi

DATANAME=Greenland_${GRID}km_v2_ctrl
if [ $# -gt 2 ] ; then
  DATANME="$3"
fi
PISMVERSION=pism_${DATANAME}.nc

OUTNAME=pism_${DATANAME}_970mW_hs.nc
if [ $# -gt 3 ] ; then
  OUTNAME="$4"
fi

cp $PISMVERSION $OUTNAME

# center:
XSPOT=35500
NEGYSPOT=1647755

# parameters for ellipse and rotation in m and heat to apply there
ASPOT=123500
BSPOT=20242
COSTHETA=0.54655
SINTHETA=0.83743

GHFSPOT=0.970   # from Fahnstock et al 2001; in W m-2

ncrename -v bheatflx,bheatflxSR $OUTNAME  # keep Shapiro & Ritzwoller

# do equivalent of Matlab's:  [xx,yy] = meshgrid(x,y)
ncap2 -t $NN -O -s 'zero=0.0*lat' $OUTNAME $OUTNAME # note lat=lat(x,y)
ncap2 -t $NN -O -s 'xx=zero+x' $OUTNAME $OUTNAME
ncap2 -t $NN -O -s 'yy=zero+y' $OUTNAME $OUTNAME
XIROT="xi=${COSTHETA}*(xx-${XSPOT})+${SINTHETA}*(yy+${NEGYSPOT})"
ncap2 -t $NN -O -s $XIROT $OUTNAME $OUTNAME
ETAROT="eta=-${SINTHETA}*(xx-${XSPOT})+${COSTHETA}*(yy+${NEGYSPOT})"
ncap2 -t $NN -O -s $ETAROT $OUTNAME $OUTNAME

# filled ellipse is:   xi^2/a^2 + eta^2/b^2 < 1
ELLLEFT="eleft=(xi*xi)/(${ASPOT}*${ASPOT})"
ncap2 -t $NN -O -s $ELLLEFT $OUTNAME $OUTNAME
ELLRIGHT="eright=(eta*eta)/(${BSPOT}*${BSPOT})"
ncap2 -t $NN -O -s $ELLRIGHT $OUTNAME $OUTNAME
ncap2 -t $NN -O -s 'hotmask=(-eleft+eright-1<0)' $OUTNAME $OUTNAME

# actually create hot spot
NEWBHEATFLX="bheatflx=hotmask*${GHFSPOT}+!hotmask*bheatflxSR"
ncap2 -t $NN -O -s $NEWBHEATFLX $OUTNAME $OUTNAME

# ncap2 leaves hosed attributes; start over
ncatted -a ,bheatflx,d,, $OUTNAME   # delete all attributes
ncatted -a units,bheatflx,c,c,"mW m-2" $OUTNAME
ncatted -a long_name,bheatflx,c,c,"basal geothermal flux" $OUTNAME
ncatted -a propose_standard_name,bheatflx,c,c,"lithosphere_upward_heat_flux" $OUTNAME

# clear out the temporary variables and only leave additional 'bheatflxSR'
ncks -O -x -v xx,yy,xi,eta,eleft,eright,hotmask,zero,bheatflxSR $OUTNAME $OUTNAME

echo "PISM-readable file '$OUTNAME' created from '$PISMVERSION':"
echo "  * variable 'bheatflxSR' is copy of 'bheatflx' from '$PISMVERSION'"
echo "  * variable 'bheatflx' has added hot spot near source of NE Greenland ice stream:"
echo "      center: (74 deg N lat, -40 W lon)"
echo "      radius: $RSPOT m"
echo "      value : $GHFSPOT mW m-2"
echo "  * reference for hot spot is"
echo "      M. Fahnestock, et al (2001).  High geothermal heat flow, basal melt, and"
echo "      the origin of rapid ice flow in central Greenland, Science vol 294, 2338--2342."
