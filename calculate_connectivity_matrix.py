#!/usr/bin/env python

"""
Name: calculate_connectivity_matrix.py

Created by: Kirstie Whitaker
            kw401@cam.ac.uk


"""

#=============================================================================
# IMPORTS 
#=============================================================================
import os
import sys
from glob import glob
import argparse
import numpy as np
import matplotlib.pylab as plt
import nibabel as nib

import dipy.reconst.dti as dti
from dipy.reconst.dti import quantize_evecs
from dipy.data import get_sphere
from dipy.io import read_bvals_bvecs
from dipy.core.gradients import gradient_table
from dipy.tracking.eudx import EuDX
from dipy.reconst import peaks, shm
from dipy.tracking import utils

try:
      from dipy.viz import fvtk
except ImportError:
      raise ImportError('Python vtk module is not installed')

from dipy.viz.colormap import line_colors

import networkx as nx

import matplotlib.colors as colors

from condition_seeds import condition_seeds

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
    help_text = ('Create a connectivity matrix from a diffusion weighted dataset')
    
    sign_off = 'Author: Kirstie Whitaker <kw401@cam.ac.uk>'
    
    parser = argparse.ArgumentParser(description=help_text, epilog=sign_off)
    
    # Now add the arguments
    # Required argument: dti_dir
    parser.add_argument(dest='dti_dir', 
                            type=str,
                            metavar='dti_dir',
                            help='DTI directory')
    
    # Required argument: parcellation_file
    parser.add_argument(dest='parcellation_file', 
                            type=str,
                            metavar='parcellation_file',
                            help='Parcellation filename')
    
    # Required argument: white_matter_file
    parser.add_argument(dest='white_matter_file', 
                            type=str,
                            metavar='white_matter_file',
                            help='White matter filename')
                            
    arguments = parser.parse_args()
    
    return arguments, parser

#=============================================================================
# Define some variables
#=============================================================================
# Read in the arguments from argparse
arguments, parser = setup_argparser()

dti_dir = arguments.dti_dir
parcellation_file = arguments.parcellation_file
wm_file = arguments.white_matter_file

if not os.path.exists(parcellation_file):
    parcellation_file = os.path.join(dti_dir, parcellation_file)

# Check that the inputs exist:
if not os.path.isdir(dti_dir):
    print "DTI directory doesn't exist"
    sys.exit()

if not os.path.exists(parcellation_file):
    print "Parcellation file doesn't exist"
    sys.exit()
 
if not os.path.exists(wm_file):
    print "White matter file doesn't exist"
    sys.exit()

# Define the output directory and make it if it doesn't yet exist
connectivity_dir = os.path.join(dti_dir, 'CONNECTIVITY')
if not os.path.isdir(connectivity_dir):
    os.makedirs(connectivity_dir)

# Now define a couple of variables
dwi_file = os.path.join(dti_dir, 'dti_ec.nii.gz')
mask_file = os.path.join(dti_dir, 'dti_ec_brain.nii.gz')
bvals_file = os.path.join(dti_dir, 'bvals')
bvecs_file = os.path.join(dti_dir, 'bvecs') 
Msym_file = os.path.join(connectivity_dir, 'Msym.txt')
Mdir_file = os.path.join(connectivity_dir, 'Mdir.txt')

#=============================================================================
# Load in the data
#=============================================================================
print 'PARCELLATION FILE: {}'.format(parcellation_file)

dwi_img = nib.load(dwi_file)
dwi_data = dwi_img.get_data()

mask_img = nib.load(mask_file)
mask_data = mask_img.get_data().astype(np.int)
mask_data_bin = np.copy(mask_data)
mask_data_bin[mask_data_bin > 0] = 1

wm_img = nib.load(wm_file)
wm_data = wm_img.get_data()
wm_data_bin = np.copy(wm_data)
wm_data_bin[wm_data_bin > 0] = 1

# Mask the dwi_data so that you're only investigating voxels inside the brain!
dwi_data = dwi_data * wm_data_bin.reshape([wm_data_bin.shape[0], 
                                             wm_data_bin.shape[1], 
                                             wm_data_bin.shape[2],
                                             1])

parcellation_img = nib.load(parcellation_file)
parcellation_data = parcellation_img.get_data().astype(np.int)

wm_img = nib.load(wm_file)
wm_data = wm_img.get_data()

bvals, bvecs = read_bvals_bvecs(bvals_file, bvecs_file)
gtab = gradient_table(bvals, bvecs)

mask_data_bin[mask_data_bin > 0] = 1
wm_data_bin = np.copy(wm_data)
wm_data_bin[wm_data_bin > 0] = 1
parcellation_data = parcellation_data * mask_data_bin
parcellation_wm_data = parcellation_data * wm_data_bin
parcellation_wm_data = parcellation_wm_data.astype(np.int)


