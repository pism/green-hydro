#!/usr/bin/env python
# Copyright (C) 2014-2015 Andy Aschwanden

import itertools
import os
from argparse import ArgumentParser

# Set up the option parser
parser = ArgumentParser()
parser.description = "Generating scripts for parameter study."
parser.add_argument("regridfile", nargs=1)
parser.add_argument("-n", '--n_procs', dest="n", type=int,
                    help='''number of cores/processors. default=64.''', default=64)
parser.add_argument("-w", '--wall_time', dest="walltime",
                    help='''walltime. default: 12:00:00.''', default="12:00:00")
parser.add_argument("-q", '--queue', dest="queue", choices=['standard_4', 'standard_16', 'standard', 'gpu', 'gpu_long', 'long', 'normal'],
                    help='''queue. default=standard_4.''', default='standard_4')
parser.add_argument("-c", "--climate", dest="climate",
                    choices=['const', 'pdd'],
                    help="climate", default='const')
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
parser.add_argument("-t", "--etype", dest="etype",
                    choices=['ctrl', 'old_bed', 'ba01_bed', '970mw_hs', 'jak_1985', 'cresis'],
                    help="subglacial topography type", default='ctrl')
parser.add_argument("--dataset_version", dest="version",
                    choices=['1.1', '1.2', '2'],
                    help="Input data set version", default='2')

options = parser.parse_args()
args = options.regridfile

nn = options.n
oformat = options.oformat
osize = options.osize
queue = options.queue
walltime = options.walltime
system = options.system

climate = options.climate
grid = options.grid
etype = options.etype
version = options.version

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


def merge_dicts(*dict_args):
    '''
    Given any number of dicts, shallow copy and merge into a new dict,
    precedence goes to key value pairs in latter dicts.
    '''
    result = {}
    for dictionary in dict_args:
        result.update(dictionary)
    return result


def generate_grid_description(grid_resolution):

    Mx_max = 10560
    My_max = 18240
    resolution_max = 150
    
    accepted_resolutions = (150, 300, 450, 600, 900, 1200, 1500, 1800, 2400, 3000, 3600, 4500, 9000, 18000, 36000)

    try:
        grid_resolution in accepted_resolutions
        pass
    except:
        print('grid resolution {}m not recognized'.format(grid_resolution))

    grid_div = (grid_resolution / resolution_max)
              
    mx = mx_max / grid_div
    my = my_max / grid_div

    horizontal_grid = {}
    horizontal_grid['-Mx'] = mx
    horizontal_grid['-My'] = my

    if grid_resolution < 1200:
        skip_max = 200
        mz = 401
        mzb = 41
    elif (grid_resolution >= 1200) and (grid_resolution < 4500):
        skip_max = 50
        mz = 201
        mzb = 21
    elif (grid_resolution >= 4500) and (grid_resolution < 18000):
        skip_max = 20
        mz = 201
        mzb = 21
    else:
        skip_max = 10
        mz = 101
        mzb = 11

    vertical_grid = {}
    vertical_grid['-Lz'] = 4000
    vertical_grid['-Lzb'] = 2000
    vertical_grid['-z_spacing'] = 'equal'
    vertical_grid['-Mz'] = mz
    vertical_grid['-Mzb'] = mzb

    grid_options = {}
    grid_options['-skip'] = ''
    grid_options['-skip_max'] = skip_max

    grid_dict = merge_dicts( horizontal_grid, vertical_grid)

    return ' '.join(['='.join([k, str(v)]) for k, v in grid_dict.items()])


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
pism_dataname = 'pism_Greenland_{}m_mcb_jpl_v{}_{}.nc'.format(grid, version, etype)
etype = '{}_v{}'.format(etype, version)
dura = 10


# ########################################################
# set up parameter sensitivity study: tillphi
# ########################################################

hydro = 'distributed'
pism_surface_bcfile = 'GR6b_ERAI_1989_2011_4800M_BIL_1989_baseline.nc'

sia_e = (1.25)
ppq = (0.6)
tefo = (0.02)
ssa_n = (3.25)
ssa_e = (1.0)

omega_values = [0.1, 1.0, 10.0]
alpha_values = [1]
k_values = [0.0001, 0.001, 0.01, 0.1]
phi_min_values = [5.0]
phi_max_values = [40.]
topg_min_values = [-700]
topg_max_values = [700]
combinations = list(itertools.product(omega_values, alpha_values, k_values, phi_min_values, phi_max_values, topg_min_values, topg_max_values))

tsstep = 'daily'
exstep = 'yearly'
regridvars = 'litho_temp,enthalpy,tillwat,bmelt,Href'

