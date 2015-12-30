#!/usr/bin/env python
# Copyright (C) 2015 Andy Aschwanden

import itertools
from collections import OrderedDict
import os
from argparse import ArgumentParser
from resources import *

grid_choices = [18000, 9000, 4500, 3600, 1800, 1500, 1200, 900, 600, 450, 300, 150]

# set up the option parser
parser = ArgumentParser()
parser.description = "Generating scripts for model initialization."
parser.add_argument("-n", '--n_procs', dest="n", type=int,
                    help='''number of cores/processors. default=64.''', default=64)
parser.add_argument("-w", '--wall_time', dest="walltime",
                    help='''walltime. default: 12:00:00.''', default="12:00:00")
parser.add_argument("-q", '--queue', dest="queue", choices=['standard_4', 'standard_16', 'standard', 'gpu', 'gpu_long', 'long', 'normal'],
                    help='''queue. default=standard_4.''', default='standard_4')
parser.add_argument("--climate", dest="climate",
                    choices=['const', 'paleo'],
                    help="Climate", default='paleo')
parser.add_argument("--calving", dest="calving",
                    choices=['float_kill', 'ocean_kill', 'eigen_calving'],
                    help="claving", default='ocean_kill')
parser.add_argument("-d", "--domain", dest="domain",
                    choices=['gris'],
                    help="sets the modeling domain", default='gris')
parser.add_argument("-f", "--o_format", dest="oformat",
                    choices=['netcdf3', 'netcdf4_parallel', 'pnetcdf'],
                    help="output format", default='netcdf4_parallel')
parser.add_argument("-g", "--grid", dest="grid", type=int,
                    choices=grid_choices,
                    help="horizontal grid resolution", default=9000)
parser.add_argument("--o_size", dest="osize",
                    choices=['small', 'medium', 'big', '2dbig'],
                    help="output size type", default='2dbig')
parser.add_argument("-s", "--system", dest="system",
                    choices=['pleiades', 'fish', 'pacman', 'debug'],
                    help="computer system to use.", default='pacman')
parser.add_argument("-b", "--bed_type", dest="bed_type",
                    choices=['ctrl', 'old_bed', 'ba01_bed', '970mW_hs', 'jak_1985', 'cresis'],
                    help="output size type", default='ctrl')
parser.add_argument("--forcing_type", dest="forcing_type",
                    choices=['ctrl', 'e_age', 'ftt', 'e_age_ftt'],
                    help="output size type", default='ctrl')
parser.add_argument("--stress_balance", dest="stress_balance",
                    choices=['sia', 'ssa+sia', 'ssa'],
                    help="stress balance solver", default='ssa+sia')
parser.add_argument("--dataset_version", dest="version",
                    choices=['2'],
                    help="input data set version", default='2')


options = parser.parse_args()

nn = options.n
oformat = options.oformat
osize = options.osize
queue = options.queue
walltime = options.walltime
system = options.system

calving = options.calving
climate = options.climate
forcing_type = options.forcing_type
grid = options.grid
bed_type = options.bed_type
version = options.version
stress_balance = options.stress_balance

domain = options.domain
pism_exec = generate_domain(domain)
save_times = [-25000, -5000, -1500, -1000, -500, -200, -100]

    
infile = ''
pism_dataname = 'pism_Greenland_{}m_mcb_jpl_v{}_{}.nc'.format(grid, version, bed_type)


# ########################################################
# set up model initialization
# ########################################################

hydro = 'null'
pism_surface_bcfile = 'GR6b_ERAI_1989_2011_4800M_BIL_1989_baseline.nc'

sia_e = (3.0)
ppq = (0.6)
tefo = (0.02)
ssa_n = (3.25)
ssa_e = (1.0)

calving_thk_threshold_values = [300]
calving_k_values = [1e18]
phi_min_values = [5.0]
phi_max_values = [40.]
topg_min_values = [-700]
topg_max_values = [700]
combinations = list(itertools.product(calving_thk_threshold_values, calving_k_values, phi_min_values, phi_max_values, topg_min_values, topg_max_values))

tsstep = 'yearly'
exstep = '100'

scripts = []
posts = []

start = -125000
end = 0

