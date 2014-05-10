#!/usr/bin/env python
#
#
# Options
# ----------
# boot_file : netcdf file
#             containing 'thk' variable
# obs_file : netcdf file
#            containing 'surfvels_mag' variable
#
# Arguments
# ---------
# files : valid PISM netcdf file(s)
#
# Example
# -------
# $ makehist.py --boot_file Greenland_5km_v0.93.nc \
# --obs_file surf_vels_5km_searise.nc g5km_*

__author__ = "Andy Aschwanden, University of Alaska Fairbanks"

import numpy as np
import pylab as plt
from argparse import ArgumentParser
from operator import itemgetter, attrgetter

try:
    from netCDF3 import Dataset as CDF
except:
    from netCDF4 import Dataset as CDF
try:
    import pypismtools.pypismtools as ppt
except:
    import pypismtools as ppt

# Number of bins
NBINS = 50
# Maximum surface speed to be considered in histogram
HISTMAX = 5000.0            # m/a
# A threshold for outliers. Values where
# abs(obs-experiment)>OUTLIER_THRESHOLD will be excluded from comparison
OUTLIER_THRESHOLD = 500.0   # m/a

# define line colors
colors = ppt.colorList()


def set_mode(mode):
    '''
    Set the print mode, i.e. document and font size. Options are:
    - onecol: width=85mm, font size=8pt. Default. Appropriate for 1-column figures
    - twocol: width=170mm, font size=8pt. Appropriate for 2-column figures
    - medium: width=85mm, font size=8pt.
    - presentation: width=85mm, font size=9pt. For presentations.
    
    '''

    import pylab as plt

    # Default values
    linestyle = '-'

    def set_onecol():
        '''
        Define parameters for "publish" mode and return value for pad_inches
        '''
        
        fontsize = 8
        lw = 1.5
        markersize = 4
        fig_width = 3.32 # inch
        fig_height = 0.8*fig_width # inch
        fig_size = [fig_width,fig_height]

        params = {'backend': 'eps',
                  'lines.linewidth': lw,
                  'axes.labelsize': fontsize,
                  'text.fontsize': fontsize,
                  'xtick.labelsize': fontsize,
                  'ytick.labelsize': fontsize,
                  'legend.fontsize': fontsize,
                  'lines.linestyle': linestyle,
                  'lines.markersize': markersize,
                  'font.size': fontsize,
                  'figure.figsize': fig_size}

        plt.rcParams.update(params)

        return 0.1

    
    def set_medium():
        '''
        Define parameters for "medium" mode and return value for pad_inches
        '''
        
        fontsize = 8
        markersize = 5
        lw = 1.5
        fig_width = 3.32 # inch
        fig_height = 0.95*fig_width # inch
        fig_size = [fig_width,fig_height]

        params = {'backend': 'eps',
                  'lines.linewidth': lw,
                  'axes.labelsize': fontsize,
                  'text.fontsize': fontsize,
                  'xtick.labelsize': fontsize,
                  'ytick.labelsize': fontsize,
                  'legend.fontsize': fontsize,
                  'lines.linestyle': linestyle,
                  'lines.markersize': markersize,
                  'font.size': fontsize,
                  'figure.figsize': fig_size}

        plt.rcParams.update(params)

        return 0.1

    def set_presentation():
        '''
        Define parameters for "presentation" mode and return value for pad_inches
        '''
        
        fontsize = 10
        lw = 1.5
        markersize = 5
        fig_width = 6.64 # inch
        fig_height = 0.95*fig_width # inch
        fig_size = [fig_width,fig_height]

        params = {'backend': 'eps',
                  'lines.linewidth': lw,
                  'axes.labelsize': fontsize,
                  'text.fontsize': fontsize,
                  'xtick.labelsize': fontsize,
                  'ytick.labelsize': fontsize,
                  'lines.linestyle': linestyle,
                  'lines.markersize': markersize,
                  'legend.fontsize': fontsize,
                  'font.size': fontsize,
                  'figure.figsize': fig_size}

        plt.rcParams.update(params)

        return 0.1

    def set_twocol():
        '''
        Define parameters for "twocol" mode and return value for pad_inches
        '''
        
        fontsize = 8
        lw = 1.25
        markersize = 5
        fig_width = 6.64 # inch
        fig_height = 0.75*fig_width # inch
        fig_size = [fig_width,fig_height]

        params = {'backend': 'eps',
                  'lines.linewidth': lw,
                  'axes.labelsize': fontsize,
                  'text.fontsize': fontsize,
                  'xtick.labelsize': fontsize,
                  'ytick.labelsize': fontsize,
                  'lines.linestyle': linestyle,
                  'lines.markersize': markersize,
                  'legend.fontsize': fontsize,
                  'font.size': fontsize,
                  'figure.figsize': fig_size}

        plt.rcParams.update(params)

        return 0.1


    if (mode=="onecol"):
        return set_onecol()
    elif (mode=="medium"):
        return set_medium()
    elif (mode=="presentation"):
        return set_presentation()
    elif (mode=="twocol"):
        return set_twocol()
    else:
        print("%s mode not recognized, using onecol instead" % mode)
        return set_onecol()

