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
    # Required argument: M_file
    parser.add_argument('M_file',
                            type=str,
                            metavar='M_file',
                            help='Matrix (text file)')
        
    # Optional argument: minimum
    parser.add_argument('--hist_min',
                            dest='hist_min', 
                            type=float,
                            help='histogram minimum value',
                            default=0.0,
                            action='store')

    # Optional argument: maximum
    parser.add_argument('--hist_max',
                            dest='hist_max', 
                            type=float,
                            help='histogram maximum value',
                            default=300,
                            action='store')
                            
    # Optional argument: color
    parser.add_argument('--hist_color',
                            dest='hist_color',
                            type=str,
                            help='histogram color',
                            default='SteelBlue',
                            action='store')

    # Optional argument: no_cost_box
    parser.add_argument('--no_cost_box', 
                            dest='no_cost_box',
                            help='do not show cost in text box',
                            action='store_true',
                            default=False)
                            
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
cost = (np.count_nonzero(M_triu) * 2) / np.float(n * (n-1))

# Create a histogram of all (non-zero) connections
M_fig_name = M_file.replace('.txt', '_weights.png')

fig, ax = plt.subplots(figsize=(4,4))    
n, bins, patches = ax.hist(M_triu[M_triu>0], 
                            log=True, 
                            range=(hist_min,hist_max), 
                            color=hist_color)

ax.set_xlim([hist_min, hist_max])
ax.set_ylim([1, 10000])
ax.set_xlabel('Connection weight')
ax.set_ylabel('Frequency (log scale)')

# Add in the cost in the top right corner                   
if not arguments.no_cost_box:
    ax.text(0.95, 0.95, 
            'cost = {:.2f}%'.format(cost*100), 
            transform=ax.transAxes,
            horizontalalignment='right',
            verticalalignment='top')
        
plt.tight_layout()

fig.savefig(M_fig_name, bbox_inches=0, dpi=600)

