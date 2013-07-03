#!/bin/bash

####
# Set up the test directory variables
dir=`pwd`
sublist=${dir}/sublist
echo "1106t1" > ${sublist}

####
# Create the SCRIPTS directory
mkdir -p ${dir}/SCRIPTS

####
# Download the code from GitHub
wget -O ${dir}/SCRIPTS/DTI_PROCESSING https://github.com/HappyPenguin/DTI_PROCESSING/archive/master.zip

####
# Unzip the DTI_PROCESSING
#+ -o option forces overwrite
#+ -f option only refreshes files that have changed
unzip -of ${dir}/SCRIPTS/GitHubCode -d ${dir}/SCRIPTS/

####
# Make all files executable
chmod +x ${dir}/SCRIPTS/DTI_PROCESSING-master/*

####
# Convert all files from dos to unix
dos2unix ${dir}/SCRIPTS/DTI_PROCESSING-master/*
# This is a really important step btw 
#+ you get uninteligable error messages if you don't run it!

####
# Run the code!
for sub in `cat ${sublist}`; do
    echo ${sub}
    ${dir}/SCRIPTS/DTI_PROCESSING-master/dti_preprocessing.sh ${dir}/SUB_DATA/${sub}/DTI/ ${sub}
    ${dir}/SCRIPTS/DTI_PROCESSING-master/mprage_preprocessing.sh ${dir}/SUB_DATA/${sub}/MPRAGE/ ${sub}
    ${dir}/SCRIPTS/DTI_PROCESSING-master/dti_registrations.sh ${dir}/SUB_DATA/${sub}/DTI/ ${dir}/SUB_DATA/${sub}/MPRAGE/

done