def make_histogram_plot(study,**kwargs):
    '''Make a histogram plot with observations and experiments'''

    kwargsdict = {}
    expected_args = ["label_param_list","out_file","explicit_labels"]
    for key in kwargs.keys():
        if key in expected_args:
            kwargsdict[key] = kwargs[key]
        else:
            raise Exception("Unexpected Argument")
        
    if 'out_file' in kwargsdict:
        out_file = kwargsdict['out_file']
    else:
        out_file = None

    if 'label_param_list' in kwargsdict:
        label_param_list = kwargsdict['label_param_list']
    else:
        label_param_list = None

    if 'explicit_labels' in kwargsdict:
        explicit_labels = kwargsdict['explicit_labels']
    else:
        explicit_labels = None
    
    fig = plt.figure()
    labels = []
    ax = fig.add_subplot(111)
    ax.plot(x,velsurf_mag_obs.n,obs_marker,markerfacecolor='0.65',markeredgecolor='k')
    labels.append(velsurf_mag_obs.title)
    for e in range(0,len(study)):
        ax.plot(x,study[e].n,exp_markers[e],markerfacecolor=colors[e],markeredgecolor='k')
        if label_param_list is None:
            title = study[e].title
        else:
            title = ', '.join(["%s = %s" % (key,str(val)) for key,val in study[e].parameter_short_dict.iteritems() if key in label_param_list])
        labels.append(title)

    ax.set_xlabel("ice surface velocity, m a$^{-1}$")
    ax.set_ylabel("number of grid cells")
    ax.set_xlim(vmin,vmax)
    ax.set_ylim(ylim_min,ylim_max)
    if explicit_labels is None:
        ax.legend(labels,numpoints=1,shadow=True)
    else:
        ax.legend(explicit_labels,numpoints=1,shadow=True)
    ax.set_yscale("log")

    grid_spacing = study[0].grid_spacing
    grid_spacing_units = study[0].grid_spacing_units
    
    for out_format in out_formats:
        if out_file is None:
            ## out_file = "g" + str(grid_spacing) + grid_spacing_units + "_" + param1 + "_" + str(value1) + "_" + param2 + "_" + str(value2) + "." + out_format
            out_file = param1 + "_" + str(value1) + "_" + param2 + "_" + str(value2) + "." + out_format
        else:
            out_file = out_file + "." + out_format
        print "  - writing image %s ..." % out_file
        fig.savefig(out_file ,bbox_inches='tight',pad_inches=pad_inches,dpi=out_res)
        plt.close()
        del fig
            
