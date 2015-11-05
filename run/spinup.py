#!/usr/bin/env python
# Copyright (C) 2014-2015 Andy Aschwanden

import itertools
import os
import subprocess
from argparse import ArgumentParser

# Set up the option parser
parser = ArgumentParser()
parser.description = "Generating scripts for initialization."
parser.add_argument("-N", '--n_procs', dest="N", type=int,
                    help='''Number of cores/processors. Default=64.''', default=64)
parser.add_argument("-P", '--procs_per_node', dest="PROCS_PER_NODE", type=int,
                    help='''Cores/Processors per node. Default=4.''', default=4)
parser.add_argument("-W", '--wall_time', dest="WALLTIME",
                    help='''Walltime. Default: 12:00:00.''', default="12:00:00")
parser.add_argument("-Q", '--queue', dest="QUEUE",
                    help='''Queue. Default=standard_4.''', default='standard_4')
parser.add_argument("-f", "--o_format", dest="OFORMAT",
                    choices=['netcdf3', 'netcdf4_parallel', 'pnetcdf'],
                    help="Output format", default='netcdf4_parallel')
parser.add_argument("-c", "--climate", dest="CLIMATE",
                    choices=['const', 'paleo'],
                    help="Climate", default='paleo')
parser.add_argument("-g", "--grid", dest="GRID", type=int,
                    choices=[18000, 9000, 4500, 3600, 1800, 1500, 1200, 900, 600, 450],
                    help="Output size type", default=9000)
parser.add_argument("-s", "--o_size", dest="OSIZE",
                    choices=['small', 'medium', 'big', '2dbig'],
                    help="Output size type", default='2dbig')
parser.add_argument("-t", "--type", dest="TYPE",
                    choices=['ctrl', 'old_bed', 'ba01_bed', '970mW_hs', 'jak_1985', 'cresis'],
                    help="Output size type", default='970mW_hs')
parser.add_argument("--dataset_version", dest="VERSION",
                    choices=['1.1', '1.2', '2'],
                    help="Input data set version", default='2')

options = parser.parse_args()

NN = options.N
PROCS_PER_NODE = options.PROCS_PER_NODE
OFORMAT = options.OFORMAT
OSIZE = options.OSIZE
QUEUE = options.QUEUE
WALLTIME = options.WALLTIME

CLIMATE = options.CLIMATE
GRID = options.GRID
TYPE = options.TYPE
VERSION = options.VERSION

INFILE = ''
PISM_DATANAME = 'pism_Greenland_{}m_mcb_jpl_v{}_{}.nc'.format(GRID, VERSION, TYPE)
TYPE = '{}_v{}'.format(TYPE, VERSION)
DURA = 100
NODES= NN/ PROCS_PER_NODE

SHEBANGLINE = "#!/bin/bash"
MPIQUEUELINE = "#PBS -q {}".format(QUEUE)
MPITIMELINE = "#PBS -l walltime={}".format(WALLTIME)
MPISIZELINE = "#PBS -l nodes={}:ppn={}".format(NODES, PROCS_PER_NODE)
MPIOUTLINE = "#PBS -j oe"


#### TODO:
## Generate config file from cdl


# ########################################################
# set up parameter sensitivity study: tillphi
# ########################################################


SIA_E = (3.0)
PPQ = (0.6)
TEFO = (0.02)
SSA_N = (3.25)
SSA_E = (3.0)
HYDRO = 'null'

phi_min_values = [5.0]
phi_max_values = [40.]
topg_min_values = [-700]
topg_max_values = [700]
combinations = list(itertools.product(phi_min_values, phi_max_values, topg_min_values, topg_max_values))

TSSTEP = '1'
EXSTEP = '100'
REGRIDVARS = 'litho_temp,enthalpy,tillwat,bmelt,Href'

