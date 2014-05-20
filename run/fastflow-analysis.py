#!/usr/bin/env python
#
#
# Options
# ----------
# boot_file : netcdf file
#             containing 'thk' variable
# obs_file : netcdf file
#            containing 'velsurf_mag' variable
#
# Arguments
# ---------
# files : valid PISM netcdf file(s)
#
# Example
# -------
# $ makehist.py --boot_file Greenland_5km_v0.93.nc \
# --obs_file ~/base/GreenlandInSAR/surf_vels_5km_searise.nc g5km_*

__author__ = "Andy Aschwanden, University of Alaska Fairbanks"

import numpy as np
import pylab as plt
from argparse import ArgumentParser

from scipy.interpolate import RectBivariateSpline
from skimage import measure

from netCDF4 import Dataset as CDF

try:
    from pypismtools import pypismtools as ppt
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

def write_file(fname, array, rasterOrigin, pixelWidth, pixelHeight, _FillValue, proj4str):

    import gdal
    import osr

    cols = array.shape[1]
    rows = array.shape[0]

    driver = gdal.GetDriverByName('netCDF')
    outRaster = driver.Create(fname, cols, rows, 1, gdal.GDT_Float32)
    outband = outRaster.GetRasterBand(1)
    outband.SetNoDataValue(_FillValue)
    outband.WriteArray(array)
    outRasterSRS = osr.SpatialReference()
    outRasterSRS.ImportFromProj4(proj4str)
    outRaster.SetProjection(outRasterSRS.ExportToWkt())
    outband.FlushCache()


def get_indices(x, y, x0, y0):
    j = np.arange(len(x))
    i = np.arange(len(y))
    j_ind, i_ind = (np.max(j * (x < x0)), np.max(i * (y < y0)))
    return i_ind, j_ind

def cross_correlation(obs, exp, ij_bbox):

    from scipy.signal import correlate2d

    i0, j0, i1, j1 = ij_bbox

    print(("i = %d, j = %d" %  (i0, j0)))
    print(("i = %d, j = %d" %  (i1, j1)))
    fill_value = 0
    obs_vals = np.ma.filled(obs.values[i0:i1, j0:j1], fill_value=fill_value)
    exp_vals = np.ma.filled(exp.values[i0:i1, j0:j1], fill_value=fill_value)
    cor = np.squeeze(correlate2d(exp_vals, obs_vals, mode='valid'))
    cor_mat = np.squeeze(correlate2d(exp_vals, obs_vals, mode='full'))
    return cor, cor_mat

def make_psd_plot(study, **kwargs):
    '''Make a power spectrum plot with observations and experiments'''

    kwargsdict = {}
    expected_args = ["label_param_list", "out_file", "explicit_labels"]
    for key in kwargs.keys():
        if key in expected_args:
            kwargsdict[key] = kwargs[key]
        else:
            raise Exception("Unexpected Argument")

    if 'out_file' in kwargsdict:
        out_file = kwargsdict['out_file']
    else:
        out_file = None

    from scipy.stats.stats import pearsonr, linregress
    NFFT=128
    fig = plt.figure()
    ax = fig.add_subplot(211)
    ax.psd(speed_obs.contour_values, NFFT=NFFT)
    ## ax.semilogy(x, y, 'r')
    for k, s in enumerate(study):
        ax.psd(study[k].contour_values, NFFT=NFFT)
        ## ax.semilogy(x, y)
    ## ax.set_ylim(-10, 180)
    ax = fig.add_subplot(212)
    ax.plot(speed_obs.contour_values)
    ## ax.semilogy(x, y, 'r')
    for k, s in enumerate(study):
        ax.plot(study[k].contour_values)
        slope, intercept, r_value, p_value, std_err = linregress(speed_obs.contour_values, study[k].contour_values)
        r = pearsonr(speed_obs.contour_values, study[k].contour_values)
        corr = "linregress r = {:1.4f}".format(r_value)
        ax.text(0.05, 0.35, corr, transform = ax.transAxes)
        corr = "pearson r = {:1.4f}".format(r[0])
        ax.text(0.05, 0.25, corr, transform = ax.transAxes)
    ax.set_ylim(0, 50)

    for out_format in out_formats:
        if out_file is None:
            out_file = param1 + "_" + str(value1) + "_" + param2 + "_" + str(value2) + "." + out_format
        else:
            out_file = out_file + "_psd." + out_format
        print "  - writing image %s ..." % out_file
        fig.savefig(out_file , bbox_inches='tight', pad_inches=pad_inches, dpi=out_res)
        plt.close()
        del fig


