#!/bin/bash

#==============================================================================
#               NAME:  mprage_processing_freesurfer.sh
#
#        DESCRIPTION:  This script takes an input directory that contains all
#                      of your subjects' high_res images and runs recon-all.
#                      Each file should be named: high_res_<subid>.nii.gz 
#
#              USAGE:  mprage_processing_freesurfer.sh <freesurfer_analysis_dir> <sub_id>
#                           eg: mprage_processing_freesurfer.sh ${freesurfer_analysis_dir} ${sub_id}
#                           eg: mprage_processing_freesurfer.sh /home/kw401/MRIMPACT/ANALYSES/FREESURFER_ANALYSES/ 1106t1
#
#        PARAMETER 1:  freesurfer_analysis_dir (full path)
#                           If you're using this script as part of another
#                               eg: ${freesurfer_analysis_dir}
#                           If you're using this script alone
#                               eg: /home/kw401/MRIMPACT/ANALYSES/FREESURFER_ANALYSES/
#
#        PARAMETER 2:  sub_id
#                           eg: ${subid}
#                           eg: 1106t1
#
#             AUTHOR:  Kirstie Whitaker
#                          kw401@cam.ac.uk
#
#            CREATED:  2nd July 2013
#==============================================================================

#------------------------------------------------------------------------------
# Define usage function
function usage {
    echo "USAGE:"
    echo "mprage_processing_freesurfer.sh <freesurfer_analysis_dir> <sub_id>"
    echo "    eg: mprage_processing_freesurfer \${freesurfer_analysis_dir} \${sub_id}"
    echo "    eg: mprage_processing_freesurfer /home/kw401/MRIMPACT/ANALYSES/FREESURFER_ANALYSES/"
    exit
}
#------------------------------------------------------------------------------
 
#------------------------------------------------------------------------------
# Assign arguments
dir=$1
if [[ ! -d /${dir} ]]; then
    dir=`pwd`/${dir}
fi
sub=$2
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Check inputs

### Step 1: check arguments
# Exit if dti directory doesn't exist
if [[ ! -d ${dir} ]]; then
    echo "    No Freesurfer analysis directory"
    print_usage=1
fi

# Exit if subID is an empty string
if [[ -z ${sub} ]]; then
    echo "    SubID is blank"
    print_usage=1
fi

# Print the usage if necessary
if [[ ${print_usage} == 1 ]]; then
    usage
fi

### Step 2: Check data
# Make sure high_res_<subid> file exists
if [[ ! -f ${dir}/high_res_${sub}.nii.gz ]]; then
    if [[ -f ${dir}/high_res_${sub}.nii ]]; then
        gzip ${dir}/high_res_${sub}.nii
    else
        echo "    No high_res_${sub}.nii.gz file"
        print_usage=1
fi

# Print the usage if necessary
if [[ ${print_usage} == 1 ]]; then
    usage
fi
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Set up the freesurfer SUBJECTS_DIR variable
SUBJECTS_DIR=${dir}
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Get started
echo "SUBID: ${sub}"

# Make the LOGS dir
logdir=${dir}/LOGS
mkdir -p ${logdir}

#------------------------------------------------------------------------------
# Run recon-all
recon-all -all -i high_res_${sub}.nii.gz -s ${sub}

#------------------------------------------------------------------------------
# And you're done!
echo "--------------------------------"
#------------------------------------------------------------------------------