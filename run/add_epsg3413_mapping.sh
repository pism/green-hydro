#!/bin/bash

# Copyright (C) 2014 Andy Aschwanden

# add EPSG:3413 mapping information
set -e -x  # exit on error

file="$1"

ncatted -O -a grid_mapping_name,mapping,o,c,"polar_stereographic" -a latitude_of_projection_origin,mapping,o,f,90. -a straight_vertical_longitude_from_pole,mapping,o,f,-45. -a standard_parallel,mapping,o,f,70. -a false_easting,mapping,o,f,0. -a false_northing,mapping,o,f,0. $file
