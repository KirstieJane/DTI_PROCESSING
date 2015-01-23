#!/bin/bash

#==============================================================================
#
#               FILE:  RunRandomiseTBSS.sh
#
#              USAGE:  RunRandomiseTBSS.sh <TBSS_DIR> <n_perms>
#
#        DESCRIPTION:  This will look in the TBSS_DIR and find the GLM directory.
#                      It will then look for each group in the GLM directory and
#                      *then* will run all of the pairs of .mat & .con files
#                      that it finds in that group directory. It will run tests
#                      for all five DTI measures (FA, MD, L1, L23 and MO).
#                      The output will be saved in <TBSS_DIR>/RESULTS/<group_name>/<test_name>/
#                      Each group directory must be set up with one subs file.
#                      If you are missing data from any of the measures you'll
#                      have to set up a new group file!
#
#       REQUIREMENTS:  GLM directory inside TBSS_DIR at the same level as 
#                      INPUT_FILES, containing any number of <GROUP> dirs.
#                      Each <GROUP> dir should contain a single subs file
#                      (called subs) and any number of pairs of .mat and 
#                      .con files called eg: TestName.mat TestName.con
#
#               BUGS:
#
#              NOTES:  
#
#             AUTHOR:  Kirstie Whitaker, kirstie.whitaker@berkeley.edu
#                      or kw401@cam.ac.uk
#
#            VERSION:  4 - Generalised! 
#                      3 - MRIMPACT v3
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
#            UPDATED:  17th December 2014
#
#==============================================================================

### USAGE
if [ $# -ne 2 ]; then
	echo "Usage: RandomiseAnalyses.sh <TBSS_dir> <n_perms>"
	echo "Note that there must be a folder called GLM that contains any" 
    echo "number of <GROUP> directories which in turn contain one subs file"
    echo "and any number of pairs of .mat and .con files"
	echo "There should also be a SKELETON_DATA folder within the TBSS_dir"
	echo "The results will go into a RESULTS folder within the TBSS_dir"
	echo -e "\teg: ./RunRandomise.sh /home/kw401/MRIMPACT/ANALYSES/TBSS_120214 500"
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

    ##### A STUPID HACK FOR MRIMPACT
    if [[ ${tbss_dir} == *mrimpact* ]]; then
        subs_file=${group_path}/subs_t1
    fi
    
    n_perms=$2
    
    skeleton_data_dir=${tbss_dir}/SKELETON_DATA/
    preproc_data_dir=${tbss_dir}/PRE_PROCESSING/
    mask_file=${preproc_data_dir}/stats/mean_FA_skeleton_mask.nii.gz

    mkdir -p ${tbss_dir}/INPUT_FILES/${group}
    
    # First, create the 4D data file by finding all the data for the subjects
    # listed in the subs file and merging it together
    # We'll do this for all the different measures
    for measure in FA L1 L23 MD MO; do
        echo ${measure}
        infile=(${tbss_dir}/INPUT_FILES/${group}/all_${measure}_skeletonised.nii.gz)
        if [[ ! -f ${infile} ]]; then
            rm -f $tbss_dir/temp_sublist
            for sub in `cat ${subs_file}`; do
                echo -n "${skeleton_data_dir}/${measure}/${sub}_${measure}_skeletonised.nii.gz " >> $tbss_dir/temp_sublist
            done
            echo "Merging subject data"
            fslmerge -t ${infile} `cat $tbss_dir/temp_sublist`
            # Now, multiply all "timeseries" by 1000 if they're "too small"
            echo "Checking values - running fslstats"
            st_dev=(`fslstats ${infile} -S`)
            too_small=(`echo "${st_dev} < 0.001" | bc`)
            if [[ ${too_small} == 1 ]]; then
                fslmaths ${infile} -mul 1000 ${infile}
            fi
            rm -f ${tbss_dir}/temp_sublist
        else
            echo "Data already merged"
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
        
        test_dir=${tbss_dir}/RESULTS/${group}/${test_name}/
    
        # Make logs dir in output dir
        mkdir -p ${test_dir}/LOGS
    
        # Loop through the different measures
        for measure in FA L1 L23 MD MO; do
            # Designate your input file
            infile=(${tbss_dir}/INPUT_FILES/${group}/all_${measure}_skeletonised.nii.gz)
    
            # Name your output files
            outfile=${test_dir}/${measure}_${n_perms}
            
            ## Randomise command
            # Only run if it hasn't already been run!
            if [[ ! -f ${outfile}_tfce_corrp_tstat2.nii.gz ]]; then
            
                # Or if the randomise command has already been submitted or started somewhere else
                if [[ ! -f ${outfile}_alreadystarted ]]; then
                    echo "" > ${outfile}_alreadystarted
                    echo "Running Randomise for ${test_name} ${measure}"

                    # If you're on the CBU you can submit this to a queue, so instead of 
                    # just running it in the terminal so we're going to write the command
                    # to a script text file ready to be submitted or run wherever.
                    echo '#!/bin/bash' > ${outfile}_randomisecommand.sh
                    
                    echo "#PBS -N ${test_name}_${measure}" >> ${outfile}_randomisecommand.sh
                    echo "#PBS -o ${test_dir}/LOGS/${measure}_${n_perms}_PBSoutput.log" >> ${outfile}_randomisecommand.sh
                    echo "#PBS -e ${test_dir}/LOGS/${measure}_${n_perms}_PBSerrors.log" >> ${outfile}_randomisecommand.sh

                    # If you're running a TTest then you shouldn't demean your columns
                    if [[ ${test_name:0:5} != 'TTest' ]]; then
                        demean='-D'
                    else
                        demean=' '
                    fi
                    
                    # I'm not quite sure what I'm doing here - have a think about running
                    # anovas in the future...
                    if [[ ${test_name:0:5} == 'Anova' ]]; then
                        demean=' '
                        ftest=" -f ${fts_file} "
                    else
                        ftest=' '
                    fi
                    
                    # Write the command to the randomisecommand file
                    echo "randomise -i ${infile} \
                            -o ${outfile} \
                            -m ${mask_file} \
                            -d ${mat_file} \
                            -t ${con_file} \
                            ${ftest} \
                            -n ${n_perms} \
                            --T2 -x ${demean} \
                            --glm_output " >> ${outfile}_randomisecommand.sh
                    
                    # Make this file executable
                    chmod +x ${outfile}_randomisecommand.sh
                    
                    # If you're Kirstie and on the CBU server then we're going to use
                    # qsub and send this script to the cluster
                    if [[ ${outfile} == *kw02* ]]; then
                        qsub ${outfile}_randomisecommand.sh
                    
                    # Otherwise, just run the script in the shell as usual
                    else
                        ${outfile}_randomisecommand.sh
                    fi
                else
                    echo "Randomise for ${test_name} ${measure} is already in progress"
                fi
            else
                # The results are already here, so just print that to the screen
                # and then remove any marker files that might be there
                echo "Data already exists"
                rm -f ${outfile}_alreadystarted
            fi
        done    # Close measure loop
        
    done # Close mat file loop

done # Close group file loop
#=============================================================================
# Interesting story of the day:
#    Today is Earth Day and the google doodle is really cute.
# Heart Kx
#==============================================================================

