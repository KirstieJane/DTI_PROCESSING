#!/bin/bash
#
#=============================================================================
# Some code written by Kirstie Whitaker on 11th February 2015
# to create one parcellation of cortical and subcortical regions
# from the Harvard Oxford atlas
#
# Please contact kw401@cam.ac.uk with any questions
#=============================================================================
#
#=============================================================================
### SET THE FOLLOWING VARIABLES AS NEEDED
# Data directory - where you're going to save your files
data_dir=/home/kw401/MATILDE/

# Resolution - either 1 or 2 mm
resolution=1
#resolution=2

# Threshold - probability threshold
#thr0
thr=25
#thr50

#=============================================================================
# Copy over the files you need
cp ${FSLDIR}/data/atlases/HarvardOxford/HarvardOxford-cort-maxprob-thr${thr}-${resolution}mm.nii.gz ${data_dir}/cort.nii.gz
cp ${FSLDIR}/data/atlases/HarvardOxford/HarvardOxford-sub-maxprob-thr${thr}-${resolution}mm.nii.gz ${data_dir}/sub.nii.gz


# Threshold out the structures in the subcortical file that you don't want
fslmaths ${data_dir}/sub.nii.gz -thr 4 -uthr 7 -sub 3 -thr 0 ${data_dir}/temp_sub_L1.nii.gz
fslmaths ${data_dir}/sub.nii.gz -thr 9 -uthr 11 -sub 4 -thr 0 ${data_dir}/temp_sub_L2.nii.gz
fslmaths ${data_dir}/sub.nii.gz -thr 15 -uthr 21 -sub 7 -thr 0 ${data_dir}/temp_sub_R.nii.gz

fslmaths ${data_dir}/temp_sub_L1.nii.gz \
            -add ${data_dir}/temp_sub_L2.nii.gz \
            -add ${data_dir}/temp_sub_R.nii.gz \
            ${data_dir}/temp_sub.nii.gz
            
# Create a masks so you can split up the left and right hemispheres for the cortical map
# You need to know the mid point of the x axis
dims=(`fslinfo cort.nii.gz`)
x_dim=${dims[3]}
mid=(`echo "${x_dim}/2" | bc -l`)
echo ${mid}

fslmaths ${data_dir}/cort.nii.gz -mul 0 -add 1 -roi 0 ${mid} 0 -1 0 -1 0 -1 ${data_dir}/temp_right_mask.nii.gz
fslmaths ${data_dir}/temp_right_mask.nii.gz -mul -1 -add 1 ${data_dir}/temp_left_mask.nii.gz

# Now split and recombine the cortical hemispheres
fslmaths ${data_dir}/cort.nii.gz -mul ${data_dir}/temp_left_mask.nii.gz -add 14 -thr 15 ${data_dir}/temp_left_cort.nii.gz
fslmaths ${data_dir}/cort.nii.gz -mul ${data_dir}/temp_right_mask.nii.gz -add 62 -thr 63 ${data_dir}/temp_right_cort.nii.gz

# Combine all three files into one mask
fslmaths ${data_dir}/temp_sub.nii.gz \
            -add ${data_dir}/temp_left_cort.nii.gz \
            -add ${data_dir}/temp_right_cort.nii.gz \
            ${data_dir}/HO_parcellation.nii.gz
            
rm ${data_dir}/*temp*
rm ${data_dir}/cort.nii.gz
rm ${data_dir}/sub.nii.gz


