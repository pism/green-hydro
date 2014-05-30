#!/usr/bin/env python
# Copyright (C) 2011-2013 Andy Aschwanden
#
# Script creates a basemap plot of a variable in a netCDF file
# with a geotiff background (if given).
# Does a 1x2, 1x3, 2x2, 3x2 grid plots

import numpy as np
import pylab as plt
from argparse import ArgumentParser

from netCDF4 import Dataset as NC

try:
    import pypismtools.pypismtools as ppt
except:
    import pypismtools as ppt

# Set up the option parser
parser = ArgumentParser()
parser.description = "Under construction."
parser.add_argument("FILE", nargs='*')
parser.add_argument("--obs_file",dest="obs_file",
                  help='''Profile file with observations. Default is None''', default=None)
parser.add_argument("-p", "--print_size", dest="print_mode",
                    choices=['onecol','medium','twocol','height','presentation', 'small_font'],
                    help="sets figure size and font size, available options are: \
                    'onecol','medium','twocol','presentation'", default="twocol")
parser.add_argument("-r", "--output_resolution", dest="out_res",
                  help='''
                  Graphics resolution in dots per inch (DPI), default
                  = 300''', default=300)
parser.add_argument("-v", "--variable", dest="varname",
                  help='''Variable to plot, default = 'velsurf_mag'.''', default='velsurf_mag')

options = parser.parse_args()
args = options.FILE

print_mode = options.print_mode
obs_file = options.obs_file
out_res = int(options.out_res)
varname = options.varname

class FluxGate(object):
    '''
    A class for FluxGates.

    Parameters
    ----------
    gate_name: string, name of flux gate
    gate_id: int, gate identification
    profile_axis: 1-d array, profile axis values
    profile_axis_units: string, udunits unit of axis
    profile_axis_name: string, descriptive name of axis
    '''
    def __init__(self, gate_name, gate_id, profile_axis, profile_axis_units, profile_axis_name, *args, **kwargs):
        super(FluxGate, self).__init__(*args, **kwargs)
        self.gate_name = gate_name
        self.gate_id = gate_id 
        self.profile_axis = profile_axis
        self.profile_axis_units = profile_axis_units
        self.profile_axis_name = profile_axis_name
        self.experiments = []
        self.exp_counter = 0

    def __repr__(self):
        return "FluxGate"

    def add(self, experiment):
        print(("Adding experiment to flux gate {0}".format(self.gate_name)))
        gate_id = self.gate_id
        fge = FluxGateDataset(experiment, gate_id)
        self.experiments.append(fge)
        self.exp_counter += 1

    def make_line_plot(self, **kwargs):
        experiments = self.experiments
        profile_axis = self.profile_axis
        fig = plt.figure()
        ax = fig.add_subplot(111)
        for exp in experiments:
            if 'label_param_list' in kwargs.keys():
                params = kwargs['label_param_list']
                pism_config = exp.pism_config
                label = ','.join(['='.join([key, pism_config[key].astype('str')]) for key in params])
                    
            ax.plot(profile_axis, np.squeeze(exp.values), label=label)
        plt.legend()

class FluxGateDataset(object):
    def __init__(self, experiment, gate_id, *args, **kwargs):
        super(FluxGateDataset, self).__init__(*args, **kwargs)
        self.values = experiment.values[gate_id, Ellipsis]
        self.pism_config = experiment.pism_config

    def __repr__(self):
        return "FluxGateDataset"

class Dataset(object):
    '''
    A class for Experiments or Observations.

    Parameters
    ----------
    '''
    def __init__(self, filename, varname, *args, **kwargs):
        super(Dataset, self).__init__(*args, **kwargs)
        print("  opening NetCDF file %s ..." % filename)
        try:
            nc = NC(filename, 'r')
        except:
            print(("ERROR:  file '%s' not found or not NetCDF format ... ending ..."
                  % filename))
            import sys
            sys.exit(1)

        pism_config = nc.variables['pism_config']
        self.pism_config = dict()
        for attr in pism_config.ncattrs():
            self.pism_config[attr] = getattr(pism_config, attr)

        for name in nc.variables:
            v = nc.variables[name]
            if getattr(v, "standard_name", "") == varname:
                print("variabe {0} found by its standard_name {1}".format(name,
                                                                          varname))
                varname = name
        self.values = nc.variables[varname][:]
        self.nc = nc

    def __repr__(self):
        return "Dataset"

    def __del__(self):
        # Close open file
        self.nc.close()

filename = args[0]
print("  opening NetCDF file %s ..." % filename)
try:
    nc0 = NC(filename, 'r')
except:
    print(("ERROR:  file '%s' not found or not NetCDF format ... ending ..."
          % filename))
    import sys
    sys.exit(1)

profile_names = nc0.variables['profile_name'][:]
flux_gates = []
for gate_id, profile_name in enumerate(profile_names):
    profile_axis = nc0.variables['profile'][gate_id]
    profile_axis_units = nc0.variables['profile'].units
    profile_axis_name = nc0.variables['profile'].long_name
    flux_gate = FluxGate(profile_name, gate_id, profile_axis, profile_axis_units, profile_axis_name)
    flux_gates.append(flux_gate)
nc0.close()

if obs_file:
    obs = Dataset(obs_file, varname)

for k, filename in enumerate(args):

    experiment = Dataset(filename, varname)
    for flux_gate in flux_gates:
        flux_gate.add(experiment)


params = ('pseudo_plastic_q', 'till_effective_fraction_overburden',
          'sia_enhancement_factor')
params_abbr = ('q', '$\\alpha$')
abbr_dict = dict(zip(params, params_abbr))
flux_gates[0].make_line_plot(label_param_list=params)
