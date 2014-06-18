#!/bin/bash

# When you have run all your various tests, you need to report the
# significant ones. This script finds the significant results, runs
# tbss_fill, and then re-runs randomise with 5000 permutations. It
# also reports a list of significant results so that future commands
# can focus only on those.

# USAGE: ReportRandomiseResults.sh <tbss_dir> <sublist>

#==============================================================================
# Check the two inputs make sense
#------------------------------------------------------------------------------
# Read in the tbss_dir and the sublist
tbss_dir=$1
sublist=$2

# If either of them don't exist then print that and exit
if [[ ! -d ${tbss_dir} ]]; then
    echo "TBSS dir doesn't exist"
    exit
fi
if [[ ! -f ${sublist} ]]; then
    echo "sublist doesn't exist"
    exit
fi

#==============================================================================
# Start by writing out a list of all the significant results
#------------------------------------------------------------------------------
echo "Creating list of significant results"

# Name the results list file and remove any old versions of the file
results_list=${tbss_dir}/RESULTS/significant_results_list.txt
rm -f ${results_list}

# Loop through the result files
for result in `ls -d ${tbss_dir}/RESULTS/*/*/*tfce_corrp*tstat?.nii.gz`; do
    # Find the range of each result file
    range=(`fslstats ${result} -R`)
    # Figure out if the most significant voxel is > 0.95 ( p < 0.05 )
    sig=(`echo "${range[1]} > 0.95" | bc -l`)

    # If there are significant voxels then write this file
    # (with its whole path so you can find it)
    # into the sig_results_list file
    if [[ ${sig} == 1 ]]; then
        echo ${result} >> ${tbss_dir}/RESULTS/significant_results_list.txt
    fi
done

#==============================================================================
# TBSS_fill all of the significant results files and report where the
# significant results are located
#------------------------------------------------------------------------------

# Loop through the significant results
for sig_result in `cat ${results_list}`; do
    echo "Significant result: ${sig_result}"
    # If that significant result does not already have a tbss_fill file
    # then tbss_fill it
    if [[ ! -f ${sig_result%.nii.gz}_FILL.nii.gz ]]; then
        echo "    Now running tbss_fill"
        tbss_fill ${sig_result} \
                   0.95 \
                   ${tbss_dir}/PRE_PROCESSING/stats/mean_FA.nii.gz \
                   ${sig_result%.nii.gz}_FILL.nii.gz
    
    # If the _FILL file already exists then just echo that and move on
    else
        echo "    Tbss_fill already complete"
    fi

    # It's also useful to have a binarized FILL file so check to see if that
    # exists yet
    if [[ ! -f ${sig_result%.nii.gz}_FILL_bin.nii.gz ]]; then
        echo "    Binarizing tbss_fill result"
        # And if it doesn't, binarize the tbss_fill file
        # in case you need to overlay it
        fslmaths ${sig_result%.nii.gz}_FILL.nii.gz -bin ${sig_result%.nii.gz}_FILL_bin.nii.gz 
    else
        echo "    Tbss_fill binarized"
    fi
    
    # Figure out the locations of all the significant results

    # Define a couple of variables:
    # The ReportingResultLocations script and atlas directory
    report_locations_script=`dirname ${0}`/ReportingResultLocations.sh
    atlas_dir=${FSLDIR}/data/atlases/

    # Run this script for this significant result (remember we're in a loop)
    
    # JHU-labels atlas
    ${report_locations_script} ${sig_result} \
                            ${tbss_dir}/PRE_PROCESSING/stats/mean_FA_skeleton.nii.gz \
                            ${atlas_dir}/JHU/JHU-ICBM-labels-1mm.nii.gz \
                            ${atlas_dir}/JHU-labels.xml

    # JHU-tracts atlas
    ${report_locations_script} ${sig_result} \
                            ${tbss_dir}/PRE_PROCESSING/stats/mean_FA_skeleton.nii.gz \
                            ${atlas_dir}/JHU/JHU-ICBM-tracts-maxprob-thr0-1mm.nii.gz \
                            ${atlas_dir}/JHU-tracts.xml

done # End the significant result loop

#==============================================================================
# Now extract a bunch of average values from all significant results
#------------------------------------------------------------------------------
extract_values_script=`dirname ${0}`/Extract_values.sh
${extract_values_script} ${tbss_dir} ${sublist}
#==============================================================================
