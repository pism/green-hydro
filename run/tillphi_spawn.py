#!/usr/bin/env python
# Copyright (C) 2014-2015 Andy Aschwanden

import itertools
import os
import subprocess
from argparse import ArgumentParser

# Set up the option parser
parser = ArgumentParser()
parser.description = "Generating scripts for parameter study."
parser.add_argument("REGRIDFILE", nargs=1)
parser.add_argument("-N", '--n_procs', dest="N", type=int,
                    help='''Number of cores/processors. Default=64.''', default=64)
parser.add_argument("-W", '--wall_time', dest="WALLTIME",
                    help='''Walltime. Default: 12:00:00.''', default="12:00:00")
parser.add_argument("-Q", '--queue', dest="QUEUE", choices=['standard_4', 'standard_16', 'gpu', 'gpu_long', 'long', 'normal'],
                    help='''Queue. Default=standard_4.''', default='standard_4')
parser.add_argument("-c", "--climate", dest="CLIMATE",
                    choices=['const', 'pdd'],
                    help="Climate", default='const')
parser.add_argument("-d", "--domain", dest="DOMAIN",
                    choices=['greenland', 'jakobshavn'],
                    help="Sets the modeling domain", default='Greenland')
parser.add_argument("-f", "--o_format", dest="OFORMAT",
                    choices=['netcdf3', 'netcdf4_parallel', 'pnetcdf'],
                    help="Output format", default='netcdf4_parallel')
parser.add_argument("-g", "--grid", dest="GRID", type=int,
                    choices=[18000, 9000, 4500, 3600, 1800, 1500, 1200, 900, 600, 450],
                    help="Output size type", default=1500)
parser.add_argument("--o_size", dest="OSIZE",
                    choices=['small', 'medium', 'big', '2dbig'],
                    help="Output size type", default='2dbig')
parser.add_argument("-s", "--system", dest="SYSTEM",
                    choices=['pleiades', 'fish', 'pacman'],
                    help="Computer system to use.", default='pacman')
parser.add_argument("-t", "--type", dest="TYPE",
                    choices=['ctrl', 'old_bed', 'ba01_bed', '970mW_hs', 'jak_1985', 'cresis'],
                    help="Output size type", default='ctrl')
parser.add_argument("--dataset_version", dest="VERSION",
                    choices=['1.1', '1.2', '2'],
                    help="Input data set version", default='2')

options = parser.parse_args()
args = options.REGRIDFILE

NN = options.N
OFORMAT = options.OFORMAT
OSIZE = options.OSIZE
QUEUE = options.QUEUE
WALLTIME = options.WALLTIME
SYSTEM = options.SYSTEM

CLIMATE = options.CLIMATE
GRID = options.GRID
TYPE = options.TYPE
VERSION = options.VERSION

DOMAIN = options.DOMAIN
if DOMAIN.lower() in ('greenland'):
    pism_exec = 'pismr'
elif DOMAIN.lower() in ('jakobshavn'):
    x_min = -280000
    x_max = 320000
    y_min = -2410000
    y_max = -2020000
    pism_exec = '''\'pismo -x_range {x_min},{x_max} -y_range {y_min},{y_max} -bootstrap\''''.format(x_min=x_min, x_max=x_max, y_min=y_min, y_max=y_max)
else:
    print('Domain {} not recognized, exiting'.format(DOMAIN))
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
              
    Mx = Mx_max / grid_div
    My = My_max / grid_div

    horizontal_grid = {}
    horizontal_grid['-Mx'] = Mx
    horizontal_grid['-My'] = My

    vertical_grid = {}
    vertical_grid['-Lz'] = 4000
    vertical_grid['-Lzb'] = 2000
    vertical_grid['-z_spacing'] = 'equal'
    vertical_grid['-Mz'] = 6
    vertical_grid['-Mzb'] = 6

    grid_dict = merge_dicts( horizontal_grid, vertical_grid)

    return ' '.join(['='.join([k, str(v)]) for k, v in grid_dict.items()])

              
def make_pbs_header(system, cores, walltime, queue):
    systems = {}
    systems['fish'] = {'gpu' : 16,
                       'gpu_long' : 16}
    systems['pacman'] = {'standard_4' : 4,
                        'standard_16' : 16}
    systems['pleiades'] = {'long' : 20,
                           'normal': 20}

    assert system in systems.keys()
    assert queue in systems[system].keys()
    assert cores > 0

    ppn = systems[system][queue]
    nodes = cores / ppn

    if system in ('pleiades'):
        
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

    
REGRIDFILE=args[0]
INFILE = ''
PISM_DATANAME = 'pism_Greenland_{}m_mcb_jpl_v{}_{}.nc'.format(GRID, VERSION, TYPE)
TYPE = '{}_v{}'.format(TYPE, VERSION)
DURA = 10


