from collections import OrderedDict


def generate_domain(domain):
    '''
    Generate domain specific options
    '''
    
    if domain.lower() in ('greenland', 'gris'):
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

    return pism_exec


def generate_spatial_ts(outfile, exvars, step, start=None, end=None, split=None):
    '''
    Return dict to generate spatial time series
    '''

    ts_dict = OrderedDict()
    ts_dict['extra_file'] = 'ex_' + outfile
    ts_dict['extra_vars'] = exvars
        
    if step is None:
        step = 'yearly'

    if (start is not None and end is not None):
        times = '{start}:{step}:{end}'.format(start=start, step=step, end=end)
    else:
        times = step
        
    ts_dict['extra_times'] = times
        
    if split:
        ts_dict['extra_split'] = ''

    return ts_dict


def generate_scalar_ts(outfile, step, start=None, end=None):
    '''
    Return dict to create scalar time series
    '''

    ts_dict = OrderedDict()
    ts_dict['ts_file'] = 'ts_' + outfile
    
    if step is None:
        step = 'yearly'

    if (start is not None and end is not None):
        times = '{start}:{step}:{end}'.format(start=start, step=step, end=end)
    else:
        times = step
    ts_dict['ts_times'] = times

    return ts_dict


    
def generate_grid_description(grid_resolution):
    '''
    Generate grid description dict
    '''
    
    mx_max = 10560
    my_max = 18240
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

    horizontal_grid = OrderedDict()
    horizontal_grid['Mx'] = mx
    horizontal_grid['My'] = my

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

    vertical_grid = OrderedDict()
    vertical_grid['Lz'] = 4000
    vertical_grid['Lzb'] = 2000
    vertical_grid['z_spacing'] = 'equal'
    vertical_grid['Mz'] = mz
    vertical_grid['Mzb'] = mzb

    grid_options = {}
    grid_options['skip'] = ''
    grid_options['skip_max'] = skip_max

    grid_dict = merge_dicts( horizontal_grid, vertical_grid)

    return grid_dict


def merge_dicts(*dict_args):
    '''
    Given any number of dicts, shallow copy and merge into a new dict,
    precedence goes to key value pairs in latter dicts.
    '''
    result = OrderedDict()
    for dictionary in dict_args:
        result.update(dictionary)
    return result


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


def generate_stress_balance(stress_balance, params_dict):
    '''
    Generate stress balance params
    '''

    accepted_stress_balances = ('sia', 'ssa+sia')

    if stress_balance not in accepted_stress_balances:
        print('{} not in {}'.format(stress_balance, accepted_stress_balances))
        print('available stress balance solvers are {}'.format(accepted_stress_balances))
        import sys
        sys.exit(0)

    stress_balance_params_dict = OrderedDict()
    stress_balance_params_dict['stress_balance'] = stress_balance
    if stress_balance in ('ssa+sia'):
        stress_balance_params_dict['cfbc'] = ''
        stress_balance_params_dict['sia_flow_law'] = 'gpbld3'
        stress_balance_params_dict['pseudo_plastic'] = ''
        stress_balance_params_dict['pseudo_plastic_q'] = params_dict['pseudo_plastic_q']
        stress_balance_params_dict['till_effective_fraction_overburden'] = params_dict['till_effective_fraction_overburden']
        stress_balance_params_dict['topg_to_phi'] = params_dict['topg_to_phi']
        stress_balance_params_dict['tauc_slippery_grounding_lines'] = ''

        return merge_dicts(params_dict, stress_balance_params_dict)
        



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
