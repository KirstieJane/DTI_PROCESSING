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

# Define the data_directory
# (this could be passed as an argument when you generalize the code)
data_dir = os.path.join('/work', 'imagingG', 'NSPN', 'workspaces', 'kw401', 'UCHANGE', 'INTERIM_ANALYSIS')
sublist = np.loadtxt(os.path.join(data_dir, 'sublist'), dtype='string')
dti_identifier = os.path.join('DTI', 'MRI0')

dti_dir_list = []

# Find the disp files
for sub in sublist:
    dti_dir_list.append(glob(os.path.join(data_dir, 'SUB_DATA', sub, 'DTI', 'MRI0'))[0])
    
# Generate an empty data frame for the subject data
# Define the columns
columns = ['subid', 'dirname']
measures = ['abs', 'rel']
measure_suffixes = [ '', '_b0', '_notb0' ]
for measure, suffix in it.product(measures, measure_suffixes):
    columns.append('mean_rms_'+measure+suffix)
    columns.append('std_rms_'+measure+suffix)
    columns.append('max_rms_'+measure+suffix)

# Now create the empty data frame    
subs_df = pd.DataFrame(index=range(len(dti_dir_list)),
                        columns=columns)

# Loop through the subjects
for i, (sub, dti_dir) in enumerate(zip(sublist, dti_dir_list)):
    subs_df.ix[i, 'dirname'] = dti_dir
    subs_df.ix[i, 'subid'] = sub
    
    # Read in the three files that contain information on the displacements
    # and add the mean and standard deviations to your subs_df
    filenames = [ 'ec_disp.txt', 'ec_disp_b0.txt', 'ec_disp_notb0.txt' ]
    
    for file, suffix in zip(filenames, measure_suffixes):
        disp = pd.read_csv(os.path.join(dti_dir, file),
                            delimiter=' ', header=None,
                            names=['abs'+suffix, 'rel'+suffix], na_values='.')
        
        # Loop through th
        for measure in measures:
            subs_df.ix[i, 'mean_rms_'+measure+suffix] = disp['abs'+suffix].mean()
            subs_df.ix[i, 'std_rms_'+measure+suffix] = disp['abs'+suffix].std()
            subs_df.ix[i, 'max_rms_'+measure+suffix] = disp['abs'+suffix].max()

# Sort the subs dataframe according to the mean rms relative displacement
# for the diffusion-weighted volumes
subs_df.sort(columns='mean_rms_rel_notb0', inplace=True)

cols = [ name for name in subs_df.columns if 'mean_rms' in name ]

fig, ax = plt.subplots()
box = plt.boxplot(subs_df[subs_df[cols[0]]<2.5][cols].values)
for f in box['fliers']:
    i, fliers = f.get_data()
    for c, (x, y) in enumerate(zip(i, fliers)):
        id = subs_df.subid[subs_df[cols[np.int(x-1)]]==y].values
        offset = -40 * np.float(c%2) + 20
        ax.annotate(id[0], xy=(x, y), xytext=(offset,offset),
            textcoords='offset points', ha='center', va='center',
            bbox=dict(boxstyle='round,pad=0.2', fc='green', alpha=0.3),
            arrowprops=dict(arrowstyle='->', #connectionstyle='arc3,rad=0.5', 
                            color='green'))
plt.xticks(range(1,len(cols)+1), cols, rotation=45)
plt.tight_layout()
plt.show()

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
    xs = range(disp['rel'][mask].count())
    ys = np.ones_like(xs)*i
    zs = disp['rel'][mask].values
    ax.plot(xs, ys, zs, c=colors)
    
ax.set_xlabel('Volume')
ax.set_ylabel('Participant')
ax.set_zlabel('Translation (mm)')

plt.show()
