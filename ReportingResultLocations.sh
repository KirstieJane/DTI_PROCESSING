#!/bin/bash

# This script loops through an atlas and creates a report
# of the number of significant voxels per label, along
# with the percentage of skeleton voxels that are significant
# per label too.

# USAGE: ReportingResultsLocations.sh <result_file> <mean_skeleton_file> <atlas_file> <labels_xml_file>

# Read in the arguments
result=$1
mean_skeleton=$2
atlas=$3
labels_file=$4

# Check that you have the right arguments etc
for input in $1 $2 $3 $4; do
    
    # Check to see if the file exists
    if [[ ! -f ${input} ]]; then
        echo ${input} is not a file
        exit
    fi
    
done

# Figure out the atlas name
atlas_name=`basename ${atlas} .nii.gz`

result_locations="`basename ${result} .nii.gz`_`basename ${labels_file} .xml`.csv"
# If the locations file already exists then don't run this script
if [[ -f ${result_locations} ]]; then
    echo "    ${atlas_name} locations already reported"
    exit
fi

# But if it doesn't then create it and write in the header
echo "Atlas_label, N_voxels_result, N_voxels_skeleton" > ${result_locations}

#==============================================================================
# Lets start by thresholding the result for significant voxels only
# and multiplying it by the atlas
result_thr_bin=${result%.nii.gz}_thr95_bin.nii.gz
result_thr_atlas=${result%.nii.gz}_thr95_${atlas_name}.nii.gz
# You need to create an unclassified file as well
result_thr_atlas_unclass=${result%.nii.gz}_thr95_${atlas_name}_unclassified.nii.gz

fslmaths ${result} -thr 0.95 -bin ${result_thr_bin}
fslmaths ${result_thr_bin} -mul ${atlas} ${result_thr_atlas}
fslmaths ${result_thr_atlas} -bin -sub ${result_thr_bin} -mul -1 ${result_thr_atlas_unclass}

#==============================================================================
# You also need to know how many voxels from the mean skeleton fall in the atlas regions
mean_skeleton_atlas=${mean_skeleton%.nii.gz}_${atlas_name}.nii.gz
mean_skeleton_atlas_unclass=${mean_skeleton%.nii.gz}_${atlas_name}_unclassified.nii.gz

fslmaths ${mean_skeleton} -mul ${atlas} ${mean_skeleton_atlas}
fslmaths ${mean_skeleton_atlas} -bin -sub ${mean_skeleton} -mul -1 ${mean_skeleton_atlas_unclass}

#==============================================================================
# Figure out a couple of important pieces of information about the atlas
atlas_range=(`fslstats ${atlas} -R`)
atlas_max=${atlas_range[1]%.*}

#==============================================================================
# Now start your loop of all the atlas regions

i=1
while [[ ${i} -lt ${atlas_max} ]]; do

    l_thr=`echo ${i} - 1 | bc`
    u_thr=`echo ${i} + 1 | bc`
    vol=(`fslstats ${result_thr_atlas} -l ${l_thr} -u ${u_thr} -V`)
    
    if [[ ${vol} -ne 0 ]]; then
        label=`grep "label index=\"${i}\"" ${labels_file}`
        label=${label#*>}
        label=${label%<*}
    
        vol_skel=(`fslstats ${mean_skeleton_atlas} -l ${l_thr} -u ${u_thr} -V`)
        
        percent=(`echo "${vol}/${vol_skel} * 100" | bc -l`)
        echo "${label}, ${vol}, ${vol_skel}, ${percent}" >> ${result_locations}
    fi
    let i=${i}+1
done

# Finally add in the unclassified answer
vol=(`fslstats ${results_thr_atlas_unclass} -V`)
vol_skel=(`fslstats ${mean_skeleton_atlas_unclass} -V`)
percent=(`echo "${vol}/${vol_skel} * 100" | bc -l`)
echo "Unclassified, ${vol}, ${vol_skel}, ${percent}" >> ${result_locations}

#==============================================================================
# All done, well done ;)
#==============================================================================
