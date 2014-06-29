#!/usr/bin/env python

'''
Combine a list of matrix files to create an average matrix
'''


#=============================================================================
# IMPORTS
#=============================================================================
import numpy as np
import matplotlib.pylab as plt
import argparse
import os


#=============================================================================
# FUNCTIONS
#=============================================================================

# Set up the argparser so you can read arguments from the command line
def setup_argparser():
    '''
    # Code to read in arguments from the command line
    # Also allows you to change some settings
    '''
    
    # Build a basic parser.
    help_text = ('Combine a list of matrices into an average matrix')
    
    sign_off = 'Author: Kirstie Whitaker <kw401@cam.ac.uk>'
    
    parser = argparse.ArgumentParser(description=help_text, epilog=sign_off)
    
    # Now add the arguments
    # Required argument: M_file
    parser.add_argument('M_file_list',
                            type=str,
                            metavar='M_file_list',
                            help='Text file containing full paths of all matrices to be averaged)')
        
    arguments = parser.parse_args()
    
    return arguments, parser

#=============================================================================
# Define some variables
#=============================================================================
# Read in the arguments from argparse
arguments, parser = setup_argparser()
M_file_list_file = arguments.M_file_list

M_file_list = [ M.strip() for M in open(M_file_list_file) ]

# Load in the matrix
M = np.loadtxt(M_file)

# Zero out the lower triangle and the diagonal
M_triu = np.triu(M, 1)

# Threshold M_triu
thr_M_triu = threshold_Mtriu(M_triu, n_keep)

# Now reflect that matrix into the lower triangle
# and add them together
thr_M = thr_M_triu + thr_M_triu.T
# Make sure that the diagonal is the original
di = np.diag_indices(M.shape[0])
thr_M[di] = M[di]

# Save the matrix as a text file
name = '_thrNkeep{:05d}.txt'.format(n_keep)
M_text_name = M_file.replace('.txt', name)
save_mat(thr_M, M_text_name)
M_png_name = M_text_name.replace('.txt', '.png')
save_png(thr_M, M_png_name)