scripts = []
posts = []
for n, combination in enumerate(combinations):

    omega, alpha, k, phi_min, phi_max, topg_min, topg_max = combination

    ttphi = '{},{},{},{}'.format(phi_min, phi_max, topg_min, topg_max)

    experiment='{}_{}_sia_e_{}_ppq_{}_tefo_{}_ssa_n_{}_ssa_e_{}_phi_min_{}_phi_max_{}_topg_min_{}_topg_max_{}_hydro_{}_omega_{}_alpha_{}_k_{}'.format(climate, etype, sia_e, ppq, tefo, ssa_n, ssa_e, phi_min, phi_max, topg_min, topg_max, hydro, omega, alpha, k)
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


        outfile = '{domain}_g{grid}m_{experiment}_{dura}a.nc'.format(domain=domain.lower(),grid=grid, experiment=experiment, dura=dura)
            
        params_dict = dict()
        params_dict['PISM_DO'] = ''
        params_dict['PISM_OFORMAT'] = oformat
        params_dict['PISM_OSIZE'] = osize
        params_dict['PISM_EXEC'] = pism_exec
        params_dict['PISM_DATANAME'] = pism_dataname
        params_dict['PISM_SURFACE_BC_FILE'] = pism_surface_bcfile
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
        params_dict['PARAM_FTT'] = 'foo'
        params_dict['PARAM_ALPHA'] = alpha
        params_dict['PARAM_K'] = k
        params_dict['PARAM_OMEGA'] = omega
        
        
        params = ' '.join(['='.join([k, str(v)]) for k, v in params_dict.items()])
        cmd = ' '.join([params, './run.sh', str(nn), climate, str(dura), str(grid), 'hybrid', hydro, outfile, infile, '2>&1 | tee job.${PBS_JOBID}'])

        f.write(cmd)
        f.write('\n')

        if etype in 'ctrl_v2':
            mytype = "MO14 2015-04-27"
        elif etype in 'cresis_v2':
            mytype = "MO14+CReSIS 2015-04-27"
        elif etype in 'ctrl_v1.2':
            mytype = "MO14 2014-11-19"
        elif etype in ('ctrl', 'ctrl_v1.1'):
            mytype = "MO14 2014-06-26"
        elif etype in ('old_bed', 'old_bed_v1.1', 'old_bed_v1.2', 'old_bed_v2'):
            mytype = "BA01"
        elif etype in 'searise':
            mytype = "SR13"
        else:
            import sys
            print('etype {} not recognized, exiting'.format(etype))
            sys.exit(0)

    tl_dir = '{}m_{}_{}'.format(grid, climate, etype)
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
        f.write(  '''  ncap2 -o -s "uflux=ubar*thk; vflux=vbar*thk; velshear_mag=velsurf_mag-velbase_mag; where(thk<50) {{velshear_mag={fill}; velbase_mag={fill}; velsurf_mag={fill}; flux_mag={fill};}}; sliding_r = velbase_mag/velsurf_mag; tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag);" {tl_dir}/{nc_dir}/{rc_dir}/{outfile} {tl_dir}/{nc_dir}/{rc_dir}/{outfile}\n'''.format(outfile=outfile, fill=fill, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write('  ncatted -a bed_data_set,run_stats,o,c,"{mytype}" -a grid_dx_meters,run_stats,o,f,{grid} -a grid_dy_meters,run_stats,o,f,{grid} -a long_name,uflux,o,c,"vertically-integrated horizontal flux of ice in the x direction" -a long_name,vflux,o,c,"vertically-integrated horizontal flux of ice in the y direction" -a units,uflux,o,c,"m2 year-1" -a units,vflux,o,c,"m2 year-1" -a units,sliding_r,o,c,"1" -a units,tau_r,o,c,"1" -a units,tau_rel,o,c,"1" {tl_dir}/{nc_dir}/{rc_dir}/{outfile}\n'.format(mytype=mytype, grid=grid, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir, outfile=outfile))
        f.write('fi\n')
        f.write('\n')

        
scripts = uniquify_list(scripts)
posts = uniquify_list(posts)

submit = 'submit_{domain}_g{grid}m_{climate}_{etype}_tillphi.sh'.format(domain=domain.lower(), grid=grid, climate=climate, etype=etype)
try:
    os.remove(submit)
except OSError:
    pass

with open(submit, 'w') as f:

    f.write('#!/bin/bash\n')

    for k in range(len(scripts)):
        f.write('JOBID=$(qsub {script})\n'.format(script=scripts[k]))
        #f.write('qsub -W depend=afterok:${{JOBID}} {post}\n'.format(post=posts[k]))

print("\nRun {} to submit all jobs to the scheduler\n".format(submit))