#=============================================================================
# Track all of white matter using EuDX
#=============================================================================

if not os.path.exists(Msym_file) and not os.path.exists(Mdir_file):

    print '\tCalculating peaks'
    csamodel = shm.CsaOdfModel(gtab, 6)
    csapeaks = peaks.peaks_from_model(model=csamodel,
                                      data=dwi_data,
                                      sphere=peaks.default_sphere,
                                      relative_peak_threshold=.8,
                                      min_separation_angle=45,
                                      mask=wm_data_bin)
                                      
    print '\tTracking'
    seeds = utils.seeds_from_mask(parcellation_wm_data, density=2)
    condition_seeds = condition_seeds(seeds, np.eye(4), csapeaks.peak_values.shape[:3])
    streamline_generator = EuDX(csapeaks.peak_values, csapeaks.peak_indices,
                                odf_vertices=peaks.default_sphere.vertices,
                                a_low=.05, step_sz=.5, seeds=condition_seeds)
    affine = streamline_generator.affine
    streamlines = list(streamline_generator)
    
else:
    print '\tTracking already complete'

#=============================================================================
# Create two connectivity matrices - symmetric and directional
#=============================================================================
if not os.path.exists(Msym_file) and not os.path.exists(Mdir_file):
 
<<<<<<< HEAD
<<<<<<< HEAD
    print '\tCreating Connectivity Matrix'
=======
    print '\tCreatingConnectivityMatrix'
>>>>>>> c8759e622742fb8bef2b3061dfa46d51702d20e4
=======
    print '\tCreatingConnectivityMatrix'
>>>>>>> c8759e622742fb8bef2b3061dfa46d51702d20e4
    Msym, grouping = utils.connectivity_matrix(streamlines, parcellation_wm_data,
                                                    affine=affine,
                                                    return_mapping=True,
                                                    symmetric=True,
                                                    mapping_as_streamlines=True)
                                            
    Mdir, grouping = utils.connectivity_matrix(streamlines, parcellation_wm_data,
                                                    affine=affine,
                                                    return_mapping=True,
                                                    symmetric=False,
                                                    mapping_as_streamlines=True)
 
else:
    Msym = np.loadtxt(Msym_file)
    Mdir = np.loadtxt(Mdir_file)
    
# Calculate the difference the two directions

Mdiff = Mdir - Mdir.T
Mdiff[Mdiff<0] = 0

#=============================================================================
# Save the connectivity matrices as text files, and as figures
#=============================================================================
print '\tMaking Pictures'

for M, name in zip([Msym, Mdir, Mdiff], ['Msym', 'Mdir', 'Mdiff']):
    
    # Save the matrix as a text file
    M_text_name = os.path.join(connectivity_dir, '{}.txt'.format(name))
    if not os.path.exists(M_text_name):
    
        np.savetxt(M_text_name,
                       M[1:,1:],
                       fmt='%.5f',
                       delimiter='\t',
                       newline='\n')

    # Make a png image of the matrix
    M_fig_name = os.path.join(connectivity_dir, '{}.png'.format(name))
    if not os.path.exists(M_fig_name):

        fig, ax = plt.subplots(figsize=(4,4))    
        
        # Plot the matrix on a log scale
        axM = ax.imshow(np.log1p(M[1:,1:]), 
                        interpolation='nearest',
                        cmap='jet')
        
        # Add a colorbar
        cbar = fig.colorbar(axM)

        fig.savefig(M_fig_name, bbox_inches=0, dpi=600)

# Save an image of all three matrices        
fig_name = os.path.join(connectivity_dir, 'AllMatrices.png')
if not os.path.exists(fig_name):
    # Now make the plot of all three figures
    fig, ax = plt.subplots(1,3, figsize=(12, 4))

    M0 = ax[0].imshow(np.log1p(Msym[1:,1:]), interpolation='nearest', cmap='jet', 
                    vmin=0, vmax=np.log1p(1000))
    M1 = ax[1].imshow(np.log1p(Mdir[1:,1:]), interpolation='nearest', cmap='jet',
                    vmin=0, vmax=np.log1p(1000))
    M2 = ax[2].imshow(np.log1p(Mdiff[1:,1:]), interpolation='nearest', cmap='jet',
                    vmin=0, vmax=np.log1p(1000))

    ax[0].set_title('Symmetric')
    ax[1].set_title('Directed')
    ax[2].set_title('Difference\nA --> B and B --> A')

    plt.tight_layout()

    fig.savefig(fig_name, bbox_inches=0, dpi=600)

#------------------------------------------------
### THE END ###
# Today is April 3rd and the sun in shining in Cambridge
#------------------------------------------------