for n, combination in enumerate(combinations):
    phi_min = combination[0]
    phi_max = combination[1]
    topg_min = combination[2]
    topg_max = combination[3]

    TTPHI = '{},{},{},{}'.format(phi_min, phi_max, topg_min, topg_max)

    EXPERIMENT='{}_{}_sia_e_{}_ppq_{}_tefo_{}_ssa_n_{}_ssa_e_{}_phi_min_{}_phi_max_{}_topg_min_{}_topg_max_{}'.format(CLIMATE, TYPE, SIA_E, PPQ, TEFO, SSA_N, SSA_E, phi_min, phi_max, topg_min, topg_max)

    
    DURA=100000
    START=-125000
    END=-25000

    SCRIPT = 'do_g{GRID}m_m{END}a_{EXPERIMENT}.sh'.format(GRID=GRID, END=END, EXPERIMENT=EXPERIMENT)
    
    for filename in (SCRIPT):
        try:
            os.remove(filename)
        except OSError:
            pass

    
    os.environ['PISM_EXPERIMENT'] = EXPERIMENT
    os.environ['PISM_TITLE'] = 'Greenland Paleo-Climate Initialization'
    
    with open(SCRIPT, 'w') as f:

        f.write('{}\n'.format(SHEBANGLINE))
        f.write('\n')
        f.write('{}\n'.format(MPIQUEUELINE))
        f.write('{}\n'.format(MPITIMELINE))
        f.write('{}\n'.format(MPISIZELINE))
        f.write('{}\n'.format(MPIOUTLINE))
        f.write('\n')
        f.write('cd $PBS_O_WORKDIR\n')
        f.write('\n')

        OUTFILE = 'g{GRID}m_m{END}_{EXPERIMENT}a.nc'.format(GRID=GRID, EXPERIMENT=EXPERIMENT, END=-END)

        params_dict = dict()
        params_dict['PISM_DO'] = ''
        params_dict['PISM_OFORMAT'] = OFORMAT
        params_dict['PISM_OSIZE'] = OSIZE
        params_dict['PISM_CONFIG'] = 'spinup_config.nc'
        params_dict['PARAM_NOAGE'] = ''
        params_dict['PISM_DATANAME'] = PISM_DATANAME
        params_dict['TSSTEP'] = TSSTEP
        params_dict['EXSTEP'] = EXSTEP
        params_dict['SIA_E'] = SIA_E
        params_dict['SSA_E'] = SSA_E
        params_dict['SSA_N'] = SSA_N
        params_dict['PARAM_PPQ'] = PPQ
        params_dict['PARAM_TEFO'] = TEFO
        params_dict['PARAM_TTPHI'] = TTPHI
        params_dict['PARAM_FTT'] = ''
        params_dict['PISM_SAVE'] = '-25000,-11000,-5000,-1000,-500,-200,-100'
        params_dict['STARTEND'] = '{},{}'.format(START,END)
        params_dict['DURA'] = DURA
        

        params = ' '.join(['='.join([k, str(v)]) for k, v in params_dict.items()])
        cmd = ' '.join([params, './run.sh', str(NN), CLIMATE, str(params_dict['DURA']), str(GRID), 'hybrid', HYDRO, OUTFILE, INFILE, '2>&1 | tee job.${PBS_JOBID}'])

        f.write(cmd)
        f.write('\n')




# SUBMIT = 'submit_g{GRID}m_{CLIMATE}_{TYPE}_tillphi.sh'.format(GRID=GRID, CLIMATE=CLIMATE, TYPE=TYPE)
# try:
#     os.remove(SUBMIT)
# except OSError:
#     pass

# with open(SUBMIT, 'w') as f:

#     f.write('#!/bin/bash\n')

#     for k in range(len(SCRIPTS)):
#         f.write('JOBID=$(qsub {script})\n'.format(script=SCRIPTS[k]))
#         f.write('qsub -W depend=afterok:${{JOBID}} {post}\n'.format(post=POSTS[k]))

# print("\nRun {} to submit all jobs to the scheduler\n".format(SUBMIT))

