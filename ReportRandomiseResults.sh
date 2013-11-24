#!/bin/bash

# When you have run all your various tests, you need to report the
# significant ones. This script finds the significant results, runs
# tbss_fill, and then re-runs randomise with 5000 permutations. It
# also reports a list of significant results so that future commands
# can focus only on those.

# USAGE: ReportRandomiseResults.sh <tbss_dir>

tbss_dir=$1
if [[ ! -d ${tbss_dir} ]]; then
    echo "TBSS dir doesn't exist"
    exit
fi

#==============================================================================
# Lets start by writing out that list of all the significant results
echo "Creating list of significant results"

results_list=${tbss_dir}/RESULTS/significant_results_list.txt
rm -f ${results_list}

for result in `ls -d ${tbss_dir}/RESULTS/*/*/*tfce_corrp*`; do
    range=(`fslstats ${result} -R`)
    sig=(`echo "${range[1]} > 0.95" | bc -l`)

    if [[ ${sig} == 1 ]]; then
        echo ${result} >> ${tbss_dir}/RESULTS/significant_results_list.txt
    fi
done

#==============================================================================
# Fill all of the significant results files
for sig_result in `cat ${results_list}`; do
    tbss_fill ${sig_result} \
                   0.95 \
                   ${tbss_dir}/PRE_PROCESSING/stats/mean_FA.nii.gz \
                   ${sig_result%.nii.gz}_FILL.nii.gz

    # Figure out the locations of all the significant results
    # First you need to find the right script
    report_locations_script=`dirname ${0}`/ReportingResultLocations.sh

    atlas_dir=${FSLDIR}/data/atlases/

    ${report_locations_script} ${sig_result} \
                            ${tbss_dir}/PRE_PROCESSING/stats/mean_FA_skeleton.nii.gz \
                            ${atlas_dir}/JHU/JHU-ICBM-labels-1mm.nii.gz \
                            ${atlas_dir}/JHU-labels.xml

    ${report_locations_script} ${sig_result} \
                            ${tbss_dir}/PRE_PROCESSING/stats/mean_FA_skeleton.nii.gz \
                            ${atlas_dir}/JHU/JHU-ICBM-tracts-maxprob-thr0-1mm.nii.gz \
                            ${atlas_dir}/JHU-tracts.xml

done
#==============================================================================
