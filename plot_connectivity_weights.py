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

