#!/usr/bin/env python

# Create thresholded matrices

'''
Threshold matrices by a certain cost
It's important to give it an integer number of
elements to keep though as the rounding causes
difficulty calculating the correct value
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
    help_text = ('Create a histogram of weights from a connectivity matrix')
    
    sign_off = 'Author: Kirstie Whitaker <kw401@cam.ac.uk>'
    
    parser = argparse.ArgumentParser(description=help_text, epilog=sign_off)
    
    # Now add the arguments
    # Required argument: M_file
    parser.add_argument('M_file',
                            type=str,
                            metavar='M_file',
                            help='Matrix (text file)')
        
    # Required argument: n_keep
    parser.add_argument('n_keep',
                            type=int,
                            help='number of highest weights to keep **IN THE TOP TRIANGLE**')
                            
    arguments = parser.parse_args()
    
    return arguments, parser

#-----------------------------------------------------------------------------
    
def threshold_Mtriu(M_triu, n_keep):

    print 'n_keep {}'.format(n_keep)
    
    # Reshape M_triu into one long vector
    M_triu_unzip = M_triu.reshape(-1)
    
    # Sort the values in M_triu and find the nth value
    M_triu_unzip_sorted = np.sort(M_triu_unzip)
    keep_values = M_triu_unzip_sorted[-n_keep:]
    thresh = M_triu_unzip_sorted[-n_keep]

    print 'keep_values len: {}'.format(keep_values.shape[0])
    print 'thresh {}'.format(thresh)
    
    # Count how many of those values need to remain in M_triu
    n_thresh_keep = keep_values[keep_values == thresh].shape[0]
    print 'n_thresh_keep {}'.format(n_thresh_keep)
    
    # Find all the indices in M_triu that have that value
    idx  = np.argwhere(M_triu_unzip == thresh)
    np.random.shuffle(idx)
    
    print 'len idx: {}'.format(len(idx))
    
    # Now set all but the first n_thresh_keep of these to zero
    M_triu_unzip[idx[n_thresh_keep:]] = 0
    
    thresh_M_triu = M_triu_unzip.reshape(M_triu.shape)

    return thresh_M_triu

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

M_file = arguments.M_file
n_keep = arguments.n_keep

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



