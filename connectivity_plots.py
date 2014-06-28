#!/usr/bin/env python

# connectivity_plots(Msym_file)

'''
Connectivity plots for a matrix
'''

### IMPORTS
import numpy as np
import matplotlib.pylab as plt

# Load in the matrix
Msym = np.loadtxt(Msym_file)

# Zero out the lower triangle and the diagonal
Msym_triu = np.triu(Msym, 1)

# Create a histogram of all (non-zero) connections
M_fig_name = Msym_file.replace('Msym.txt', 'Msym_Ntracts.png')

fig, ax = plt.subplots(figsize=(4,4))    
n, bins, patches = ax.hist(Msym_triu[Msym_triu>0], 
                            log=True, 
                            range=(0,300), 
                            color='#3670f1')

fig.savefig(M_fig_name, bbox_inches=0, dpi=600)