for n, combination in enumerate(combinations):

    calving_thk_threshold, calving_k , phi_min, phi_max, topg_min, topg_max = combination

    ttphi = '{},{},{},{}'.format(phi_min, phi_max, topg_min, topg_max)

    name_options = OrderedDict()
    name_options['sia_e'] = sia_e
    name_options['ppq'] = ppq
    name_options['tefo'] = tefo
    name_options['ssa_n'] = ssa_n
    name_options['ssa_e'] = ssa_e
    name_options['phi_min'] = phi_min
    name_options['phi_max'] = phi_max
    name_options['topg_min'] = topg_min
    name_options['topg_max'] = topg_max
    name_options['calving'] = calving
    if calving in ('eigen_calving'):
        name_options['calving_k'] = calving
        name_options['calving_thk_threshold'] = calving
    name_options['forcing_type'] = forcing_type
    
    vversion = 'v' + str(version)
    experiment =  '_'.join([climate, vversion, bed_type, '_'.join(['_'.join([k, str(v)]) for k, v in name_options.items()])])

        
    script = 'spinup_{}_g{}m_{}.sh'.format(domain.lower(), grid, experiment)
    scripts.append(script)
    post = 'spinup_{}_g{}m_{}_post.sh'.format(domain.lower(), grid, experiment)
    posts.append(post)
    
    for filename in (script, post):
        try:
            os.remove(filename)
        except OSError:
            pass

    pbs_header = make_pbs_header(system, nn, walltime, queue)
        
    
    os.environ['PISM_EXPERIMENT'] = experiment
    os.environ['PISM_TITLE'] = 'Greenland Paramter Study'
    
    with open(script, 'w') as f:

        f.write(pbs_header)


        outfile = '{domain}_g{grid}m_spinup_straight_{experiment}_0.nc'.format(domain=domain.lower(),grid=grid, experiment=experiment)
        
        dura = 10

        general_params_dict = OrderedDict()
        general_params_dict['o_format'] = oformat
        general_params_dict['o_size'] = osize
        
        grid_params_dict = generate_grid_description(grid)

        sb_params_dict = OrderedDict()
        sb_params_dict['sia_e'] = sia_e
        sb_params_dict['ssa_e'] = ssa_e
        sb_params_dict['ssa_n'] = ssa_n
        sb_params_dict['pseudo_plastic_q'] = ppq
        sb_params_dict['till_effective_fraction_overburden'] = tefo
        sb_params_dict['topg_to_phi'] = ttphi

        stress_balance_params_dict = generate_stress_balance(stress_balance, sb_params_dict)
        exvars = "climatic_mass_balance_cumulative,tempsurf,diffusivity,temppabase,bmeltvelsurf_mag,mask,thk,topg,usurf,taud_mag,velsurf,climatic_mass_balance,climatic_mass_balance_original,velbase_mag,tauc,taub_mag"
        spatial_ts_dict = generate_spatial_ts(outfile, exvars, exstep, start=start, end=end)
        scalar_ts_dict = generate_scalar_ts(outfile, tsstep, start=start, end=end)

        all_params_dict = merge_dicts(general_params_dict, grid_params_dict, stress_balance_params_dict, spatial_ts_dict, scalar_ts_dict)
        all_params = ' '.join([' '.join(['-' + k, str(v)]) for k, v in all_params_dict.items()])
        
        params_dict = OrderedDict()
        if system in ('debug'):
            params_dict['PISM_DO'] = 'echo'
        else:
            params_dict['PISM_DO'] = ''
            
        params_dict['PISM_EXEC'] = pism_exec
        params_dict['PISM_PARAMS'] = '\'{}\''.format(all_params)
        params_dict['PISM_SAVE'] = ','.join(str(e) for e in save_times[grid_mapping[grid]+1::])
        params_dict['STARTEND'] = '{},{}'.format(start, end)

        params_dict['PISM_DATANAME'] = pism_dataname
        params_dict['PISM_SURFACE_BC_FILE'] = pism_surface_bcfile
        params_dict['PISM_CONFIG'] = 'spinup_config.nc'
        params_dict['TSSTEP'] = tsstep
        params_dict['EXSTEP'] = exstep
        params_dict['PARAM_NOAGE'] = ''
        params_dict['PARAM_CALVING'] = calving
        if calving in ('eigen_calving'):
            params_dict['PARAM_CALVING_THK'] = calving_thk_threshold
            params_dict['PARAM_CALVING_K'] = calving_k
        if forcing_type in ('e_age', 'e_age_ftt'):
            params_dict['PARAM_E_AGE_COUPLING'] = 'yes'
        if forcing_type in ('ftt', 'e_age_ftt'):
            params_dict['PARAM_FTT'] = 'yes'            
        
        params = ' '.join(['='.join([k, str(v)]) for k, v in params_dict.items()])
        
        cmd = ' '.join([params, './run_main.sh', str(nn), climate, str(dura), hydro, outfile, infile, '2>&1 | tee job.${PBS_JOBID}'])

        f.write(cmd)
        f.write('\n')

        if version in ('v2', 'v2_1985'):
            mytype = "MO14 2015-04-27"
        else:
            import sys
            print('TYPE {} not recognized, exiting'.format(version))
            sys.exit(0)

    tl_dir = '{}m_{}_{}'.format(grid, climate, bed_type)
    nc_dir = 'processed'
    rc_dir = domain.lower()
    fill = '-2e9'
        
    with open(post, 'w') as f:

        f.write('#!/bin/bash\n')
        f.write('#PBS -q transfer\n')
        f.write('#PBS -l walltime=4:00:00\n')
        f.write('#PBS -l nodes=1:ppn=1\n')
        f.write('#PBS -j oe\n')
        f.write('\n')
        f.write('source ~/python/bin/activate\n')
        f.write('\n')
        f.write('cd $PBS_O_WORKDIR\n')
        f.write('\n')

        f.write(' if [ ! -d {tl_dir}/{nc_dir}/{rc_dir} ]; then mkdir -p {tl_dir}/{nc_dir}/{rc_dir}; fi\n'.format(tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write('\n')
        f.write('if [ -f {} ]; then\n'.format(outfile))
        f.write('  rm -f tmp_{outfile} {tl_dir}/{nc_dir}/{rc_dir}/{outfile}\n'.format(outfile=outfile, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write('  ncks -v enthalpy,litho_temp -x {outfile} tmp_{outfile}\n'.format(outfile=outfile))
        f.write('  sh add_epsg3413_mapping.sh tmp_{}\n'.format(outfile))
        f.write('  ncpdq -o --64 -a time,y,x tmp_{outfile} {tl_dir}/{nc_dir}/{rc_dir}/{outfile}\n'.format(outfile=outfile, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write(  '''  ncap2 -O -s "uflux=ubar*thk; vflux=vbar*thk; velshear_mag=velsurf_mag-velbase_mag; where(thk<50) {{velshear_mag={fill}; velbase_mag={fill}; velsurf_mag={fill}; flux_mag={fill};}}; sliding_r = velbase_mag/velsurf_mag; tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag);" {tl_dir}/{nc_dir}/{rc_dir}/{outfile} {tl_dir}/{nc_dir}/{rc_dir}/{outfile}\n'''.format(outfile=outfile, fill=fill, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write('  ncatted -a bed_data_set,run_stats,o,c,"{mytype}" -a grid_dx_meters,run_stats,o,f,{grid} -a grid_dy_meters,run_stats,o,f,{grid} -a long_name,uflux,o,c,"Vertically-integrated horizontal flux of ice in the X direction" -a long_name,vflux,o,c,"Vertically-integrated horizontal flux of ice in the Y direction" -a units,uflux,o,c,"m2 year-1" -a units,vflux,o,c,"m2 year-1" -a units,sliding_r,o,c,"1" -a units,tau_r,o,c,"1" -a units,tau_rel,o,c,"1" {tl_dir}/{nc_dir}/{rc_dir}/{outfile}\n'.format(mytype=mytype, grid=grid, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir, outfile=outfile))
        f.write('fi\n')
        f.write('\n')
        
    
scripts = uniquify_list(scripts)
posts = uniquify_list(posts)

submit = 'submit_{domain}_g{grid}m_{climate}_{bed_type}.sh'.format(domain=domain.lower(), grid=grid, climate=climate, bed_type=bed_type)
try:
    os.remove(submit)
except OSError:
    pass

with open(submit, 'w') as f:

    f.write('#!/bin/bash\n')

    for k in range(len(scripts)):
        f.write('JOBID=$(qsub {script})\n'.format(script=scripts[k]))
        f.write('qsub -W depend=afterok:${{JOBID}} {post}\n'.format(post=posts[k]))

print("\nRun {} to submit all jobs to the scheduler\n".format(submit))

