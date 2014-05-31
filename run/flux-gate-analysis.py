#!/usr/bin/env python
# Copyright (C) 2011-2013 Andy Aschwanden
#
# Script creates a basemap plot of a variable in a netCDF file
# with a geotiff background (if given).
# Does a 1x2, 1x3, 2x2, 3x2 grid plots

from unidecode import unidecode
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
my_colors = ppt.colorList()

alpha = 0.5
dash_style = 'o'
markersize = 4
numpoints = 1

params = ('pseudo_plastic_q', 'till_effective_fraction_overburden',
          'sia_enhancement_factor', 'do_cold_ice_methods', 'stress_balance_model')
params_abbr = ('q', '$\\alpha$', 'e', 'cold', 'SSA')
params_abbr_dict = dict(zip(params, params_abbr))

var_long = ('velsurf_mag', 'velbase_mag')
var_short = ('speed', 'sliding speed')
var_name_dict = dict(zip(var_long, var_short))



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
        self.varname = None
        self.varname_units = None
        self.has_observations = None

    def __repr__(self):
        return "FluxGate"

    def add_experiment(self, data):
        print((u"Adding experiment to flux gate {0}".format(self.gate_name)))
        gate_id = self.gate_id
        fg_exp = FluxGateDataset(data, gate_id)
        self.experiments.append(fg_exp)
        if self.varname is None:
            self.varname = data.varname
        if self.varname_units is None:
            self.varname_units = data.varname_units
        self.exp_counter += 1

    def add_observations(self, data):
        print((u"Adding observations to flux gate {0}".format(self.gate_name)))
        gate_id = self.gate_id
        fg_obs = FluxGateObservations(data, gate_id)
        self.observations = fg_obs
        if self.has_observations is not None:
            print(("Flux gate {0} already has observations, overriding".format(self.gate_name)))
        self.has_observations = True

    def make_line_plot(self, **kwargs):
        '''
        Make plot
        '''
        gate_name = self.gate_name
        experiments = self.experiments
        profile_axis = self.profile_axis
        profile_axis_name = self.profile_axis_name
        profile_axis_units = self.profile_axis_units
        varname = self.varname
        v_units = self.varname_units
        has_observations = self.has_observations

        labels = []
        fig = plt.figure()
        ax = fig.add_subplot(111)
        if has_observations:
            obs = self.observations
            label = 'observed'
            # plot_keys = ('color', 'label', 'markersize')
            # plot_kwargs = ('k', label, markersize) 
            # plot_params = dict(zip(plot_keys, plot_kwargs))
            # print plot_params
            # my_color = colorsys.hsv_to_rgb(my_colorHSV[0,0],my_colorHSV[0,1],my_colorHSV[0,2]/1.5
            has_error = obs.has_error
            if has_error:
                ax.errorbar(profile_axis, obs.values, yerr=obs.error, color='0.5')
            ax.plot(profile_axis, obs.values, '-', color='0.5')
            ax.plot(profile_axis, obs.values, dash_style, color='0.5', label=label, markersize=markersize)
        for k, exp in enumerate(experiments):
            if 'label_param_list' in kwargs.keys():
                params = kwargs['label_param_list']
                pism_config = exp.pism_config
                label = ', '.join(['='.join([params_abbr_dict[key], pism_config[key].astype('str')]) for key in params])
                labels.append(label)    
            ax.plot(profile_axis, np.squeeze(exp.values), '-', color=my_colors[k], alpha=alpha)
            ax.plot(profile_axis, np.squeeze(exp.values), dash_style, color=my_colors[k], label=label, markersize=markersize)
            labels.append(label)
        xlabel = "{0} ({1})".format(profile_axis_name, profile_axis_units)
        ax.set_xlabel(xlabel)
        if varname in var_name_dict.keys():
            v_name = var_name_dict[varname]
        else:
            v_name = varname
        ylabel = "{0} ({1})".format(v_name, v_units)
        ax.set_ylabel(ylabel)
        plt.legend(loc="upper right",
                  shadow=True, numpoints=numpoints,
                  bbox_to_anchor=(0, 0, 1, 1),
            bbox_transform=plt.gcf().transFigure)
        plt.title(gate_name)
        return fig


class FluxGateDataset(object):
    def __init__(self, data, gate_id, *args, **kwargs):
        super(FluxGateDataset, self).__init__(*args, **kwargs)
        self.values = data.values[gate_id, Ellipsis]
        self.pism_config = data.pism_config

    def __repr__(self):
        return "FluxGateDataset"


class FluxGateObservations(object):
    def __init__(self, data, gate_id, *args, **kwargs):
        super(FluxGateObservations, self).__init__(*args, **kwargs)
        self.has_error = None
        self.values = data.values[gate_id, Ellipsis]
        if data.has_error:
            self.error = data.error[gate_id, Ellipsis]
            self.has_error = True

    def __repr__(self):
        return "FluxGateObservations"


class Dataset(object):
    '''
    A base class for Experiments or Observations.

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

        for name in nc.variables:
            v = nc.variables[name]
            if getattr(v, "standard_name", "") == varname:
                print("variabe {0} found by its standard_name {1}".format(name,
                                                                          varname))
                varname = name
        self.values = nc.variables[varname][:]
        self.varname_units = nc.variables[varname].units
        self.varname = varname
        self.nc = nc

    def __repr__(self):
        return "Dataset"

    def __del__(self):
        # Close open file
        self.nc.close()

class ExperimentDataset(Dataset):
    '''
    A derived class for experiments

    A derived class for handling PISM experiments.

    Parameters
    ----------
    '''
    def __init__(self, *args, **kwargs):
        super(ExperimentDataset, self).__init__(*args, **kwargs)

        pism_config = self.nc.variables['pism_config']
        self.pism_config = dict()
        for attr in pism_config.ncattrs():
            self.pism_config[attr] = getattr(pism_config, attr)

    def __repr__(self):
        return "ExperimentDataset"

class ObservationsDataset(Dataset):
    '''
    A derived class for experiments

    A derived class for handling PISM experiments.

    Parameters
    ----------
    '''
    def __init__(self, *args, **kwargs):
        super(ObservationsDataset, self).__init__(*args, **kwargs)
        self.has_error = None
        error_varname = 'uvelsurf_error'
        if error_varname in self.nc.variables.keys():
            self.error = self.nc.variables[error_varname][:]
            self.has_error = True

    def __repr__(self):
        return "ObservationsDataset"


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
    obs = ObservationsDataset(obs_file, varname)
    for flux_gate in flux_gates:
        flux_gate.add_observations(obs)

for k, filename in enumerate(args):

    experiment = ExperimentDataset(filename, varname)
    for flux_gate in flux_gates:
        flux_gate.add_experiment(experiment)


params = ('pseudo_plastic_q', 'till_effective_fraction_overburden',
          'sia_enhancement_factor')

# set the print mode
golden_mean = ppt.get_golden_mean()
aspect_ratio = golden_mean
lw, pad_inches = ppt.set_mode(print_mode, aspect_ratio=golden_mean * 1)

for gate in flux_gates:
    fig = gate.make_line_plot(label_param_list=params)
    gate_name = unidecode(gate.gate_name)
    outname = '.'.join([gate_name, 'pdf']).replace(' ', '_')
    print(("Saving {0}".format(outname)))
    fig.savefig(outname)
