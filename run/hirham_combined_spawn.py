#!/usr/bin/env python
# Copyright (C) 2015 Andy Aschwanden

import itertools
from collections import OrderedDict
import os
from argparse import ArgumentParser

# set up the option parser
parser = ArgumentParser()
parser.description = "Generating scripts for parameter study."
parser.add_argument("regridfile", nargs=1)
parser.add_argument("-n", '--n_procs', dest="n", type=int,
                    help='''number of cores/processors. default=64.''', default=64)
parser.add_argument("-w", '--wall_time', dest="walltime",
                    help='''walltime. default: 12:00:00.''', default="12:00:00")
parser.add_argument("-q", '--queue', dest="queue", choices=['standard_4', 'standard_16', 'standard', 'gpu', 'gpu_long', 'long', 'normal'],
                    help='''queue. default=standard_4.''', default='standard_4')
parser.add_argument("--calving", dest="calving",
                    choices=['float_kill', 'ocean_kill', 'eigen_calving', 'thickness_calving', 'ok_eigen_calving'],
                    help="claving", default='eigen_calving')
parser.add_argument("--ocean", dest="ocean",
                    choices=['const_ctrl', 'const_m20'],
                    help="ocean forcing type", default='const_ctrl')
parser.add_argument("-d", "--domain", dest="domain",
                    choices=['greenland', 'jakobshavn'],
                    help="sets the modeling domain", default='greenland')
parser.add_argument("-f", "--o_format", dest="oformat",
                    choices=['netcdf3', 'netcdf4_parallel', 'pnetcdf'],
                    help="output format", default='netcdf4_parallel')
parser.add_argument("-g", "--grid", dest="grid", type=int,
                    choices=[18000, 9000, 4500, 3600, 1800, 1500, 1200, 900, 600, 450],
                    help="horizontal grid resolution", default=1500)
parser.add_argument("--o_size", dest="osize",
                    choices=['small', 'medium', 'big', '2dbig'],
                    help="output size type", default='2dbig')
parser.add_argument("-s", "--system", dest="system",
                    choices=['pleiades', 'fish', 'pacman', 'debug'],
                    help="computer system to use.", default='pacman')
parser.add_argument("-b", "--bed_type", dest="bed_type",
                    choices=['ctrl', 'old_bed', 'ba01_bed', '970mW_hs', 'jak_1985', 'cresis'],
                    help="subglacial topograpy type", default='ctrl')
parser.add_argument("--dataset_version", dest="version",
                    choices=['2_1985'],
                    help="input data set version", default='2_1985')


options = parser.parse_args()
args = options.regridfile

nn = options.n
oformat = options.oformat
osize = options.osize
queue = options.queue
walltime = options.walltime
system = options.system

calving = options.calving
ocean = options.ocean
grid = options.grid
bed_type = options.bed_type
version = options.version
vversion = 'v{}'.format(version)

if calving in ('ok_eigen_calving'):
    calving_relax = 'ocean_kill'
    calving_hindcast = 'eigen_calving'
else:
    calving_relax = calving
    calving_hindcast = calving

domain = options.domain
if domain.lower() in ('greenland'):
    pism_exec = 'pismr'
elif domain.lower() in ('jakobshavn'):
    x_min = -280000
    x_max = 320000
    y_min = -2410000
    y_max = -2020000
    pism_exec = '''\'pismo -x_range {x_min},{x_max} -y_range {y_min},{y_max} -bootstrap\''''.format(x_min=x_min, x_max=x_max, y_min=y_min, y_max=y_max)
else:
    print('Domain {} not recognized, exiting'.format(domain))
    import sys
    sys.exit(0)

    
def uniquify_list(seq, idfun=None):
    '''
    Remove duplicates from a list, order preserving.
    From http://www.peterbe.com/plog/uniqifiers-benchmark
    '''

    if idfun is None:
        def idfun(x): return x
    seen = {}
    result = []
    for item in seq:
        marker = idfun(item)
        if marker in seen:
            continue
        seen[marker] = 1
        result.append(item)
    return result