def make_histogram_plot(study, **kwargs):
    '''Make a histogram plot with observations and experiments'''

    kwargsdict = {}
    expected_args = ["label_param_list", "out_file", "explicit_labels"]
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
    ax.plot(x,speed_obs.n,obs_marker, markerfacecolor='0.65', markeredgecolor='k')
    labels.append(speed_obs.title)
    for e in range(0, len(study)):
        ax.plot(x,study[e].n, exp_markers[e], markerfacecolor=colors[e], markeredgecolor='k')
        if label_param_list is None:
            title = study[e].title
        else:
            title = ', '.join(["%s = %s" % (key, str(val)) for key, val in study[e].parameter_short_dict.iteritems() if key in label_param_list])
        labels.append(title)

    ax.set_xlabel("ice surface velocity, m a$^{-1}$")
    ax.set_ylabel("number of grid cells")
    ax.set_xlim(vmin, vmax)
    ax.set_ylim(ylim_min, ylim_max)
    if explicit_labels is None:
        ax.legend(labels, numpoints=1, shadow=True)
    else:
        ax.legend(explicit_labels, numpoints=1, shadow=True)
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
        fig.savefig(out_file , bbox_inches='tight', pad_inches=pad_inches, dpi=out_res)
        plt.close()
        del fig

            
