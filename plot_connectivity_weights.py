#!/usr/bin/env python

# plot_connectivity_weights(M_file)

'''
Connectivity plots for a matrix
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
    # Required argument: dti_dir
    parser.add_argument(dest='M_file', 
                            type=str,
                            metavar='M_file',
                            help='Matrix (text file)')
        
    # Optional argument: minimum
    parser.add_argument(dest='hist_min', 
                            type=float,
                            metavar='hist_min',
                            required=False,
                            help='histogram minimum value',
                            default=0.0)

    # Optional argument: maximum
    parser.add_argument(dest='hist_max', 
                            type=float,
                            metavar='hist_max',
                            required=False,
                            help='histogram maximum value',
                            default=300)
                            
    # Optional argument: color
    parser.add_argument(dest='hist_color', 
                            type=str,
                            metavar='histogram color',
                            required=False,
                            help='histogram color',
                            default='SteelBlue')

    # Optional argument: no_cost_box
    parser.add_argument(dest='--no_cost_box', 
                            help='do not show cost in text box',
                            required=False,
                            action='store_false')
                            
    arguments = parser.parse_args()
    
    return arguments, parser

#=============================================================================
# Define some variables
#=============================================================================
# Read in the arguments from argparse
arguments, parser = setup_argparser()

M_file = arguments.M_file
hist_min = arguments.hist_min
hist_max = arguments.hist_max
hist_color = arguments.hist_color

# Load in the matrix
M = np.loadtxt(M_file)

# Zero out the lower triangle and the diagonal
M_triu = np.triu(M, 1)

# Calculate the density (cost)
n = M.shape[0]
cost = np.count_nonzero(M) / np.float(n * n-1)

# Create a histogram of all (non-zero) connections
M_fig_name = M_file.replace('.txt', '_weights.png')

fig, ax = plt.subplots(figsize=(4,4))    
n, bins, patches = ax.hist(M_triu[M_triu>0], 
                            log=True, 
                            range=(0,300), 
                            color=hist_color)

if not arguments.no_cost_box:
    ax.text(0.95, 0.95, 'cost = {:.2f}%'.format(cost*100), transform=ax.transAxes, fontsize=14,
        verticalalignment='top', bbox=props)
        
fig.savefig(M_fig_name, bbox_inches=0, dpi=600)

