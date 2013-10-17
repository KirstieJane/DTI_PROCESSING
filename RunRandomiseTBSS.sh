#!/bin/bash

#==============================================================================
#
#               FILE:  RunRandomiseTBSS.sh
#
#              USAGE:  RunRandomiseTBSS.sh <TBSS_DIR> <subs_file> <n_perms>
#
#        DESCRIPTION:  This should just run randomise on the associated 
#			.mat, .con and .grp files for the subs listed in <subs_file>
#
#       REQUIREMENTS:  Subs_file and .mat and .con files in the same folder
#                      and named with the same root
#                           eg: TestName_subs, TestName.mat TestName.con
#
#               BUGS:
#
#              NOTES:  Data is NOT demeaned, make sure your models have a column
#                      of 1s
#                      
#                      The subject id structure is specific to the study, so
#                      here each <subid> is a 4 digit number followed by t and
#                      then another number that represents their
#                      session number (eg: 1234t1). <subroot> is the part
#                      before the "t" (eg: 1234) and <occ> is the session
#                      number (eg: 1). If you are not working on MRIMPACT DTI
#                      data then you'll need to edit this script for *your*
#                      subid naming structure.
#
#             AUTHOR:  Kirstie Whitaker, kirstie.whitaker@berkeley.edu
#                      or kw401@cam.ac.uk
#
#            VERSION:  3 - MRIMPACT v3
#                        22nd March 2013: Updated again to deal with 
#                            correlations within All, Dep and Con groups
#                        21st March 2013: Updated version to go with the new
#                            Randomise_setup.py script.
#                            Notable update is that models now are demeaned
#                            across groups (rather than within group)
#                            AND (more importantly) the subs file is now 
#                            for the WHOLE folder and all data is the same for
#                            each test
#                        3rd January 2013: New version of RandomiseAnalyses.sh 
#                            for Cambridge data. Major change is that SEVEN_B0
#                            and SINGLE_B0 and has been scrapped (If you're not
#                            Kirstie and don't understand this comment then
#                            don't worry - it has to do with her PhD data!)
#                            I've also scrapped the ALL_VOLS and MOVE_COR_VOLS
#                            dual processing - there's very little movement in
#                            this data anyway!
#                                This is specific to MRIMPACT DTI data.
#
#   CREATION STARTED:  22nd April 2012
# CREATION COMPLETED:  22nd April 2012
#
#==============================================================================

