#!/usr/bin/env python

'''
This code provides an individual quality assurance report
for dti processing. It expects a data directory in which 
DTI data has been preprocessed

'''
#### Import the modules you're going to use
import os
import numpy as np
import matplotlib.pylab as plt
import nibabel as nib
from glob import glob
import pandas as pd
import matplotlib.gridspec as gridspec
import matplotlib.patches as patches
import argparse


#### Now define the functions you're going to use
#==============================================================================
def setup_argparser():
    '''
    # CODE TO READ ARGUMENTS FROM THE COMMAND LINE AND SET OPTIONS
    # ALSO INCLUDES SOME HELP TEXT
    '''
    
    # Build a basic parser.
    help_text = ('Create a quality control report for a bunch of DTI directories')
    
    sign_off = 'Author: Kirstie Whitaker <kw401@cam.ac.uk>'
    
    parser = argparse.ArgumentParser(description=help_text, epilog=sign_off)
    
    # Now add the arguments
    # Required argument: data_dir
    parser.add_argument(dest='data_dir', 
                            type=str,
                            metavar='data_dir',
                            help='Data directory')
        
    arguments = parser.parse_args()
    
    return arguments, parser


def plot_dti_slices(background_file, overlay_file, fig, grid, ax_name_list, cmap='jet'):
        
    # LOAD THE DATA
    bg_img = nib.load(background_file)
    bg = bg_img.get_data()
    
    overlay_img = nib.load(overlay_file)
    overlay = overlay_img.get_data()

    # Make sure all data is float:
    bg = bg/1.
    overlay = overlay/1.
    
    # Scale the data by its maximum
    bg = bg / bg.max()
    overlay = overlay / overlay.max()    
        
    # Now we're going to loop through the different slice orientations

    for i, axis_name in enumerate(ax_name_list):
        if axis_name == 'axial':
            # Align so that right is right
            overlay_plot = np.rot90(overlay)
            overlay_plot = np.fliplr(overlay_plot)
            bg_plot = np.rot90(bg)
            bg_plot = np.fliplr(bg_plot)
    
        elif axis_name == 'coronal':
            overlay_plot = np.rot90(overlay)
            bg_plot = np.rot90(bg)
            overlay_plot = np.flipud(np.swapaxes(overlay_plot, 0, 2))
            bg_plot = np.flipud(np.swapaxes(bg_plot, 0, 2))

        elif axis_name == 'sagittal':
            overlay_plot = np.flipud(np.swapaxes(overlay, 0, 2))
            bg_plot = np.flipud(np.swapaxes(bg, 0, 2))

        n = ( np.float(bg_plot.shape[1])/bg_plot.shape[2] ) * (np.float(figsize[0])/ (0.15 * figsize[1]))

        n_floor = np.int(np.floor(n))
        
        inner_grid = gridspec.GridSpecFromSubplotSpec(1, n_floor,
                         subplot_spec=grid[i], wspace=0.0, hspace=0.0)
        
        for j, slice_id in enumerate(np.linspace(0 , bg_plot.shape[2], n_floor+2)[1:-1]):
        
            bg_slice = bg_plot[:,:,slice_id]
            overlay_slice = overlay_plot[:,:,slice_id]
            
            ax = plt.Subplot(fig, inner_grid[j])
            fig.add_subplot(ax)

            # Add a black background
            black = ax.imshow(np.ones_like(bg_slice),
                                    interpolation='none',
                                    cmap='gray')
            
            # Mask the data
            m_overlay_slice = np.ma.masked_where(overlay_slice==0, overlay_slice)

            # First show the background slice
            im1 = ax.imshow(bg_slice,
                                interpolation='none',
                                cmap='gray',
                                vmin = 0,
                                vmax = 1)
    
            # Then overlay the overlay_slice
            im2 = ax.imshow(m_overlay_slice,
                                interpolation='none',
                                cmap=cmap,
                                vmin = 0,
                                vmax = 1,
                                alpha = 0.3)
               
            # Turn off axis labels
            ax.get_xaxis().set_visible(False)
            ax.get_yaxis().set_visible(False)
            ax.set_frame_on(False)
            
    return fig