if __name__ == "__main__":

    # Set up the argument parser
    parser = ArgumentParser()
    parser.description = "A script to compare model results and observations."
    parser.add_argument("FILE", nargs='*')
    parser.add_argument("--boot_file",dest="boot_file",
                      help="file containing original ice thickness for masking and comparison",default="foo.nc")
    parser.add_argument("--obs_file",dest="obs_file",
                      help="file containing observations",default="bar.nc")
    parser.add_argument("--debug",dest="DEBUG",action="store_true",
                      help="Debugging mode",default=False)
    parser.add_argument("-f", "--output_format",dest="out_formats",
                      help="Comma-separated list with output graphics suffix, default = pdf",default='pdf')
    parser.add_argument("--bins",dest="Nbins",
                      help="  specifies the number of bins",default=NBINS)
    parser.add_argument("--histmax",dest="histmax",
                      help="  max velocity (m/a) used in histogram",default=HISTMAX)
    parser.add_argument("--outlier",dest="outlier",
                      help=" speed difference (m/a) above which velocities are not used in histogramm",default=OUTLIER_THRESHOLD)
    parser.add_argument("-l", "--labels",dest="labels",
                  help="comma-separated list with labels, put in quotes like \
                  'label 1,label 2'",default=None)
    parser.add_argument("-p", "--print_size",dest="print_mode",
                        choices=['onecol','medium','twocol','height','presentation'],
                        help="sets figure size and font size.'",default="onecol")
    parser.add_argument("-r", "--output_resolution",dest="out_res",
                  help="Resolution ofoutput graphics in dots per inch (DPI), default = 300",default=300)

    options = parser.parse_args()
    args = options.FILE
    DEBUG = options.DEBUG
    Nbins = options.Nbins
    histmax = options.histmax
    outlier = options.outlier
    boot_file = options.boot_file
    obs_file = options.obs_file
    explicit_labels = options.labels.split(',')
    print_mode = options.print_mode
    out_formats = options.out_formats.split(',')
    out_res = options.out_res
    thk_min = 25.
    params = ('pseudo_plastic_q', 'till_effective_fraction_overburden',
              'sia_enhancement_factor')
    params_abbr = ('q', '$\\delta$', 'e', 'cold', 'SSA')
    abbr_dict = dict(zip(params,params_abbr))
    variable = "velsurf_mag"
    obs_variable = "velsurf_mag"
    thk_variable = "thk"
    obs_marker = 'o'
    exp_markers = ['*','^','v','s','d','p','1','2','3','4']

    # horizontal axis limits
    vmin = 0.
    vmax = histmax

    # vertical axis limits
    ylim_min = 1
    ylim_max =1e6

    # Create bins from min/max values and number of bins.
    bins = np.linspace(vmin, vmax, Nbins+1)
    print("\nBins used in this study:\n  %s" % str(bins))

    # Create observations of ice thickness ('thk') and magnitude of
    # horizontal surface velocity ('velsurf_mag').
    thk_obs = ppt.Observation(boot_file, thk_variable, bins)
    velsurf_mag_obs = ppt.Observation(obs_file, obs_variable, bins)

    print("\n  * Applying mask (%s <= %3.2f %s), updating histogram" %(thk_variable, thk_min, thk_obs.units))
    velsurf_mag_obs.add_mask(thk_obs.values <= thk_min)
    if DEBUG:
        plot_mapview(velsurf_mag_obs.values, log=True, show=True)

   
    experiments = []
    no_experiments = len(args)
    for k in range(0,no_experiments):
        filename = args[k]
        # Create individual experiment from observations and options.
        experiment = ppt.Experiment(velsurf_mag_obs, outlier, params, abbr_dict, filename, variable, bins)
        valid_cells = experiment.get_valid_cells()
        # Some statistics
        print("  * Statistics")
        rmse = ppt.get_rmse(experiment.values, velsurf_mag_obs.values, valid_cells)
        experiment.set_rmse(rmse)
        print("    - rmse = %3.2f m/a" % rmse)
        print("    - rmse normalized = %3.2f %%" % (rmse / (np.ptp(velsurf_mag_obs.values)) * 100))
        avg = ppt.get_avg(experiment.values, velsurf_mag_obs.values, valid_cells)
        experiment.set_avg(avg)
        print("    - avg  = %3.2f m/a" % avg)
        print("    - avg  normalized = %3.2f %%" % (avg / (np.ptp(velsurf_mag_obs.values)) * 100))
        if DEBUG:
            plot_mapview(np.abs(velsurf_mag_obs.values-experiment.values),log=True,title='abs(obs-expr)')
        experiments.append(experiment)


    # Histogram plots of observations and experiments
    print("\nMaking histogram plots...")
        
    # set the print mode
    pad_inches = set_mode(print_mode)

    # We plot centered-values for bins, e.g. the bin [0,100] m/a will
    # be plotted at x = 50 m/a.
    width = (vmax - vmin) / (Nbins)
    x = bins[:-1:]+width/2

    out_file = "speed_histogram"
    make_histogram_plot(experiments,out_file=out_file,explicit_labels=explicit_labels)

    # Print statistics
    ppt.print_overall_statistics(experiments)


if DEBUG:
        plt.show()
