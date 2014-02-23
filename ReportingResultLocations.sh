#!/bin/bash

# This script loops through an atlas and creates a report
# of the number of significant voxels per label, along
# with the percentage of skeleton voxels that are significant
# per label too.
# It also reports the peak t-statistic and its location within
# each labelled region in mm.

# USAGE: ReportingResultsLocations.sh <result_file> <mean_skeleton_file> <atlas_file> <labels_xml_file>
# Note that the result file is the corr_p file, not the raw t-statistic file (we're going to find that
# by assuming the corr_p file is named in a standard way)

#==============================================================================
# Read in the arguments and check they exist
#------------------------------------------------------------------------------
result_p=$1
mean_skeleton=$2
atlas=$3
labels_file=$4

# Check these files all exist
for input in $1 $2 $3 $4; do
    
    if [[ ! -f ${input} ]]; then
        echo ${input} is not a file
        exit
    fi
done

#==============================================================================
# Define a couple of variable names
#------------------------------------------------------------------------------
# Figure out the atlas name from its file name
atlas_name=`basename ${atlas} .nii.gz`

# Figure out the tstat file name from the result file name
tstat=${result/_tfce_corrp/}
tstat=${result/_vox_corrp/}

# Name the result locations file from the result name and the labels file
result_locations="${result%.nii.gz}_`basename ${labels_file} .xml`.csv"

#==============================================================================
# If the locations file already exists then don't run this script
#------------------------------------------------------------------------------
if [[ -f ${result_locations} ]]; then
    echo "    ${atlas_name} locations already reported"
    exit
fi

#==============================================================================
# Create the header for the text file
#------------------------------------------------------------------------------
# But if it doesn't then create it and write in the header
echo "    ${atlas_name} reporting locations"

echo "Atlas_label, N_voxels_result, N_voxels_skeleton, Percent_of_skel" > ${result_locations}            #### NEED TO UPDATE!

#==============================================================================
# Lets start by thresholding the result for significant voxels only
# and multiplying it by the atlas
#------------------------------------------------------------------------------
# Define the file names
result_thr_bin=${result%.nii.gz}_thr95_bin.nii.gz
result_thr_atlas=${result%.nii.gz}_thr95_${atlas_name}.nii.gz
# You need to create an unclassified file as well
result_thr_atlas_unclass=${result%.nii.gz}_thr95_${atlas_name}_unclassified.nii.gz

# Create the files
fslmaths ${result} -thr 0.95 -bin ${result_thr_bin}
fslmaths ${result_thr_bin} -mul ${atlas} ${result_thr_atlas}
fslmaths ${result_thr_atlas} -bin -sub ${result_thr_bin} -mul -1 ${result_thr_atlas_unclass}

#==============================================================================
# You also need to know how many voxels from the mean skeleton fall in the atlas regions
#------------------------------------------------------------------------------
# Define the file names
mean_skeleton_atlas=${mean_skeleton%.nii.gz}_${atlas_name}.nii.gz
mean_skeleton_atlas_unclass=${mean_skeleton%.nii.gz}_${atlas_name}_unclassified.nii.gz

# Create the files
fslmaths ${mean_skeleton} -bin -mul ${atlas} ${mean_skeleton_atlas}
fslmaths ${mean_skeleton_atlas} -bin -sub ${mean_skeleton} -mul -1 ${mean_skeleton_atlas_unclass}

#==============================================================================
# Figure out a couple of important pieces of information about the atlas
#------------------------------------------------------------------------------
atlas_range=(`fslstats ${atlas} -R`)
atlas_max=${atlas_range[1]%.*}

#==============================================================================
# Now start your loop of all the atlas regions
#------------------------------------------------------------------------------

# Start a counter at 1
i=1
# Loop until you've covered all of the atlas regions
while [[ ${i} -le ${atlas_max} ]]; do

    # Mask the result with this atlas region (i)
    # Define the lower (i-1) and upper (i+1) thresholds
    l_thr=`echo ${i} - 1 | bc` 
    u_thr=`echo ${i} + 1 | bc` 
    
    # Calculate the volume of this atlas region
    vol=(`fslstats ${result_thr_atlas} -l ${l_thr} -u ${u_thr} -V`)
    
    # If there are significant voxels in this atlas region then we need to
    # record them
    if [[ ${vol} -ne 0 ]]; then
    
        # Figure out the volume of the skeleton in this region
        vol_skel=(`fslstats ${mean_skeleton_atlas} -l ${l_thr} -u ${u_thr} -V`)
        
        # Calculate the percent of the skeleon in this region that shows a significant result
        percent=(`echo "${vol}/${vol_skel} * 100" | bc -l`)

        # Find out the name of this region
        # Note that the JHU tracts list is screwed up 
        # so you have to subtract one to line up the names
        if [[ ${atlas_name} == *tracts* ]]; then
            j=`echo ${i} - 1 | bc`
        else
            j=${i}
        fi
        # Now that we know what our marker for the label is
        # we can grep for those words:
        label=`grep "label index=\"${j}\"" ${labels_file}`
        label=${label#*>}
        label=${label%<*}

        # Now write out the label, volumes and the percentage into the result locations file
        echo "${label}, ${vol}, ${vol_skel}, ${percent}" >> ${result_locations}
    fi
    # Keep your loop through the atlas regions going
    let i=${i}+1
done

# Finally add in the unclassified answer
vol=(`fslstats ${result_thr_atlas_unclass} -V`)
vol_skel=(`fslstats ${mean_skeleton_atlas_unclass} -V`)
percent=(`echo "${vol}/${vol_skel} * 100" | bc -l`)
echo "Unclassified, ${vol}, ${vol_skel}, ${percent}" >> ${result_locations}

#==============================================================================
# All done, well done ;)
#==============================================================================
