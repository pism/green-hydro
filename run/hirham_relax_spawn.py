#!/usr/bin/env python
# Copyright (C) 2014-2015 Andy Aschwanden

import itertools
import os
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
parser.add_argument("--calving", dest="CALVING",
                    choices=['float_kill', 'ocean_kill', 'eigen_calving'],
                    help="Claving", default='eigen_calving')
parser.add_argument("--ocean", dest="OCEAN",
                    choices=['const_ctrl', 'const_m20'],
                    help="Ocean forcing type", default='const')
parser.add_argument("-d", "--domain", dest="DOMAIN",
                    choices=['greenland', 'jakobshavn'],
                    help="Sets the modeling domain", default='Greenland')
parser.add_argument("-f", "--o_format", dest="OFORMAT",
                    choices=['netcdf3', 'netcdf4_parallel', 'pnetcdf'],
                    help="Output format", default='netcdf4_parallel')
parser.add_argument("-g", "--grid", dest="GRID", type=int,
                    choices=[18000, 9000, 4500, 3600, 1800, 1500, 1200, 900, 600, 450],
                    help="Horizontal grid resolution", default=1500)
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
                    choices=['2_1985'],
                    help="Input data set version", default='2_1985')

options = parser.parse_args()
args = options.REGRIDFILE

NN = options.N
OFORMAT = options.OFORMAT
OSIZE = options.OSIZE
QUEUE = options.QUEUE
WALLTIME = options.WALLTIME
SYSTEM = options.SYSTEM

CALVING = options.CALVING
OCEAN = options.OCEAN
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
DURA = 20


# ########################################################
# set up parameter sensitivity study: tillphi
# ########################################################

CLIMATE = 'const'
HYDRO = 'null'
PISM_SURFACE_BCFILE = 'GR6b_ERAI_1989_2011_4800M_BIL_1989_baseline.nc'

SIA_E = (1.25)
PPQ = (0.6)
TEFO = (0.02)
SSA_N = (3.25)
SSA_E = (1.0)

calving_thk_threshold_values = [100, 300, 500]
calving_k_values = [1e15, 1e18]
phi_min_values = [5.0]
phi_max_values = [40.]
topg_min_values = [-700]
topg_max_values = [700]
combinations = list(itertools.product(calving_thk_threshold_values, calving_k_values, phi_min_values, phi_max_values, topg_min_values, topg_max_values))

TSSTEP = 'daily'
EXSTEP = 'yearly'
REGRIDVARS = 'litho_temp,enthalpy,tillwat,bmelt,Href'

