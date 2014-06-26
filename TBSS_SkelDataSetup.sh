#!/bin/bash
#==============================================================================
#
#               FILE:  TBSS_SkelDataSetup.sh
#
#              USAGE:  TBSS_SkelDataSetup.sh <data_dir> <TBSS_dir> <sublist>
#
#        DESCRIPTION:  This looks for every subject in sublist to see if TBSS
#                      is completed and creates individualized skeletonised
#                      TBSS data in the TBSS_DIR
#
#          PARAMETERS:  <data_dir> is the full path to the directory that
#                              contains the output from Filesetup.sh
#                        <TBSS_dir> is the name of the TBSS dir that will
#                                be created in the data_dir
#                       <sublist> is a text file that contains the subids
#                              of each participant
#
#      EXAMPLE USAGE:  SCRIPTS/TBSS_SkelDataSetup.sh `pwd` TBSS_121210
#                                                            sublist_Mrimpact
# 
#
#       REQUIREMENTS:  DTI_Preprocessing must have been run.
#
#               BUGS:
#
#              NOTES:  The subject id structure is specific to the study, so
#                       here each <subid> is a 4 digit number followed by t and
#                       then another number that represents their
#                       session number (eg: 1234t1). <subroot> is the part
#                       before the "t" (eg: 1234) and <occ> is the session
#                       number (eg: 1). If you are not working on MRIMPACT DTI
#                       data then you'll need to edit this script for *your*
#                       subid naming structure.
#
#             AUTHOR:  Kirstie Whitaker, kirstie.whitaker@berkeley.edu
#                      or kw401@cam.ac.uk
#
#            VERSION:  2.2 - MRIMPACT v1
#                        18th December 2012: Updated for MRIMPACT data
#                        10th December 2012: New version of TBSS_SkelDataSetup.sh 
#                            for Cambridge data. Major change is that SEVEN_B0
#                            and SINGLE_B0 and has been scrapped (If you're not
#                            Kirstie and don't understand this comment then
#                            don't worry - it has to do with her PhD data!)
#                            I've also scrapped the ALL_VOLS and MOVE_COR_VOLS
#                            dual processing - there's very little movement in
#                            this data anyway!
#                                This is specific to NSPN Pilot DTI data.
#                        
#   CREATION STARTED:  22nd April 2012
# CREATION COMPLETED:  22nd April 2012
#
#==============================================================================

