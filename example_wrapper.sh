#!/bin/bash

#=============================================================================
# This script is a little loop that downloads the code from GitHub
# and runs the dti_processing and mprage and registrations scripts.
# You should download this to your data directory, and then edit it 
# as needed.
#
# There should be a file called sublist in your data directory (where you save
# this wrapper script) that contains the subject IDs.
#
# In this example your data is in a folder called SUB_DATA (which is inside 
# the data directory) and then inside folders named using the subject IDs
# (as listed in the sublist file described above).
#
# Every subject has a directory called DTI, which contains the DTI data,
# MPRAGE which contains the high resolution data, and REG, which will contain
# the registrations from the various spaces to each other.
#
# If you have any questions please do email Kirstie at kw401@cam.ac.uk
#
# October 25th 2013
#=============================================================================

####
# Set up the test directory variables
dir=`pwd`
sublist=${dir}/sublist

####
# Create the SCRIPTS directory
mkdir -p ${dir}/SCRIPTS

####
# Download the code from GitHub
rm -f ${dir}/SCRIPTS/DTI_PROCESSING
wget -O ${dir}/SCRIPTS/DTI_PROCESSING https://github.com/HappyPenguin/DTI_PROCESSING/archive/master.zip

####
# Unzip the DTI_PROCESSING
#+ -o option forces overwrite
#+ -f option only refreshes files that have changed
unzip -o ${dir}/SCRIPTS/DTI_PROCESSING -d ${dir}/SCRIPTS/

####
# Make all files executable
chmod +x ${dir}/SCRIPTS/DTI_PROCESSING-master/*

####
# Convert all files from dos to unix
dos2unix ${dir}/SCRIPTS/DTI_PROCESSING-master/*
# This is a really important step btw 
#+ you get uninteligable error messages if you don't run it!

####
# Decide on your bedpostx and freesufer options
bedpostx_option=yes
freesurfer_option=yes

####
# Run the code!
for sub in `cat ${sublist}`; do
    echo ${sub}
    ${dir}/SCRIPTS/DTI_PROCESSING-master/dti_preprocessing.sh ${dir}/SUB_DATA/${sub}/DTI/ ${sub} ${bedpostx_option}
    ${dir}/SCRIPTS/DTI_PROCESSING-master/mprage_processing.sh ${dir}/SUB_DATA/${sub}/MPRAGE/ ${sub} ${freesurfer_option}
    ${dir}/SCRIPTS/DTI_PROCESSING-master/registrations.sh ${dir}/SUB_DATA/${sub}/DTI/ ${dir}/SUB_DATA/${sub}/MPRAGE/ ${sub}

done
