#!/bin/bash

set -e  # exit on error

ncap2 -O -s 'where(bmelt<0.001) bmelt=-1.0;' g5km_gridseq.nc g5km-init.nc

