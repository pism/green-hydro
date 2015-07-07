#!/usr/bin/env python

# Copyright (C) 2011-2015 Andy Aschwanden

import netCDF4 as netCDF
NC = netCDF.Dataset
from netcdftime import utime
import dateutil
import numpy as np
from datetime import datetime, timedelta
from argparse import ArgumentParser

# Set up the option parser
parser = ArgumentParser()
parser.description = "Script adds ocean forcing to HIRHAM atmosphere/surface forcing file. Sets a constant, spatially-uniform basal melt rate of b_a before time t_a, and b_e after time t_a."
parser.add_argument("FILE", nargs='*')
parser.add_argument("-a",dest="b_a",
                    help="basal melt rate until t_a, in kg m-2 s-1",default=228e3*0.91)
parser.add_argument("-e",dest="b_e",
                    help="basal melt rate from t_e on, in kg m-2 s-1",default=285e3*0.91)
parser.add_argument("--ta",dest="t_a",
                  help="time t_e, udunits string, e.g. 1989-1-1",default="1997-1-31")

# From Motyka et al (2011)
# melt rates increased by 25% from 228 m/yr to 285 m/yr

options = parser.parse_args()
args = options.FILE

b_a = options.b_a
b_e = options.b_e
t_a = str(options.t_a)

infile = args[0]

nc = NC(infile,'a')
time = nc.variables["time"]
time_units = time.units
time_calendar = time.calendar

cdftime = utime(time_units, time_calendar)
dates = cdftime.num2date(time[:])
# cdftime returns a phony object for non-real calendars
if time_calendar in ("365_day", "366_day"):
    dates = np.array([dateutil.parser.parse(x.strftime()) for x in dates])

acab = nc.variables["climatic_mass_balance"]
bmelt = np.ones_like(acab[:])


t_a_date = dateutil.parser.parse(t_a)
t_e_dates = dates[dates>=t_a_date]
time_e = cdftime.date2num(t_e_dates)

x = nc.variables['x']
y = nc.variables['y']

nx = len(x)
ny = len(y)

def def_var(nc, name, units):
    # dimension transpose is standard: "float thk(y, x)" in NetCDF file
    var = nc.createVariable(name, 'f', dimensions=("time","y", "x"))
    var.units = units
    return var

idx = np.squeeze(np.nonzero(dates>t_a_date))
nte = len(idx)
var = "shelfbmassflux"
if (var not in nc.variables.keys()):
    bmelt_var = def_var(nc, var, "kg m-2 yr-1")
    bmelt_var[:] = b_a*np.ones_like(acab)
    bmelt_var[idx,:,:] = b_e*np.ones((nte,ny,nx))

else:
    nc.variables[var][:,:,:] = b_a*np.ones_like(acab)
    nc.variables[var][idx,:,:] = b_e*np.ones((nte,ny,nx))
    
var = "shelfbtemp"
if (var not in nc.variables.keys()):
    btemp_var = def_var(nc, var, "deg_C")
    btemp_var[:] = np.zeros_like(acab[:])
else:
    nc.variables[var][:] = np.zeros_like(acab[:])

nc.close()