def make_pbs_header(system, cores, walltime, queue):
    systems = {}
    systems['debug'] = {}
    systems['fish'] = {'gpu' : 16,
                       'gpu_long' : 16,
                       'standard' : 12}
    systems['pacman'] = {'standard_4' : 4,
                        'standard_16' : 16}
    systems['pleiades'] = {'long' : 20,
                           'normal': 20}

    assert system in systems.keys()
    if system not in 'debug':
        assert queue in systems[system].keys()
        assert cores > 0

        ppn = systems[system][queue]
        nodes = cores / ppn

    if system in ('debug'):

        header = ''
        
    elif system in ('pleiades'):
        
        header = """
#PBS -S /bin/bash
#PBS -N cfd
#PBS -l walltime={walltime}
#PBS -m e
#PBS -q {queue}
#PBS -lselect={nodes}:ncpus={ppn}:mpiprocs={ppn}:model=ivy
#PBS -j oe

cd $PBS_O_WORKDIR

""".format(queue=queue, walltime=walltime, nodes=nodes, ppn=ppn)
    else:
        header = """
#!/bin/bash
#PBS -q {queue}
#PBS -l walltime={walltime}
#PBS -l nodes={nodes}:ppn={ppn}
#PBS -j oe

cd $PBS_O_WORKDIR

""".format(queue=queue, walltime=walltime, nodes=nodes, ppn=ppn)

    return header

    
regridfile=args[0]
infile = ''
pism_dataname = 'pism_Greenland_{}m_mcb_jpl_v{}_{}.nc'.format(grid, version, bed_type)
dura = 20


# ########################################################
# set up parameter sensitivity study: 1985 relaxation run
# ########################################################

climate = 'const'
hydro = 'null'
relax_surface_bcfile = 'GR6b_ERAI_1989_2011_4800M_BIL_1989_baseline.nc'
hindcast_surface_bcfile= 'GR6b_ERAI_1989_2011_4800M_BIL_MM.nc'


sia_e = (1.25)
ppq = (0.6)
tefo = (0.02)
ssa_n = (3.25)
ssa_e = (1.0)
calving_thk_threshold_values = [100, 300, 500]
calving_k_values = [1e15, 1e18]
phi_min_values = [5.0]
phi_max_values = [40.]
topg_min_values = [-700]
topg_max_values = [700]
combinations = list(itertools.product(calving_thk_threshold_values, calving_k_values, phi_min_values, phi_max_values, topg_min_values, topg_max_values))

tsstep = 'daily'

era_start = 1989
era_end = 2011

