#!/usr/bin/env python

import os

def create_mat_files(root_name, EVs):
    '''
    create_mat_files takes a filename root, and a list of EVs
    and writes them into a .mat file ready for randomise analyses
    '''
    
    # Make the output directory if it doesn't yet exist
    if not os.path.isdir(os.path.dirname(root_name)):
        os.makedirs(os.path.dirname(root_name))
    
    mat_file = root_name + '.mat'    
    with open(mat_file, 'w') as f:
        f.write('/NumWaves {}\n'.format(len(EVs)))
        f.write('/NumPoints {}\n'.format(len(EVs[0])))
        f.write('\n')
        f.write('/Matrix \n')
        for a in zip(*EVs):
            f.write(' '.join(str(s) for s in a) + '\n')

def create_fts_files(root_name, fts):
    '''
    create_fts_files takes a filename root and a list of ftest
    contrasts and creates a .fts file ready for randomise analyses
    '''
    
    # Make the output directory if it doesn't yet exist
    if not os.path.isdir(os.path.dirname(root_name)):
        os.makedirs(os.path.dirname(root_name))
    
    fts_file = root_name + '.fts'    
    with open(fts_file, 'w') as f:
        f.write('/NumWaves {}\n'.format(len(fts[0])))
        f.write('/NumContrasts {}\n'.format(len(fts)))
        f.write('\n')
        f.write('/Matrix \n')
        for a in fts:
            f.write(' '.join(str(s) for s in a) + '\n')
    
    

def create_con_files(root_name, cons):
    '''
    create_con_files takes a filename root, and a list of contrasts
    and creates a .con file ready for randomise analyses
    '''
    
    # Make the output directory if it doesn't yet exist
    if not os.path.isdir(os.path.dirname(root_name)):
        os.makedirs(os.path.dirname(root_name))
    
    con_file = root_name + '.con'    
    with open(con_file, 'w') as f:
        f.write('/NumWaves {}\n'.format(len(cons[0])))
        f.write('/NumContrasts {}\n'.format(len(cons)))
        f.write('\n')
        f.write('/Matrix \n')
        for a in cons:
            f.write(' '.join(str(s) for s in a) + '\n')
    
    
def create_with_covars(EVs_list, EVs_name, covars_list, covars_name_list, cons, fts=False):
    """
    This handy dandy little functions takes a list of EVs that you do care
    about, and the name that you'll save the file to, and a list of covariates
    that you'd like to add as regressors of no interest, and their names,
    along with the contrast list that was created with the EVs. It then
    appends every possible permutation of the covariates to the end of the
    EVs list and makes the appropriate mat and con files.
    """
    # IMPORTS
    import itertools as it
    import numpy as np
    
    # Calculate the number of covariates you have in the list
    n_covars = len(covars_name_list)
    
    # Loop through every number of combinations of these covariates
    for i in range(n_covars+1):
        
        combos = it.combinations(range(n_covars), i)
        
        # For each of these combinations make .mat and .con files
        for covar in combos:
            
            # Assume that we're going to create each one
            no_create=False
            
            # C is the list of covariates
            C = [covars_list[i] for i in list(covar)]
            
            # Check that there are no empty columns
            # ie: if the covariate is constant then we don't want
            # to include it in the model - it's a waste of time!
            for col in C:                
                if np.std(col) == 0.0:
                    no_create=True

            # C_name is the name of the covariates in combos
            C_name = [covars_name_list[i] for i in list(covar)]
            C_name = '_'.join(C_name)

            # new_cons is a copy of cons
            new_cons = list(cons)
            
            # The very first combination will be empty, so we
            # need to put this cushion in
            if C:
                # If there are covariates in C though, add them to
                # the EVs_list_with_covars
                EVs_list_with_covars = EVs_list + C
                # And append the name to the EVs_name
                name = EVs_name + '_Covar_' + C_name
                
                # Add a 0 to the end of each row of cons because
                # you aren't going to look at these covariates
                # specifically
                for i in range(len(cons)):
                    new_cons[i] = cons[i] + [0]*len(C)
            
            # Everything is easier if you have no covariates
            else:
                name = EVs_name
                EVs_list_with_covars = EVs_list
                
            # Now create the mat and con files
            # But only if there are no empty covar columns:
            if not no_create:
                print name
                create_mat_files(name, EVs_list_with_covars)
                create_con_files(name, new_cons)
                if fts:
                    create_fts_files(name, fts)