#=============================================================================
def plot_movement_params(dti_dir, fig, grid):
    measures = ['abs', 'rel']
    measure_suffixes = [ '', '_b0', '_notb0' ]
    
    # Loop through the measure suffixes ('', '_b0', '_notb0')
    # which you can think of as the groups of volumes that are being considered
    # and find the data from each of thoese files
    for i, suffix in enumerate(measure_suffixes):
        
        ax = plt.Subplot(fig, grid[i])
        fig.add_subplot(ax)

        # Read in the files
        disp = pd.read_csv(os.path.join(dti_dir, 'ec_disp{}.txt'.format(suffix)),
                            delimiter=' ', header=None,
                            names=['abs'+suffix, 'rel'+suffix], na_values='.')

        # Loop through the three different values that you want to know
        # for the two different measures (abs and rel)
        for measure in measures:

            ax.plot(disp[measure+suffix][disp[measure+suffix].notnull()], label=measure)
                
        # Label the x axis according to which plot this is:
        if suffix == '':
            ax.set_xlabel('Volume Number')
        elif suffix == '_b0':
            ax.set_xlabel('B0 Volume Number')
        else:
            ax.set_xlabel('Diff weighted Volume Number')
        
        # Set the y axis to always between 0 and 3
        ax.set_ylim(0,3)
        
        # Only label the first y axis
        if i == 0:
            # And label the yaxis
            ax.set_ylabel('Displacement (mm)')
            
        # Add a legend
        leg = ax.legend(loc=2, fontsize=8)
        leg.get_frame().set_alpha(0.5)
        
    return fig


#=============================================================================
def tensor_histogram(fa_file, mo_file, sse_file, wm_mask_file, fig, grid):
    
    # Load in the data
    fa_img = nib.load(fa_file)
    fa = fa_img.get_data()
    mo_img = nib.load(mo_file)
    mo = mo_img.get_data()
    sse_img = nib.load(sse_file)
    sse = sse_img.get_data()
    
    wm_mask_img = nib.load(wm_mask_file)
    wm_mask = wm_mask_img.get_data()
    
    # Mask the fa data with the white matter mask
    # so we're only looking inside the mask
    fa = fa * wm_mask
    
    # Add a subplot to the first space in the grid
    # and enter a histogram of FA values
    ax = plt.Subplot(fig, grid[0])
    fig.add_subplot(ax)    
    ax.hist(fa[fa>0].reshape(-1), bins=np.linspace(0,1,100), color='green',histtype='stepfilled')
    # Label the x axis:
    ax.set_xlabel('Fractional Anisotropy')
    # Set the y axis to always between 0 and 2500
    ax.set_ylim(0,2500)
    # Adjust the power limits so that you use scientific notation on the y axis
    ax.ticklabel_format(style='sci', axis='y')
    ax.yaxis.major.formatter.set_powerlimits((-3,3))

    # Only label this first y axis as they're all the same
    ax.set_ylabel('Number of voxels')
    
    # Add a subplot to the second space in the grid
    # and plot a histogram of mode values
    ax = plt.Subplot(fig, grid[1])
    fig.add_subplot(ax)    
    ax.hist(mo[fa>0].reshape(-1), bins=np.linspace(-1,1,100), color='orange', histtype='stepfilled')
    # Label the x axes:
    ax.set_xlabel('Mode of Anisotropy')
    # Set the y axis to always between 0 and 3500
    ax.set_ylim(0,3500)
    # Adjust the power limits so that you use scientific notation on the y axis
    #plt.ticklabel_format(style='sci', axis='y')
    ax.yaxis.major.formatter.set_powerlimits((-3,3))

    
    # Add a subplot to the third space in the grid
    # and plot a histogram of sum of square errors
    # Note that low values are very good - they indicate voxels
    # that have a good fit to the diffusion tensor model.
    # The y-axis is therefore limited so that the histogram highlights
    # "bad" fit voxels.

    ax = plt.Subplot(fig, grid[2])
    fig.add_subplot(ax)    
    ax.hist(sse[fa>0].reshape(-1), bins=np.linspace(0,5,100), color='red', histtype='stepfilled')
    # Label the x axis:
    ax.set_xlabel('Sum of Square Errors')
    # Set the y axis to always between 0 and 3500
    ax.set_ylim(0,100)
    
    return fig


#=============================================================================
def add_background(fig, grid):
    ax = plt.Subplot(fig, grid[0])
    fig.add_subplot(ax)

    # Add a black background
    black = ax.imshow(np.ones([100,100]),
                            interpolation='none',
                            cmap='gray',
                            aspect='auto')
    # Turn off axis labels
    ax.get_xaxis().set_visible(False)
    ax.get_yaxis().set_visible(False)
    ax.set_frame_on(False)

    return fig