# ########################################################
# set up parameter sensitivity study: tillphi
# ########################################################

HYDRO = 'distributed'
PISM_SURFACE_BCFILE = 'GR6b_ERAI_1989_2011_4800M_BIL_1989_baseline.nc'

SIA_E = (1.75)
PPQ = (0.6)
TEFO = (0.02)
SSA_N = (3.25)
SSA_E = (1.0)

omega_values = [0.1, 1.0, 10.0]
alpha_values = [1, 2, 3]
k_values = [0.0001, 0.001, 0.01, 0.1]
phi_min_values = [5.0, 7.5, 10.0]
phi_max_values = [40.]
topg_min_values = [-900, -700, -500]
topg_max_values = [500, 700, 900]
combinations = list(itertools.product(omega_values, alpha_values, k_values, phi_min_values, phi_max_values, topg_min_values, topg_max_values))

TSSTEP = 'daily'
EXSTEP = 'yearly'
REGRIDVARS = 'litho_temp,enthalpy,tillwat,bmelt,Href'

SCRIPTS = []
POSTS = []
for n, combination in enumerate(combinations):

    omega, alpha, k, phi_min, phi_max, topg_min, topg_max = combination

    TTPHI = '{},{},{},{}'.format(phi_min, phi_max, topg_min, topg_max)

    EXPERIMENT='{}_{}_sia_e_{}_ppq_{}_tefo_{}_ssa_n_{}_ssa_e_{}_phi_min_{}_phi_max_{}_topg_min_{}_topg_max_{}_hydro_{}_omega_{}_alpha_{}_k_{}'.format(CLIMATE, TYPE, SIA_E, PPQ, TEFO, SSA_N, SSA_E, phi_min, phi_max, topg_min, topg_max, HYDRO, omega, alpha, k)
    SCRIPT = 'do_{}_g{}m_{}.sh'.format(DOMAIN.lower(), GRID, EXPERIMENT)
    SCRIPTS.append(SCRIPT)
    POST = 'do_{}_g{}m_{}_post.sh'.format(DOMAIN.lower(), GRID, EXPERIMENT)
    POSTS.append(POST)
    
    for filename in (SCRIPT, POST):
        try:
            os.remove(filename)
        except OSError:
            pass

    pbs_header = make_pbs_header(SYSTEM, NN, WALLTIME, QUEUE)
        
    
    os.environ['PISM_EXPERIMENT'] = EXPERIMENT
    os.environ['PISM_TITLE'] = 'Greenland Paramter Study'
    
    with open(SCRIPT, 'w') as f:

        f.write(pbs_header)


        OUTFILE = '{DOMAIN}_g{GRID}m_{EXPERIMENT}_{DURA}a.nc'.format(DOMAIN=DOMAIN.lower(),GRID=GRID, EXPERIMENT=EXPERIMENT, DURA=DURA)
            
        params_dict = dict()
        params_dict['PISM_DO'] = ''
        params_dict['PISM_OFORMAT'] = OFORMAT
        params_dict['PISM_OSIZE'] = OSIZE
        params_dict['PISM_EXEC'] = pism_exec
        params_dict['PISM_DATANAME'] = PISM_DATANAME
        params_dict['PISM_SURFACE_BC_FILE'] = PISM_SURFACE_BCFILE
        params_dict['REGRIDFILE'] = REGRIDFILE
        params_dict['TSSTEP'] = TSSTEP
        params_dict['EXSTEP'] = EXSTEP
        params_dict['REGRIDVARS'] = REGRIDVARS
        params_dict['SIA_E'] = SIA_E
        params_dict['SSA_E'] = SSA_E
        params_dict['SSA_N'] = SSA_N
        params_dict['PARAM_NOAGE'] = 'foo'
        params_dict['PARAM_PPQ'] = PPQ
        params_dict['PARAM_TEFO'] = TEFO
        params_dict['PARAM_TTPHI'] = TTPHI
        params_dict['PARAM_FTT'] = 'foo'
        params_dict['PARAM_ALPHA'] = alpha
        params_dict['PARAM_K'] = k
        params_dict['PARAM_OMEGA'] = omega
        
        
        params = ' '.join(['='.join([k, str(v)]) for k, v in params_dict.items()])
        cmd = ' '.join([params, './run.sh', str(NN), CLIMATE, str(DURA), str(GRID), 'hybrid', HYDRO, OUTFILE, INFILE, '2>&1 | tee job.${PBS_JOBID}'])

        f.write(cmd)
        f.write('\n')

        if TYPE in 'ctrl_v2':
            MYTYPE = "MO14 2015-04-27"
        elif TYPE in 'cresis_v2':
            MYTYPE = "MO14+CReSIS 2015-04-27"
        elif TYPE in 'ctrl_v1.2':
            MYTYPE = "MO14 2014-11-19"
        elif TYPE in ('ctrl', 'ctrl_v1.1'):
            MYTYPE = "MO14 2014-06-26"
        elif TYPE in ('old_bed', 'old_bed_v1.1', 'old_bed_v1.2', 'old_bed_v2'):
            MYTYPE = "BA01"
        elif TYPE in 'searise':
            MYTYPE = "SR13"
        else:
            import sys
            print('TYPE {} not recognized, exiting'.format(TYPE))
            sys.exit(0)

    tl_dir = '{}m_{}_{}'.format(GRID, CLIMATE, TYPE)
    nc_dir = 'processed'
    fill = '-2e9'
        
    with open(POST, 'w') as f:

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

        f.write(' if [ ! -d {tl_dir}/{nc_dir} ]; then mkdir -p {tl_dir}/{nc_dir}; fi\n'.format(tl_dir=tl_dir, nc_dir=nc_dir))
        f.write('\n')
        f.write('if [ -f {} ]; then\n'.format(OUTFILE))
        f.write('  rm -f tmp_{outfile} {tl_dir}/{nc_dir}/{outfile}\n'.format(outfile=OUTFILE, tl_dir=tl_dir, nc_dir=nc_dir))
        f.write('  ncks -v enthalpy,litho_temp -x {} tmp_{}\n'.format(OUTFILE, OUTFILE))
        f.write('  sh add_epsg3413_mapping.sh tmp_{}\n'.format(OUTFILE))
        f.write('  ncpdq -O --64 -a time,y,x tmp_{outfile} {tl_dir}/{nc_dir}/{outfile}\n'.format(outfile=OUTFILE, tl_dir=tl_dir, nc_dir=nc_dir))
        f.write(  '''  ncap2 -O -s "uflux=ubar*thk; vflux=vbar*thk; velshear_mag=velsurf_mag-velbase_mag; where(thk<50) {{velshear_mag={fill}; velbase_mag={fill}; velsurf_mag={fill}; flux_mag={fill};}}; sliding_r = velbase_mag/velsurf_mag; tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag);" {tl_dir}/{nc_dir}/{outfile} {tl_dir}/${nc_dir}/{outfile}\n'''.format(outfile=OUTFILE, fill=fill, tl_dir=tl_dir, nc_dir=nc_dir))
        f.write('  ncatted -a bed_data_set,run_stats,o,c,"{MYTYPE}" -a grid_dx_meters,run_stats,o,f,{GRID} -a grid_dy_meters,run_stats,o,f,{GRID} -a long_name,uflux,o,c,"Vertically-integrated horizontal flux of ice in the X direction" -a long_name,vflux,o,c,"Vertically-integrated horizontal flux of ice in the Y direction" -a units,uflux,o,c,"m2 year-1" -a units,vflux,o,c,"m2 year-1" -a units,sliding_r,o,c,"1" -a units,tau_r,o,c,"1" -a units,tau_rel,o,c,"1" {tl_dir}/{nc_dir}/{outfile}\n'.format(MYTYPE=MYTYPE, GRID=GRID, tl_dir=tl_dir, nc_dir=nc_dir, outfile=OUTFILE))
        f.write('fi\n')
        f.write('\n')
        
    


SUBMIT = 'submit_{DOMAIN}_g{GRID}m_{CLIMATE}_{TYPE}_tillphi.sh'.format(DOMAIN=DOMAIN.lower(), GRID=GRID, CLIMATE=CLIMATE, TYPE=TYPE)
try:
    os.remove(SUBMIT)
except OSError:
    pass

with open(SUBMIT, 'w') as f:

    f.write('#!/bin/bash\n')

    for k in range(len(SCRIPTS)):
        f.write('JOBID=$(qsub {script})\n'.format(script=SCRIPTS[k]))
        #f.write('qsub -W depend=afterok:${{JOBID}} {post}\n'.format(post=POSTS[k]))

print("\nRun {} to submit all jobs to the scheduler\n".format(SUBMIT))

