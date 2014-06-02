#!/usr/bin/env python
try:
    from netCDF3 import Dataset as CDF
except:
    from netCDF4 import Dataset as CDF
from argparse import ArgumentParser


# Set up the Argument parser
description = '''A script to add EPSG:3413 mapping information to a netCDF file.'''
parser = ArgumentParser()
parser.description = description
parser.add_argument("FILE", nargs='*')
options = parser.parse_args()
args = options.FILE

infile = args[0]

nc = CDF(infile, 'a')


mapping_var = 'mapping'
for var in nc.variables.keys():
    if hasattr(var, 'grid_mapping'):
        mapping_var = var.grid_mapping
        pass

if not var in nc.variables.keys():
    mapping = nc.createVariable(mapping_var, 'b')

else:
    mapping = nc.variables[mapping_var]
mapping.grid_mapping_name = "polar_stereographic"
mapping.latitude_of_projection_origin = 90.
mapping.straight_vertical_longitude_from_pole = -45.0
mapping.standard_parallel = 70.0
mapping.false_easting = 0.
mapping.false_northing = 0.
mapping.units = "m"


# Save the projection information:
nc.proj4 = "+init=epsg:3413"

nc.Conventions = "CF-1.6"

script_command = ' '.join([time.ctime(), ':', __file__.split('/')[-1]])
nc.history = script_command
print "writing to %s ...\n" % output
print "run nc2cdo.py to add lat/lon variables" 
nc.close()