#=============================================================================
def add_header(fig, grid):
    ax = plt.Subplot(fig, grid[0])
    fig.add_subplot(ax)

    # The header simply says:
    header_text = "Diffusion Tensor Imaging Quality Report\n\nSubID:____________  Date:____________"
    
    ax.text(0.05, 0.5, header_text, transform=ax.transAxes, fontsize=14,
                   horizontalalignment='left', verticalalignment='center')
    
    # On the right we'll add two options:
    quality_text = "Pass"

    ax.text(0.82, 0.55, quality_text, transform=ax.transAxes, fontsize=18,
                   horizontalalignment='right', verticalalignment='bottom')

    ax.add_patch(patches.Rectangle((0.84,0.55),0.1,0.35, color='black', fill=False))

    quality_text = "Fail"

    ax.text(0.82, 0.15, quality_text, transform=ax.transAxes, fontsize=18,
                   horizontalalignment='right', verticalalignment='bottom')
    
    ax.add_patch(patches.Rectangle((0.84,0.15),0.1,0.35, color='black', fill=False))
    
    # Turn off axis labels
    ax.get_xaxis().set_visible(False)
    ax.get_yaxis().set_visible(False)
    ax.set_frame_on(False)

    return fig


#=============================================================================
#=============================================================================
# Define the files you're going to need

# Read in the arguments from argparse
arguments, parser = setup_argparser()

data_dir = arguments.data_dir

# Define the output directory and make it if it doesn't yet exist
qa_dir = os.path.join(data_dir, 'QA_OUTPUT')
if not os.path.isdir(qa_dir):
    os.makedirs(qa_dir)

dti_file = os.path.join(data_dir, 'dti_ec.nii.gz')
bvals_file = os.path.join(data_dir, 'bvals')
bvecs_file = os.path.join(data_dir, 'bvecs')
dti_vol0_file = os.path.join(data_dir, 'dti_ec_00.nii.gz')
mask_file = os.path.join(data_dir, 'dti_ec_brain_mask.nii.gz')
wm_mask_file = os.path.join(data_dir, 'whitematter_mask.nii.gz')
fa_file = glob(os.path.join(data_dir, '*_FA.nii.gz'))[0]
mo_file = glob(os.path.join(data_dir, '*_MO.nii.gz'))[0]
sse_file = glob(os.path.join(data_dir, '*_sse.nii.gz'))[0]

#### Now actually run the code

# Create a figure that's the same size as an A4 piece of paper

figsize = (8.3,11.6)
fig = plt.figure(figsize = figsize)


# Now set up the plotting areas using GridSpec 
# Header grid - to contain the header at the top of the page
header_grid = gridspec.GridSpec(1,1)
header_grid.update(left=0.05, right=0.95, top = 0.98, bottom = 0.9)

# Background A - to go behind brain_grid A
bgA_grid = gridspec.GridSpec(1, 1)
bgA_grid.update(left=0.05, right=0.95, top = 0.9, bottom = 0.65)

# Brain grid A - non-diffusion weighted image and brain mask
brainA_grid = gridspec.GridSpec(3, 1)
brainA_grid.update(left=0.05, right=0.95, top = 0.9, bottom = 0.65)

# Movement grid - movement and eddy_correct realignment parameters 
movement_grid = gridspec.GridSpec(1, 3)
movement_grid.update(left=0.1, right=0.95, top = 0.63, bottom = 0.5, wspace=0.2)

# Background B - to go behind brain_grid B
bgB_grid = gridspec.GridSpec(1, 1)
bgB_grid.update(left=0.05, right=0.95, top = 0.45, bottom = 0.2)

# Brain grid B - FA image and white matter mask
brainB_grid = gridspec.GridSpec(3, 1)
brainB_grid.update(left=0.05, right=0.95, top = 0.45, bottom = 0.2)

# Histogram grid - histograms of FA, MO, and sum of square errors
hist_grid = gridspec.GridSpec(1, 3)
hist_grid.update(left=0.1, right=0.95, top = 0.18, bottom = 0.05, wspace=0.2)


# Fill in these plotting areas using the functions defined above

fig = add_header(fig, header_grid)
fig = add_background(fig, bgA_grid)
fig = plot_dti_slices(dti_vol0_file, mask_file, fig, brainA_grid, ['sagittal', 'coronal', 'axial'], cmap='cool_r')
fig = plot_movement_params(data_dir, fig, movement_grid)
fig = add_background(fig, bgB_grid)
fig = plot_dti_slices(fa_file, wm_mask_file, fig, brainB_grid, ['sagittal', 'coronal', 'axial'], cmap='cool')
fig = tensor_histogram(fa_file, mo_file, sse_file, wm_mask_file, fig, hist_grid)


# Finally, save the figure

report_filename = os.path.join(qa_dir, 'QAReport.jpg')
fig.savefig(report_filename, bbox_inches=0, dpi=300)


# **That's it! You're done :)**