#------------------------------------------------------------------------------
# Being a Nice Person - checking the inputs are all correct before starting
#------------------------------------------------------------------------------
# If no arguments are given then echo the usage and exit
if [[ $# -ne 4 ]]; then
    echo "Not enough options given"
    echo "Usage: TBSS_SkelDataSetup.sh <data_dir> <tbss_dir> <sublist> <dti_identifier>"
    exit
fi
#
# If the first argument is not a directory then print error and exit
if [[ ! -d $1 ]]; then
    echo "First argument is not an existing directory"
    echo "Usage: TBSS_SkelDataSetup.sh <data_dir> <tbss_dir> <sublist> <dti_identifier>"
    exit
fi
#
# If the third argument is not a file then print error and exit
if [[ ! -f $3 ]]; then
    echo "Third argument is not an existing file"
    echo "Usage: TBSS_SkelDataSetup.sh <data_dir> <tbss_dir> <sublist> <dti_identifier>"
    exit
fi

# If the fourth argument is not a string then print error and exit
if [[ -z $4 ]]; then
    echo "Fourth argument (dti_identifier) has not been given"
    echo "Usage: TBSS_SkelDataSetup.sh <data_dir> <tbss_dir> <sublist> <dti_identifier>"
    exit
fi
#
#
#------------------------------------------------------------------------------
# Define Variables - many of these are hard coded - CHECK if they make sense!
#------------------------------------------------------------------------------
#

if [[ -d /$1 ]]; then
    data_dir=$1
else
    data_dir=`pwd`/$1
fi

tbss_dir=$2

if [[ ${tbss_dir} == ${data_dir}* ]]; then
    tbss_dir=${tbss_dir#${data_dir}}
fi

sublist=$3

dti_identifier=$4

preproc_data_dir=${data_dir}/${tbss_dir}/${dti_identifier}/PRE_PROCESSING
skel_data_dir=${data_dir}/${tbss_dir}/${dti_identifier}/SKELETON_DATA/

mkdir -p ${preproc_data_dir}/FA
mkdir -p ${skel_data_dir}

# Don't run this script if it has already been completed
if [[ -f ${preproc_data_dir}/stats/all_MO_skeletonised.nii.gz ]]; then
    echo "TBSS data already pre-processed"
    echo "If you want to run it again, DELETE the PRE_PROCESSING folder"
    exit
fi

#
#------------------------------------------------------------------------------
# Ok, lets actually get started
# Here is the beginnings of the subject FOR loop:
#------------------------------------------------------------------------------

echo "Running TBSS_SkelDataSetup"
for sub in `cat $sublist`; do

    # Print sub to screen so you can follow along as the script runs
    echo -e "\tSUBID: ${sub}"
        
    sub_dti_dir=(${data_dir}/SUB_DATA/${sub}/${dti_identifier}/)
    sub_fdt_dir=${sub_dti_dir}/FDT/
    sub_tbss_dir=${sub_dti_dir}/TBSS/
    
    # If TBSS has been run on this individual then link their warp data
    # to the FA folder in the preproc data dir 
    if [[ -f ${sub_tbss_dir}/FA/${sub}_FA_FA_to_target_warp.nii.gz ]]; then
        for file in `ls -d ${sub_tbss_dir}/FA/${sub}*`; do
            filename=`basename ${file}`
            ln ${file} ${preproc_data_dir}/FA/${filename} 2>/dev/null
        done
            
        # Copy the other measures to the pre proc dir in their own folders
        # but NAMED exactly the same as the FA file
        # Note that these files are not linked because they may need to be
        # reoriented to standard space (as the FA files were rotated in the
        # subject's personal TBSS directories)
        for measure in L1 L23 MD MO; do
            mkdir -p ${preproc_data_dir}/${measure}
            cp ${sub_fdt_dir}/${sub}_${measure}.nii.gz \
                    ${preproc_data_dir}/${measure}/${sub}_FA.nii.gz
            # Rotate this file to standard orientation
            # You aren't registering it, just making the brain face the right way
            fslreorient2std ${preproc_data_dir}/${measure}/${sub}_FA.nii.gz \
                    ${preproc_data_dir}/${measure}/${sub}_FA.nii.gz
        done
    else
        echo -e "\t\tNo data"
    fi
    
done # Close sub loop

# You only want one copy of the target file, so just do it for the first subject
# that has one of these files
target_files=(`ls -d ${data_dir}/SUB_DATA/*/${dti_identifier}/TBSS/FA/target.nii.gz`)
ln -t ${preproc_data_dir}/FA/ ${target_files[0]}

# Run the rest of the tbss pipeline
cd ${preproc_data_dir}
    
echo -e "\tTBSS processing"
tbss_3_postreg -S > ${preproc_data_dir}/log_tbss

tbss_4_prestats 0.2 >> ${preproc_data_dir}/log_tbss

echo -e "\t\tNon FA: L1"
tbss_non_FA L1 >> ${preproc_data_dir}/log_tbss
echo -e "\t\tNon FA: L23"
tbss_non_FA L23 >> ${preproc_data_dir}/log_tbss
echo -e "\t\tNon FA: MD"
tbss_non_FA MD >> ${preproc_data_dir}/log_tbss
echo -e "\t\tNon FA: MO"
tbss_non_FA MO >> ${preproc_data_dir}/log_tbss

cd ${data_dir}

# The last step is to split up each of the skeletonised
# output files into individual subject data files
mkdir -p ${skel_data_dir}

echo -e "\tSpliting and renaming files"
for measure in FA L1 L23 MD MO; do
    mkdir -p ${skel_data_dir}/${measure}/
            
    # Delete any files that might be in these folders
    # otherwise the split command will just add to these files and you'll
    # have double what you're supposed to have!
    rm -f ${skel_data_dir}/${measure}/*
            
    fslsplit ${preproc_data_dir}/stats/all_${measure}_skeletonised.nii.gz \
        ${skel_data_dir}/${measure}/SPLIT -t
    i=0
    subs_names=(`ls -d ${preproc_data_dir}/${measure}/*_FA.nii.gz`)
    files=(`ls -d ${skel_data_dir}/${measure}/SPLIT*nii.gz`)
    while [[ ${i} -lt ${#subs_names[@]} ]]; do
        if [[ ${measure} == FA ]]; then
            subname=(`basename ${subs_names[${i}]} _FA_FA.nii.gz`)
        else
            subname=(`basename ${subs_names[${i}]} _FA.nii.gz`)
        fi
        mv ${files[${i}]} ${skel_data_dir}/${measure}/${subname}_${measure}_skeletonised.nii.gz
        let i=${i}+1
    done

done # End measure loop

