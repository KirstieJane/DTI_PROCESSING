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
import sys

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
    parser.add_argument(dest = 'M_file_list',
                            type=str,
                            metavar='M_file_list',
                            help='Text file containing full paths of all matrices to be averaged)')
        
    arguments = parser.parse_args()
    
    return arguments, parser

#-----------------------------------------------------------------------------

def save_mat(M, M_text_name):
    # Save the matrix as a text file
    # NOTE THAT THIS IS NOT THE SAME
    # COMMAND AS IN calculate_connectivity_matrix.py
    if not os.path.exists(M_text_name):
        np.savetxt(M_text_name,
                       M[:,:],
                       fmt='%.5f',
                       delimiter='\t',
                       newline='\n')

#-----------------------------------------------------------------------------

def save_png(M, M_fig_name):
    # Make a png image of the matrix
    # NOTE THAT THIS IS NOT THE SAME
    # COMMAND AS IN calculate_connectivity_matrix.py
    if not os.path.exists(M_fig_name):

        fig, ax = plt.subplots(figsize=(4,4))    
        # Plot the matrix on a log scale
        axM = ax.imshow(np.log1p(M[:,:]), 
                        interpolation='nearest',
                        cmap='jet')
        
        # Add a colorbar
        cbar = fig.colorbar(axM)

        fig.savefig(M_fig_name, bbox_inches=0, dpi=600)
    
    
#=============================================================================
# Define some variables
#=============================================================================
# Read in the arguments from argparse
arguments, parser = setup_argparser()
M_file_list_file = arguments.M_file_list

if not M_file_list_file.endswith('_list'):
    print "M file list file needs to end with the word list"
    sys.exit

M_file_list = [ M.strip() for M in open(M_file_list_file) ]

#=============================================================================
# Create the three different average matrices
#=============================================================================

# Create empty matrices first
#----- AVERAGE -------------------
av_M = np.loadtxt(M_file_list[0]) * 0
#----- NORMALISE & AVERAGE -------
av_norm_M = np.loadtxt(M_file_list[0]) * 0
#----- BINARIZE & AVERAGE --------
av_bin_M = np.loadtxt(M_file_list[0]) * 0

# Loop through all the matrix files
for M_file in M_file_list:
    # Load in the matrix
    M = np.loadtxt(M_file)
    
    #----- AVERAGE -------------------
    # This one is easy: just add the 
    # matrix to the average
    av_M += M

    #----- NORMALISE & AVERAGE -------
    # Normalize M and add that to the
    # av_norm_M matrix
    M_norm = M / (np.percentile(M[M>0], 50))
    av_norm_M += M_norm
    
    #----- BINARIZE & AVERAGE -------
    # Finally binarize the matrix and
    # add that to the av_bin_M matrix
    M_bin = np.copy(M)
    M_bin[M_bin>0] = 1
    av_bin_M += M_bin
    
# Divide the average matrices by the number of files in the list
n = np.float(len(M_file_list))
av_M = av_M / n
av_norm_M = av_norm_M / n
av_bin_M = av_bin_M / n

# Threshold the average matrix so that you're only showing
# edges that are present in at least 5% of participants
av_common_M = np.copy(av_M)
av_common_M[av_bin_M<0.05] = 0

# Save the matrices as text files
#----- AVERAGE -------------------
M_text_name = M_file_list_file.replace('_list', '_avMat.txt')
save_mat(av_M, M_text_name)
M_png_name = M_text_name.replace('.txt', '.png')
save_png(av_M, M_png_name)
#----- NORMALISE & AVERAGE -------
M_text_name = M_file_list_file.replace('_list', '_avNormMat.txt')
save_mat(av_norm_M, M_text_name)
M_png_name = M_text_name.replace('.txt', '.png')
save_png(av_norm_M, M_png_name)
#----- BINARIZE & AVERAGE -------
M_text_name = M_file_list_file.replace('_list', '_avBinMat.txt')
save_mat(av_bin_M, M_text_name)
M_png_name = M_text_name.replace('.txt', '.png')
save_png(av_bin_M, M_png_name)
#----- COMMON AVERAGE ONLY -----
M_text_name = M_file_list_file.replace('_list', '_avMat_gt05.txt')
save_mat(av_common_M, M_text_name)
M_png_name = M_text_name.replace('.txt', '.png')
save_png(av_common_M, M_png_name)

