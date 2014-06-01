#!/bin/bash

# these figures show velocity bins, with coloring by ice thickness,
# where P(W) looks quite different in each bin

# also each bin might be managably small for even 2km Greenland run?

FILENAME=ex_distributed-decoupled.nc
OUTROOT=bar.pdf

./showPvsW.py -wmin 0.0 -wmax 0.15 -c thk -cmin 0 -cmax 2000 -s hydrovelbase_mag -smin 500  -smax 5000 -o bin500-${OUTROOT} $FILENAME
./showPvsW.py -wmin 0.0 -wmax 0.15 -c thk -cmin 0 -cmax 2000 -s hydrovelbase_mag -smin 100  -smax 500  -o bin100-${OUTROOT}  $FILENAME
./showPvsW.py -wmin 0.0 -wmax 0.15 -c thk -cmin 0 -cmax 2000 -s hydrovelbase_mag -smin 30   -smax 100  -o bin30-${OUTROOT}   $FILENAME
./showPvsW.py -wmin 0.0 -wmax 0.15 -c thk -cmin 0 -cmax 2000 -s hydrovelbase_mag -smin 10   -smax 30   -o bin10-${OUTROOT}   $FILENAME
./showPvsW.py -wmin 0.0 -wmax 0.15 -c thk -cmin 0 -cmax 2000 -s hydrovelbase_mag -smin 1    -smax 10   -o bin1-${OUTROOT}    $FILENAME