### USAGE
if [ $# -ne 2 ]; then
	echo "Usage: RandomiseAnalyses.sh <TBSS_dir> <n_perms>"
	echo "Note that there must be a folder called GLM in which the .mat and .con files reside"
        echo "This subs file is literally called subs_file and will be the same for EVERY model in the GLM folder" 
	echo "There should also be a SKELETON_DATA folder within the TBSS_dir"
	echo "The results will go into a RESULTS folder within the TBSS_dir"
	echo -e "\teg: ./RandomiseAnalyses.sh /home/kw401/MRIMPACT/ANALYSES/TBSS_120214 GLM/TtestDepCon_subs 500"
	exit
fi
###

### Define variables
if [[ -d /$1 ]]; then
    tbss_dir=$1
else
    tbss_dir=`pwd`/$1
fi

echo TBSS_DIR: ${tbss_dir}

for group_path in `ls -d ${tbss_dir}/GLM/*`; do
    group=`basename ${group_path}`
    echo ${group}
    subs_file=${group_path}/subs
    if [[ ! -f ${subs_file} ]]; then
        echo "Subs file doesn't exist - check!"
        exit
    fi

    n_perms=$2
    
    skeleton_data_dir=${tbss_dir}/SKELETON_DATA/
    preproc_data_dir=${tbss_dir}/PRE_PROCESSING/
    mask_file=${preproc_data_dir}/stats/mean_FA_skeleton_mask.nii.gz

    mkdir -p ${tbss_dir}/${group}
    
    # First, create the 4D data file by finding all the data for the subjects
    # listed in the subs file and merging it together
    # We'll do this for all the different measures
    for measure in FA L1 L23 MD MO; do
        echo ${measure}
        infile=(${tbss_dir}/${group}/all_${measure}_skeletonised.nii.gz)
        if [[ ! -f ${infile} ]]; then
            rm -f $tbss_dir/temp_sublist
            for sub in `cat ${subs_file}`; do
                echo -n "${skeleton_data_dir}/${measure}/${sub}_${measure}_skeletonised.nii.gz " >> $tbss_dir/temp_sublist
            done
            echo "Merging subject data"
            fslmerge -t ${infile} `cat $tbss_dir/temp_sublist`
            rm -f ${tbss_dir}/temp_sublist
        else
            echo "Data already merged"
        fi
        # Now, multiply all "timeseries" by 1000 if they're "too small"
         echo "Checking values - running fslstats"
         st_dev=(`fslstats ${infile} -S`)
         too_small=(`echo "${st_dev} < 0.001" | bc`)
         if [[ ${too_small} == 1 ]]; then
             fslmaths ${infile} -mul 1000 ${infile}
         fi
    done
    
    # Now loop through your different designs and run randomise for all of them
    rm -f ${tbss_dir}/GLM/${group}/matlist
    for mat_file in `ls -d ${tbss_dir}/GLM/${group}/*mat`; do
        echo ${mat_file} >> ${tbss_dir}/GLM/${group}/matlist
        cat ${tbss_dir}/GLM/${group}/matlist | awk '{ print length($0),$0 | "sort -n"}' | awk ' { print $2 }' > ${tbss_dir}/GLM/${group}/matlist_sorted
    done
    
    for mat_file in `cat ${tbss_dir}/GLM/${group}/matlist_sorted`; do
        test_name=(`basename ${mat_file} .mat`)
        con_file=${mat_file%????}.con
        fts_file=${mat_file%????}.fts
        
        test_dir=${tbss_dir}/RESULTS/${test_name}/
    
        # Make logs dir in ouput dir
        mkdir -p ${test_dir}/LOGS
    
        # Loop through the different measures
        for measure in FA L1 L23 MD MO; do
            # Designate your input file
            infile=(${tbss_dir}/${group}/all_${measure}_skeletonised.nii.gz)
    
            # Name your ouput files
            outfile=${test_dir}/${measure}_${n_perms}
                
            ## Randomise command
            # Only run if it hasn't already been run!
            if [[ ! -f ${outfile}_tfce_corrp_tstat2.nii.gz ]]; then
                if [[ ! -f ${outfile}_alreadystarted ]]; then
                    echo "" > ${outfile}_alreadystarted
                    echo "Running Randomise for ${test_name} ${measure}"
                    #if [[ ${test_name:0:5} -ne 'Anova' ]]; then
                    #    demean='-D'
                    #else
                    #    demean=' '
                    #fi
                    if [[ ${test_name:0:5} == 'Anova' ]]; then
                        ftest=' -f ${fts_file} '
                    else
                        ftest=' '
                    fi
                    randomise -i ${infile} \
                            -o ${outfile} \
                            -m ${mask_file} \
                            -d ${mat_file} \
                            -t ${con_file} \
                            ${ftest} \
                            -n ${n_perms} \
                            --T2 -x ${demean} >> ${test_dir}/LOGS/${measure}_${n_perms}.log
                    rm ${outfile}_alreadystarted
                else
C                    echo "Randomise for ${test_name} ${measure} is already in progress"
                fi
            else
                echo "Data already exists"
            fi
        
        done    # Close measure loop
        
    done # Close mat file loop

done # Close group file loop
#=============================================================================
# Interesting story of the day:
#    Today is Earth Day and the google doodle is really cute.
# Heart Kx
#==============================================================================