SCRIPTS = []
POSTS = []
for n, combination in enumerate(combinations):

    calving_thk_threshold, calving_k , phi_min, phi_max, topg_min, topg_max = combination

    TTPHI = '{},{},{},{}'.format(phi_min, phi_max, topg_min, topg_max)

    EXPERIMENT='{CLIMATE}_{TYPE}_{VERSION}_sia_e_{SIA_E}_ppq_{PPQ}_tefo_{TEFO}_ssa_n_{SSA_N}_ssa_e_{SSA_E}_phi_min_{phi_min}_phi_max_{phi_max}_topg_min_{topg_min}_topg_max_{topg_max}_hydro_{hydro}_{calving}_k_{calving_k}_thk_threshold_{thk_threshold}_ocean_{OCEAN}'.format(CLIMATE=CLIMATE, TYPE=TYPE, SIA_E=SIA_E, PPQ=PPQ, TEFO=TEFO, SSA_N=SSA_N, SSA_E=SSA_E, phi_min=phi_min, phi_max=phi_max, topg_min=topg_min, topg_max=topg_max, hydro=HYDRO, calving=CALVING, thk_threshold=calving_thk_threshold, calving_k=calving_k, OCEAN=OCEAN, VERSION=VERSION)
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
        params_dict['PISM_OCEAN_BCFILE']= 'ocean_forcing_{GRID}m_1989-2011_v{VERSION}_{TYPE}_{OCEAN}_1989_baseline.nc'.format(GRID=GRID, VERSION=VERSION, TYPE=TYPE, OCEAN=OCEAN)
        params_dict['PISM_CONFIG'] = 'hindcast_config.nc'
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
        params_dict['PARAM_FTT'] = ''
        params_dict['PARAM_CALVING'] = CALVING
        params_dict['PARAM_CALVING_THK'] = calving_thk_threshold
        params_dict['PARAM_CALVING_K'] = calving_k
        
        params = ' '.join(['='.join([k, str(v)]) for k, v in params_dict.items()])
        cmd = ' '.join([params, './run.sh', str(NN), CLIMATE, str(DURA), str(GRID), 'hybrid', HYDRO, OUTFILE, INFILE, '2>&1 | tee job.${PBS_JOBID}'])

        f.write(cmd)
        f.write('\n')

        if CTYPE in 'v2_1985':
            MYTYPE = "MO14 2015-04-27"
        else:
            import sys
            print('TYPE {} not recognized, exiting'.format(TYPE))
            sys.exit(0)

    tl_dir = '{}m_{}_{}'.format(GRID, CLIMATE, TYPE)
    nc_dir = 'processed'
    rc_dir = DOMAIN.lower()
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

        f.write(' if [ ! -d {tl_dir}/{nc_dir}/{rc_dir} ]; then mkdir -p {tl_dir}/{nc_dir}/{rc_dir}; fi\n'.format(tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write('\n')
        f.write('if [ -f {} ]; then\n'.format(OUTFILE))
        f.write('  rm -f tmp_{outfile} {tl_dir}/{nc_dir}/{rc_dir}/{outfile}\n'.format(outfile=OUTFILE, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write('  ncks -v enthalpy,litho_temp -x {} tmp_{}\n'.format(OUTFILE, OUTFILE))
        f.write('  sh add_epsg3413_mapping.sh tmp_{}\n'.format(OUTFILE))
        f.write('  ncpdq -O --64 -a time,y,x tmp_{outfile} {tl_dir}/{nc_dir}/{rc_dir}/{outfile}\n'.format(outfile=OUTFILE, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write(  '''  ncap2 -O -s "uflux=ubar*thk; vflux=vbar*thk; velshear_mag=velsurf_mag-velbase_mag; where(thk<50) {{velshear_mag={fill}; velbase_mag={fill}; velsurf_mag={fill}; flux_mag={fill};}}; sliding_r = velbase_mag/velsurf_mag; tau_r = tauc/(taud_mag+1); tau_rel=(tauc-taud_mag)/(1+taud_mag);" {tl_dir}/{nc_dir}/{rc_dir}/{outfile} {tl_dir}/{nc_dir}/{rc_dir}/{outfile}\n'''.format(outfile=OUTFILE, fill=fill, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir))
        f.write('  ncatted -a bed_data_set,run_stats,o,c,"{MYTYPE}" -a grid_dx_meters,run_stats,o,f,{GRID} -a grid_dy_meters,run_stats,o,f,{GRID} -a long_name,uflux,o,c,"Vertically-integrated horizontal flux of ice in the X direction" -a long_name,vflux,o,c,"Vertically-integrated horizontal flux of ice in the Y direction" -a units,uflux,o,c,"m2 year-1" -a units,vflux,o,c,"m2 year-1" -a units,sliding_r,o,c,"1" -a units,tau_r,o,c,"1" -a units,tau_rel,o,c,"1" {tl_dir}/{nc_dir}/{rc_dir}/{outfile}\n'.format(MYTYPE=MYTYPE, GRID=GRID, tl_dir=tl_dir, nc_dir=nc_dir, rc_dir=rc_dir, outfile=OUTFILE))
        f.write('fi\n')
        f.write('\n')
        
    


SUBMIT = 'submit_{DOMAIN}_g{GRID}m_{CLIMATE}_{TYPE}_hirham_relax.sh'.format(DOMAIN=DOMAIN.lower(), GRID=GRID, CLIMATE=CLIMATE, TYPE=TYPE)
try:
    os.remove(SUBMIT)
except OSError:
    pass

with open(SUBMIT, 'w') as f:

    f.write('#!/bin/bash\n')

    for k in range(len(SCRIPTS)):
        f.write('JOBID=$(qsub {script})\n'.format(script=SCRIPTS[k]))
        f.write('qsub -W depend=afterok:${{JOBID}} {post}\n'.format(post=POSTS[k]))

print("\nRun {} to submit all jobs to the scheduler\n".format(SUBMIT))