if __name__ == "__main__":

    # Set up the argument parser
    parser = ArgumentParser('''A script to compare model results and observations.''')
    parser.add_argument("FILE", nargs='*')
    parser.add_argument("--boot_file", dest="boot_file",
                      help="file containing original ice thickness for masking and comparison",
                      default="foo.nc")
    parser.add_argument("--obs_file", dest="obs_file",
                      help="file containing observations", default="bar.nc")
    parser.add_argument("--debug",dest="DEBUG", action="store_true",
                      help="Debugging mode", default=False)
    parser.add_argument("-f", "--output_format", dest="out_formats",
                      help="Comma-separated list with output graphics suffix, default = pdf",
                      default='pdf')
    parser.add_argument("--bins",dest="Nbins", type=int,
                      help="  specifies the number of bins", default=NBINS)
    parser.add_argument("--histmax", dest="histmax", type=float,
                      help="  max velocity (m/a) used in histogram",
                      default=HISTMAX)
    parser.add_argument("--outlier", dest="outlier", type=float,
                      help=" speed difference (m/a) above which velocities are not used in histogramm",
                      default=OUTLIER_THRESHOLD)
    parser.add_argument("-p", "--print_size", dest="print_mode",
                    choices=['onecol','medium','twocol','height','presentation'],
                    help="sets figure size and font size.'", default="onecol")
    parser.add_argument("-r", "--output_resolution", dest="out_res",
                  help="Resolution ofoutput graphics in dots per inch (DPI), default = 300", default=300)

    options = parser.parse_args()
    args = options.FILE
    
    DEBUG = options.DEBUG
    Nbins = options.Nbins
    histmax = options.histmax
    outlier = options.outlier
    boot_file = options.boot_file
    obs_file = options.obs_file
    print_mode = options.print_mode
    out_formats = options.out_formats.split(',')
    out_res = options.out_res
    thk_min = 25.
    params = ('pseudo_plastic_q', 'till_effective_fraction_overburden',
              'sia_enhancement_factor', 'do_cold_ice_methods', 'stress_balance_model')
    params_abbr = ('q', '$\\alpha$', 'e', 'cold', 'SSA')
    abbr_dict = dict(zip(params, params_abbr))
    variable = "velsurf_mag"
    obs_variable = "velsurf_mag"
    thk_variable = "thk"
    obs_marker = 'o'
    exp_markers = ['*', '^', 'v', 's', 'd', 'p', '1', '2', '3', '4']

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
    # horizontal surface velocity ('csurf').
    thk_obs = ppt.Observation(boot_file, thk_variable, bins)    
    speed_obs = ppt.Observation(obs_file, obs_variable, bins)

    xdim, ydim, zdim, tdim = ppt.get_dims(thk_obs.nc)
    proj4 = ppt.get_projection_from_file(speed_obs.nc)
    proj4str = proj4.srs

    x_var = np.squeeze(thk_obs.nc.variables[xdim])
    y_var = np.squeeze(thk_obs.nc.variables[ydim])
    i = range(0,len(x_var))
    j = range(0,len(y_var))

    xx, yy = np.meshgrid(x_var, y_var)

    contour_level = 2000
    # Find contours at a constant value
    print(("Finding %3.0fm contour" % contour_level))
    contours = sorted(measure.find_contours(thk_obs.values, contour_level),
                      key=lambda x: len(x))
    # We only extract the longest contigous contour
    contour = contours[-1]

    contour_x = x_var[0] + contour[:,1] * (x_var[-1] - x_var[0]) / (len(i) - 1)
    contour_y = y_var[0] + contour[:,0] * (y_var[-1] - y_var[0]) / (len(j) - 1)

    M = 10
    finelength = (len(i) - 1) * M + 1
    contour_xf = np.zeros(finelength)
    contour_yf = np.zeros(finelength)

    for k in range(0,len(i)-1):
        contour_xf[k*M:(k+1)*M] = np.linspace(contour_x[k], contour_x[k+1], M)
        contour_yf[k*M:(k+1)*M] = np.linspace(contour_y[k], contour_y[k+1], M)

    # interpolation along contour line
    print(("Interpolating observed surface speeds along %3.0fm contour" % contour_level))
    speed_obs.contour_level = contour_level
    speed_obs.contour_x = contour_x
    speed_obs.contour_y = contour_y
    contour_speed_f = RectBivariateSpline(y_var, x_var, speed_obs.values)
    contour_values = contour_speed_f.ev(contour_yf, contour_xf)
    contour_values[contour_values == speed_obs.values.fill_value] = np.nan
    speed_obs.contour_values = contour_values

    print("\n  * Applying mask (%s <= %3.2f %s), updating histogram" %(thk_variable,thk_min,thk_obs.units))
    speed_obs.add_mask(thk_obs.values <= thk_min)
    if DEBUG:
        plot_mapview(speed_obs.values, log=True, show=True)

    # We plot centered-values for bins, e.g. the bin [0,100] m/a will
    # be plotted at x = 50 m/a.
    width = (vmax - vmin) / (Nbins)
    x = bins[:-1:] + width / 2

    label_param_list = ['q', 'e', '$\\alpha$', 'thermo', 'stress']
    
    experiments = []
    no_experiments = len(args)
    for k in range(0, no_experiments):
        filename = args[k]
        # Create individual experiment from observations and options.
        experiment = ppt.Experiment(speed_obs, outlier, params, abbr_dict, filename, variable, bins)
        valid_cells = experiment.get_valid_cells()

        # Unterpolation along contour line
        print(("  * Interpolating surface speeds along %3.0fm contour" % contour_level))
        experiment.contour_level = contour_level
        experiment.contour_x = contour_x
        experiment.contour_y = contour_y
        contour_speed_f = RectBivariateSpline(y_var, x_var, experiment.values)
        experiment.contour_values = contour_speed_f.ev(contour_yf, contour_xf)

        # Some statistics
        print("  * Cross correlation tatistics")

        bbox = [-440000, -2276500, -360000, -2227000]
        xmin, ymin, xmax, ymax = bbox
        i0, j0 = get_indices(x_var, y_var, xmin, ymin)
        i1, j1 = get_indices(x_var, y_var, xmax, ymax)
        ij_bbox = [i0, j0, i1, j1]
        origin = [bbox[0] - 1000, bbox[1] - 1000]
        pixelWidth = 2000
        pixelHeight = 2000

        cor, cor_mat = cross_correlation(speed_obs, experiment, ij_bbox)
        print ("chi = {}".format(cor))

        out_file = ("cor_sia_enhancement_factor_" +
                    str(experiment.parameter_dict['sia_enhancement_factor']) +
                    "_pseudo_plastic_q_" +
                    str(experiment.parameter_dict['pseudo_plastic_q']) +
                    "_till_effective_fraction_overburden_" +
                    str(experiment.parameter_dict['till_effective_fraction_overburden']) + '.nc')
        write_file(out_file, cor_mat, origin, pixelWidth, pixelHeight, -2e9, proj4str)

        experiment.cor = cor
        # Some statistics
        print("  * Statistics")
        rmse = ppt.get_rmse(experiment.values, speed_obs.values, valid_cells)
        experiment.set_rmse(rmse)
        print("    - rmse = %3.2f m/a" % rmse)
        print("    - rmse normalized = %3.2f %%" % (rmse / (np.ptp(speed_obs.values)) * 100))
        avg = ppt.get_avg(experiment.values,speed_obs.values, valid_cells)
        experiment.set_avg(avg)
        print("    - avg  = %3.2f m/a" % avg)
        print("    - avg  normalized = %3.2f %%" % (avg / (np.ptp(speed_obs.values)) * 100))
        if DEBUG:
            plot_mapview(np.abs(speed_obs.values - experiment.values), log=True, title='abs(obs-expr)')

        # set the print mode
        lw, pad_inches = ppt.set_mode(print_mode, 0.75)
        markersize = 4
        plot_params = {'lines.markersize': markersize}
        plt.rcParams.update(plot_params)
        study = [experiment]
        out_file = ("sia_enhancement_factor_" +
                    str(experiment.parameter_dict['sia_enhancement_factor']) +
                    "_pseudo_plastic_q_" +
                    str(experiment.parameter_dict['pseudo_plastic_q']) +
                    "_till_effective_fraction_overburden_" +
                    str(experiment.parameter_dict['till_effective_fraction_overburden']))
        ## make_histogram_plot(study, out_file=out_file,
        ##                         label_param_list=label_param_list)
        make_psd_plot(study, out_file=out_file)
        experiments.append(experiment)


    # Histogram plots of observations and experiments
    print("\nMaking histogram plots...")
        
    # set the print mode
    lw, pad_inches = ppt.set_mode(print_mode, 0.75)
    markersize = 4
    plot_params = {'lines.markersize': markersize}
    plt.rcParams.update(plot_params)

    # ################################################################
    # No enhancement study
    # ################################################################

    label_param_list = ['q', '$\\alpha$']

    param1 = 'sia_enhancement_factor'
    value1 = [1]

    param2 = 'pseudo_plastic_q'
    value2 = [0.10, 0.25, 0.33, 0.8]

    param3 = 'till_effective_fraction_overburden'
    value3 = [0.01, 0.02, 0.05]

    param4 = 'do_cold_ice_methods'
    value4 = 'no'

    param5 = 'stress_balance_model'
    value5 = 'ssa+sia'

    print("\n  Making no enhancement plot")
    study = sorted(filter(lambda(x) : (x.parameter_dict[param1] in
    value1 and x.parameter_dict[param2] in value2  and
    x.parameter_dict[param3] in value3 and
    x.parameter_dict[param4] == value4 and x.parameter_dict[param5] ==
    value5), experiments), key=lambda x: x.parameter_dict["till_effective_fraction_overburden"]) 

    if len(study) != 0:
        out_file = "no_enhancement"
        make_histogram_plot(study, out_file=out_file,
                            label_param_list=label_param_list)
    else:
        print("  -> no experiments available, skipping")

    # ################################################################
    # Pore water fraction study
    # ################################################################

    label_param_list = ['$\\alpha$']

    param1 = 'sia_enhancement_factor'
    value1 = [1]

    param2 = 'pseudo_plastic_q'
    value2 = [0.25]

    param3 = 'till_effective_fraction_overburden'
    value3 = [0.01, 0.02, 0.05]

    param4 = 'do_cold_ice_methods'
    value4 = 'no'

    param5 = 'stress_balance_model'
    value5 = 'ssa+sia'

    print("\n  Making till pore water fraction plot")

    study = sorted(filter(lambda(x) : (x.parameter_dict[param1] in
    value1 and x.parameter_dict[param2] in value2 and
    x.parameter_dict[param3] in value3 and x.parameter_dict[param4] == value4 and x.parameter_dict[param5] == value5), experiments),key=lambda x: x.parameter_dict["till_effective_fraction_overburden"]) 

    if len(study) != 0:
        out_file = 'till_effective_fraction_overburden'
        make_histogram_plot(study, out_file=out_file,
                            label_param_list=label_param_list)
    else:
        print("  -> no experiments available, skipping")


    # ################################################################
    # Enhancement factor study
    # ################################################################

    label_param_list = ['e']

    param1 = 'till_effective_fraction_overburden'
    value1 = [0.02]

    param2 = 'pseudo_plastic_q'
    value2 = [0.25]

    param4 = 'do_cold_ice_methods'
    value4 = 'no'

    param5 = 'stress_balance_model'
    value5 = 'ssa+sia'

    print("\n  Making enhancement factor plot")
    study = sorted(filter(lambda(x) : (x.parameter_dict[param1] ==
    value1 and x.parameter_dict[param2] == value2 and x.parameter_dict[param4] == value4 and x.parameter_dict[param5] == value5), experiments),key=lambda x: x.parameter_dict["sia_enhancement_factor"]) 

    if len(study) != 0:
        out_file = "enhancement_factor"
        make_histogram_plot(study, out_file=out_file,
                            label_param_list=label_param_list)
    else:
        print("  -> no experiments available, skipping")




    # ################################################################
    # Pseudo-plasticity study
    # ################################################################

    label_param_list = ['q']
    
    param1 = 'sia_enhancement_factor'
    value1 = 1

    param2 = 'till_effective_fraction_overburden'
    value2 = 0.02

    param3 = 'pseudo_plastic_q'
    value3 = [0.1, 0.25, 0.33, 0.8]

    param4 = 'do_cold_ice_methods'
    value4 = 'no'

    param5 = 'stress_balance_model'
    value5 = 'ssa+sia'

    print("\n  Making plot pseudo-plastic plots")
    study = sorted(filter(lambda(x) : (x.parameter_dict[param1] ==
    value1 and x.parameter_dict[param2] == value2 and x.parameter_dict[param3] in value3 and x.parameter_dict[param4] == value4 and x.parameter_dict[param5] == value5), experiments),key=lambda x: x.parameter_dict["pseudo_plastic_q"]) 

    if len(study) != 0:
        out_file = "pseudo_plastic_q"
        make_histogram_plot(study,out_file=out_file,label_param_list=label_param_list)
    else:
        print("  -> no experiments available, skipping")

    # Print statistics
    ppt.print_overall_statistics(experiments)


if DEBUG:
        plt.show()
