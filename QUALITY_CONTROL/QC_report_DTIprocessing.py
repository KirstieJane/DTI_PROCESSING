#!/usr/bin/env python

# Import whatever you need
import numpy as np
import matplotlib.pylab as plt
import nibabel as nib
from glob import glob
import os
import pandas as pd
import matplotlib as mpl
import itertools as it
from mpl_toolkits.mplot3d import Axes3D


#dropbox_dir = glob(os.path.join('C:/','Users', '*', 'Dropbox'))
#external_scripts_dir = os.path.join(dropbox_dir[0], 'GitHub', 'DESCRIBING_DATA')

#sys.path.append(os.path.join(external_scripts_dir, 'PLOTTING_SCRIPTS'))

from boxplot_dti_movement import boxplot_dti_movement

### DEFINE SOME VARIABLES ###

# Define the data_directory
# (this could be passed as an argument when you generalize the code)
data_dir = os.path.join('/work', 'imagingG', 'NSPN', 'workspaces', 'kw401', 'UCHANGE', 'INTERIM_ANALYSIS')

# Define the sublist (again, this could be an argument)
sublist = np.loadtxt(os.path.join(data_dir, 'sublist'), dtype='string')

# Define the dti identifier. This is the additional path that exists inside the data directory
# and each individual subject's data folder that holds the dti.nii.gz files.
# It's passed as an argument to the dti_processing.sh file
dti_identifier = os.path.join('DTI', 'MRI0')

# Define the output directory and make it if it doesn't yet exist
qa_dir = os.path.join(data_dir, 'QA_OUTPUT')
if not os.path.isdir(qa_dir):
    os.makedirs(qa_dir)

### SET UP A DATA FRAME ###

# Create an empty dti_dir_list. This wil make it easier for you to loop through all the
# subjects - you'll loop through this list instead of the subjects and have to add the dti identifier
# in each time
dti_dir_list = []

# Fill up the dti_dir_list with all the subjects' DTI dirs
for sub in sublist:
    dti_dir_list.append(glob(os.path.join(data_dir, 'SUB_DATA', sub, 'DTI', 'MRI0'))[0])
    
# Generate an empty data frame for the subject data
# Define the columns
columns = ['subid', 'dirname']

# Loop through the measures and the groups of volumes that are considered
# and add these names to the columns list
measures = ['abs', 'rel']
measure_suffixes = [ '', '_b0', '_notb0' ]
for measure, suffix in it.product(measures, measure_suffixes):
    columns.append('mean_rms_'+measure+suffix)
    columns.append('std_rms_'+measure+suffix)
    columns.append('max_rms_'+measure+suffix)

# Now create the empty data frame    
subs_df = pd.DataFrame(index=range(len(dti_dir_list)),
                        columns=columns)

### FILL IN THE DATA ###

# Loop through the subjects
for i, (sub, dti_dir) in enumerate(zip(sublist, dti_dir_list)):
    # Write the subject id and the dirname into the first two columns of the subs_df
    subs_df.ix[i, 'dirname'] = dti_dir
    subs_df.ix[i, 'subid'] = sub
    
    # Loop through the measure suffixes ('', '_b0', '_notb0')
    # which you can think of as the groups of volumes that are being considered
    # and find the data from each of thoese files
    for suffix in measure_suffixes:
        
        # Read in the files and add the mean and standard deviations to your subs_df
        disp = pd.read_csv(os.path.join(dti_dir, 'ec_disp{}.txt'.format(suffix)),
                            delimiter=' ', header=None,
                            names=['abs'+suffix, 'rel'+suffix], na_values='.')
        
        # Loop through the three different values that you want to know
        # for the two different measures (abs and rel)
        for measure in measures:
            subs_df.ix[i, 'mean_rms_'+measure+suffix] = disp[measure+suffix].mean()
            subs_df.ix[i, 'std_rms_'+measure+suffix] = disp[measure+suffix].std()
            subs_df.ix[i, 'max_rms_'+measure+suffix] = disp[measure+suffix].max()

### Make the figure from ALL of the subjects
figure_name = os.path.join(qa_dir, 'movement_boxplot_all.png')
boxplot_dti_movement(subs_df, figure_name)

### Now drop all those outliers:
iter=1
while iter<5:
    print iter
    figure_name = os.path.join(qa_dir, 'movement_boxplot_iter{}.png'.format(iter))
    subs_df = boxplot_dti_movement(subs_df, figure_name)
    subs_df = subs_df[subs_df.color<1]
    iter+=1

    if subs_df.subid[subs_df.color>0].count() == 0:
        break
        
print subs_df.describe()
'''
# Now, we need to ignore the values that compare to a bval of 0
bvals_file=os.path.join(os.path.dirname(file), 'bvals')
bvals = np.loadtxt(bvals_file)
disp['bvals'] = bvals
bval_locs = np.where(disp.bvals==0)[0]
bval_locs = list(bval_locs)
exclude_locs = [ b +1 for b in bval_locs] + bval_locs
mask = ~disp.index.isin(exclude_locs)
subs_df.ix[i, 'mean_rms_abs_corr'] = disp[0][mask].mean()
subs_df.ix[i, 'mean_rms_rel_corr'] = disp[1][mask].mean()
'''


n = subs_df.subid.count()

cmap = mpl.cm.jet
norm = mpl.colors.Normalize(vmin=0, vmax=n)
map = mpl.cm.ScalarMappable( norm, 'jet')

fig = plt.figure()
ax = fig.add_subplot(111, projection='3d')

for i, dti_dir in enumerate(subs_df['dirname']):

    # Read in the three files that contain information on the displacements
    # again (but this time the subjects are in order of their mean_rms_abs_notb0)
    filenames = [ 'ec_disp.txt', 'ec_disp_b0.txt', 'ec_disp_notb0.txt' ]
    measure_suffixes = [ '', '_b0', '_notb0' ]
    for file, suffix in zip(filenames, measure_suffixes):
        disp = pd.read_csv(os.path.join(dti_dir, file),
                            delimiter=' ', header=None,
                            names=['abs'+suffix, 'rel'+suffix], na_values='.')

    # Now, we need to ignore the values that compare to a bval of 0
    bvals_file=os.path.join(os.path.join(dti_dir, 'bvals'))
    bvals = np.loadtxt(bvals_file)
    disp['bvals'] = bvals
    bval_locs = np.where(disp.bvals==0)[0]
    bval_locs = list(bval_locs)
    exclude_locs = [ b + 1 for b in bval_locs] + bval_locs
    mask = ~disp.index.isin(exclude_locs)
    colors = map.to_rgba(i)
    xs = range(disp['rel'+suffix][mask].count())
    ys = np.ones_like(xs)*i
    zs = disp['rel'+suffix][mask].values
    ax.plot(xs, ys, zs, c=colors)
    
ax.set_xlabel('Volume')
ax.set_ylabel('Participant')
ax.set_zlabel('Translation (mm)')

figure_name = os.path.join(data_dir, 'movement_beaches.png')
fig.savefig(figure_name, bbox_inches=0, dpi=100)
