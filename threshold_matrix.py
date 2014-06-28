#!/usr/bin/env python

# Create thresholded matrices

'''
Threshold matrices by a certain cost
'''

#=============================================================================
# IMPORTS
#=============================================================================
import numpy as np
import matplotlib.pylab as plt
import argparse

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
        
    # Required argument: cost
    parser.add_argument('cost',
                            type=float,
                            help='target cost')
                            
    arguments = parser.parse_args()
    
    return arguments, parser

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
    
#=============================================================================
# Define some variables
#=============================================================================
# Read in the arguments from argparse
arguments, parser = setup_argparser()

M_file = arguments.M_file
cost = arguments.cost

# Load in the matrix
M = np.loadtxt(M_file)

# Zero out the lower triangle and the diagonal
M_triu = np.triu(M, 1)

# Calculate the number of elements to keep
n = M.shape[0]
n_keep = cost * (n * (n-1)) * 0.5

# Threshold M_triu
thresh_M_triu = threshold_Mtriu(M_triu, n_keep)