scripts = []
posts = []
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
    name_options['hydro'] = hydro
    name_options['calving'] = calving
    if calving in ('eigen_calving', 'ok_eigen_calving'):
        name_options['calving_k'] = calving_k
        name_options['calving_thk_threshold'] = calving_thk_threshold
    if calving in ('thickness_calving'):
        name_options['calving_thk_threshold'] = calving_thk_threshold
    name_options['ocean'] = ocean

    experiment =  '_'.join([climate, bed_type, vversion, '_'.join(['_'.join([k, str(v)]) for k, v in name_options.items()])])

        
    script = 'do_{}_g{}m_{}.sh'.format(domain.lower(), grid, experiment)
    scripts.append(script)
    post = 'do_{}_g{}m_{}_post.sh'.format(domain.lower(), grid, experiment)
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


        relax_outfile = '{domain}_g{grid}m_{experiment}_{dura}a.nc'.format(domain=domain.lower(),grid=grid, experiment=experiment, dura=dura)

        exstep = 'yearly'
        regridvars = 'litho_temp,enthalpy,tillwat,bmelt,Href'
        params_dict = dict()
        params_dict['PISM_DO'] = ''
        params_dict['PISM_OFORMAT'] = oformat
        params_dict['PISM_OSIZE'] = osize
        params_dict['PISM_EXEC'] = pism_exec
        params_dict['PISM_DATANAME'] = pism_dataname
        params_dict['PISM_SURFACE_BC_FILE'] = relax_surface_bcfile
        params_dict['PISM_OCEAN_BCFILE']= 'ocean_forcing_{grid}m_{start}-{end}_v{version}_{bed_type}_{ocean}_1989_baseline.nc'.format(grid=grid, version=version, bed_type=bed_type, ocean=ocean, start=era_start, end=era_end)
        params_dict['PISM_CONFIG'] = 'hindcast_config.nc'
        params_dict['REGRIDFILE'] = regridfile
        params_dict['TSSTEP'] = tsstep
        params_dict['EXSTEP'] = exstep
        params_dict['REGRIDVARS'] = regridvars
        params_dict['SIA_E'] = sia_e
        params_dict['SSA_E'] = ssa_e
        params_dict['SSA_N'] = ssa_n
        params_dict['PARAM_NOAGE'] = 'foo'
        params_dict['PARAM_PPQ'] = ppq
        params_dict['PARAM_TEFO'] = tefo
        params_dict['PARAM_TTPHI'] = ttphi
        params_dict['PARAM_FTT'] = ''
        params_dict['PARAM_CALVING'] = calving_relax
        if calving_relax in ('eigen_calving'):
            params_dict['PARAM_CALVING_K'] = calving_k
        if calving_relax in ('eigen_calving', 'thickness_calving'):
            params_dict['PARAM_CALVING_THK'] = calving_thk_threshold

        params = ' '.join(['='.join([k, str(v)]) for k, v in params_dict.items()])
        cmd = ' '.join([params, './run.sh', str(nn), climate, str(dura), str(grid), 'hybrid', hydro, relax_outfile, infile, '2>&1 | tee job.${PBS_JOBID}'])

        f.write(cmd)
        f.write('\n\n')

        hindcast_outfile = '{domain}_g{grid}m_{experiment}_{start}-{end}.nc'.format(domain=domain.lower(),grid=grid, experiment=experiment, start=era_start, end=era_end)

        exstep = 'monthly'
        regridvars = 'litho_temp,enthalpy,tillwat,bmelt,Href,thk'
        params_dict['EXSTEP'] = exstep
        params_dict['REGRIDFILE'] = relax_outfile
        params_dict['REGRIDVARS'] = regridvars        
        params_dict['PISM_TIMEFILE'] = hindcast_surface_bcfile
        params_dict['PISM_SURFACE_BCFILE']= hindcast_surface_bcfile
        params_dict['PISM_OCEAN_BCFILE']= 'ocean_forcing_{grid}m_1989-2011_v{version}_{bed_type}_{ocean}.nc'.format(grid=grid, version=version, bed_type=bed_type, ocean=ocean)
        params_dict['PARAM_CALVING'] = calving_hindcast
        if calving_hindcast in ('eigen_calving'):
            params_dict['PARAM_CALVING_K'] = calving_k
        if calving_hindcast in ('eigen_calving', 'thickness_calving'):
            params_dict['PARAM_CALVING_THK'] = calving_thk_threshold

        params = ' '.join(['='.join([k, str(v)]) for k, v in params_dict.items()])
        cmd = ' '.join([params, './run.sh', str(nn), climate, str(dura), str(grid), 'hybrid', hydro, hindcast_outfile, infile, '2>&1 | tee job.${PBS_JOBID}'])

        f.write(cmd)
        f.write('\n')

        if version in 'v2_1985':
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
        f.write('if [ -f {} ]; then\n'.format(relax_outfile))
        f.write('  rm -f tmp_{relax_outfile} {tl_dir}/{nc_dir}/{rc_dir}/{relax_outfile}\n'.format(relax_outfile=relax_outfile, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write('  ncks -v enthalpy,litho_temp -x {relax_outfile} tmp_{relax_outfile}\n'.format(relax_outfile=relax_outfile))
        f.write('  sh add_epsg3413_mapping.sh tmp_{}\n'.format(relax_outfile))
        f.write('  ncpdq -o --64 -a time,y,x tmp_{relax_outfile} {tl_dir}/{nc_dir}/{rc_dir}/{relax_outfile}\n'.format(relax_outfile=relax_outfile, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write(  '''  ncap2 -O -s "uflux=ubar*thk; vflux=vbar*thk; velshear_mag=velsurf_mag-velbase_mag; where(thk<50) {{velshear_mag={fill}; velbase_mag={fill}; velsurf_mag={fill}; flux_mag={fill};}}; sliding_r = velbase_mag/velsurf_mag; tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag);" {tl_dir}/{nc_dir}/{rc_dir}/{relax_outfile} {tl_dir}/{nc_dir}/{rc_dir}/{relax_outfile}\n'''.format(relax_outfile=relax_outfile, fill=fill, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write('  ncatted -a bed_data_set,run_stats,o,c,"{mytype}" -a grid_dx_meters,run_stats,o,f,{grid} -a grid_dy_meters,run_stats,o,f,{grid} -a long_name,uflux,o,c,"Vertically-integrated horizontal flux of ice in the X direction" -a long_name,vflux,o,c,"Vertically-integrated horizontal flux of ice in the Y direction" -a units,uflux,o,c,"m2 year-1" -a units,vflux,o,c,"m2 year-1" -a units,sliding_r,o,c,"1" -a units,tau_r,o,c,"1" -a units,tau_rel,o,c,"1" {tl_dir}/{nc_dir}/{rc_dir}/{relax_outfile}\n'.format(mytype=mytype, grid=grid, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir, relax_outfile=relax_outfile))
        f.write('fi\n')
        f.write('\n')
        f.write('if [ -f {} ]; then\n'.format(hindcast_outfile))
        f.write('  rm -f tmp_{hindcast_outfile} tmp_ex_{hindcast_outfile} {tl_dir}/{nc_dir}/{rc_dir}/{hindcast_outfile} {tl_dir}/{nc_dir}/{rc_dir}/ex_{hindcast_outfile}\n'.format(hindcast_outfile=hindcast_outfile, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write('  ncks -v enthalpy,litho_temp -x {hindcast_outfile} tmp_{hindcast_outfile}\n'.format(hindcast_outfile=hindcast_outfile))
        f.write('  ncks -O --64 ex_{hindcast_outfile} {tl_dir}/{nc_dir}/{rc_dir}/ex_{hindcast_outfile}\n'.format(hindcast_outfile=hindcast_outfile, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write('  sh add_epsg3413_mapping.sh tmp_{}\n'.format(hindcast_outfile))
        f.write('  ncpdq -o --64 -a time,y,x tmp_{hindcast_outfile} {tl_dir}/{nc_dir}/{rc_dir}/{hindcast_outfile}\n'.format(hindcast_outfile=hindcast_outfile, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write(  '''  ncap2 -O -s "uflux=ubar*thk; vflux=vbar*thk; velshear_mag=velsurf_mag-velbase_mag; where(thk<50) {{velshear_mag={fill}; velbase_mag={fill}; velsurf_mag={fill}; flux_mag={fill};}}; sliding_r = velbase_mag/velsurf_mag; tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag);" {tl_dir}/{nc_dir}/{rc_dir}/{hindcast_outfile} {tl_dir}/{nc_dir}/{rc_dir}/{hindcast_outfile}\n'''.format(hindcast_outfile=hindcast_outfile, fill=fill, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write('  ncatted -a bed_data_set,run_stats,o,c,"{mytype}" -a grid_dx_meters,run_stats,o,f,{grid} -a grid_dy_meters,run_stats,o,f,{grid} -a long_name,uflux,o,c,"Vertically-integrated horizontal flux of ice in the X direction" -a long_name,vflux,o,c,"Vertically-integrated horizontal flux of ice in the Y direction" -a units,uflux,o,c,"m2 year-1" -a units,vflux,o,c,"m2 year-1" -a units,sliding_r,o,c,"1" -a units,tau_r,o,c,"1" -a units,tau_rel,o,c,"1" {tl_dir}/{nc_dir}/{rc_dir}/{hindcast_outfile}\n'.format(mytype=mytype, grid=grid, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir, hindcast_outfile=hindcast_outfile))
        f.write('fi\n')
        f.write('\n')
        

scripts = uniquify_list(scripts)
posts = uniquify_list(posts)
        
submit = 'submit_{domain}_g{grid}m_{climate}_{bed_type}_hirham.sh'.format(domain=domain.lower(), grid=grid, climate=climate, bed_type=bed_type)
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

