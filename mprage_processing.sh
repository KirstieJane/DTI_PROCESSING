#!/bin/bash

#==============================================================================
#               NAME:  mprage_processing.sh
#
#        DESCRIPTION:  This script takes an input directory that contains
#                      highres.nii.gz and a text file containing the center
#                      of mass of this image (called center_of_mass, note the 
#                      American spelling!) and runs FSL's BET and FAST 
#                      commands as well as Freesurfer's recon-all (unless the
#                      freesurfer_option is set to something other than "yes").
#
#              USAGE:  mprage_processing.sh <mprage_dir> <sub_id> <freesurfer_option>
#                           eg: mprage_processing.sh ${mprage_dir} ${sub_id} ${freesurfer_option}
#                           eg: mprage_processing.sh /home/kw401/MRIMPACT/ANALYSES/1106/t1/MPRAGE 1106t1 no
#
#        PARAMETER 1:  mprage_dir (full path)
#                           If you're using this script as part of another
#                               eg: ${mprage_dir}
#                           If you're using this script alone
#                               eg: /home/kw401/MRIMPACT/ANALYSES/1106/t1/MPRAGE
#
#        PARAMETER 2:  sub_id
#                           eg: ${subid}
#                           eg: 1106t1
#
#        PARAMETER 3:  freesurfer_option
#                           Default this is set to yes, if you type anything
#                           other than yes then recon-all will be skipped
#                               eg: ${freesurfer_option}
#                               eg: no 
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
    echo "mprage_processing.sh <mprage_dir> <sub_id> <freesurfer_option>"
    echo "    eg: mprage_processing.sh \${mprage_dir} \${sub_id} \${freesurfer_option}"
    echo "    eg: mprage_processing.sh /home/kw401/MRIMPACT/ANALYSES/1106/t1/MPRAGE 1106t1 yes"
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

if [[ ! -z ${freesurfer_option} ]]; then
    freesurfer_option=$3
else
    freesurfer_option=yes
fi

#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Check inputs

### Step 1: check arguments
# Exit if mprage directory doesn't exist
if [[ ! -d ${dir} ]]; then
    echo "    No MPRAGE directory"
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
# Make sure highres file exists
if [[ ! -f ${dir}/highres.nii.gz ]]; then
    if [[ -f ${dir}/highres.nii ]]; then
        gzip ${dir}/highres.nii
    else
        echo "    No highres.nii.gz file"
        print_usage=1
    fi
fi

# And make sure there are 3 numbers in the center of mass file
if [[ ! -f ${dir}/center_of_mass ]]; then
    echo "    center_of_mass file doesn't exist"
    print_usage=1
else
    # Define the center of mass variable and make sure it has
    # three variables in it
    com=(`cat ${dir}/center_of_mass`)
    if [[ ${#com[@]} != 3 ]]; then
        echo "    center_of_mass file doesn't contain three values"
        print_usage=1
    fi
fi

# Print the usage if necessary
if [[ ${print_usage} == 1 ]]; then
    usage
fi
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Get started
echo "DIR: ${dir}"
echo "SUBID: ${sub}"

# Make the LOGS dir
logdir=${dir}/LOGS
mkdir -p ${logdir}

#------------------------------------------------------------------------------
# Crop the mprage to have a robust field of view so that there isn't
# too much neck
if [[ ! -f ${dir}/robustfov.mat ]]; then
    echo "    Calculating robust field of view"
    cp ${dir}/highres.nii.gz ${dir}/highres_orig.nii.gz
    
    robustfov -i ${dir}/highres_orig.nii.gz \
                -r ${dir}/highres.nii.gz \
                -m ${dir}/robustfov.mat >> ${logdir}/robustfov 2>> ${logdir}/errors_robustfov
    
    # Update the center of mass:
    robustfov=(`cat ${dir}/robustfov.mat`)
    com[2]=`echo "${com[2]}-${robustfov[11]}" | bc`

else
    echo "    Robust field of view already calculated"

fi

#------------------------------------------------------------------------------
# Brain extract the mprage file
if [[ ! -f ${dir}/highres_brain_mask.nii.gz ]]; then
    echo "    Brain extracting"
    bet ${dir}/highres.nii.gz ${dir}/highres_brain.nii.gz \
          -m -f 0.2 -c ${com[@]} >> ${logdir}/bet 2>> ${logdir}/errors_bet
else
    echo "    Brain already extracted"

fi

#------------------------------------------------------------------------------
# Segment the brain    
if [[ ! -f ${dir}/highres_brain_mask.nii.gz ]]; then
    echo "    ERROR: Can't segment because brain extraction has not been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${dir}/highres_brain_seg_2.nii.gz ]]; then
    echo "    Segmenting"
    fast -g -o ${dir}/highres_brain \
            ${dir}/highres_brain.nii.gz >> ${logdir}/fast 2>> ${logdir}/errors_fast

else
    echo "    Brain already segmented"
fi

if [[ ! -f ${dir}/highres_brain_wmseg.nii.gz ]]; then
    echo "    Renaming white matter segmentation image"
    fslmaths ${dir}/highres_brain_pve_2.nii.gz -thr 0.5 \
                -bin ${dir}/highres_brain_wmseg.nii.gz

else
    echo "    White matter segmentation image already made"
fi

#------------------------------------------------------------------------------
# Run recon-all
if [[ ${run_freesurfer} == 'yes' ]]; then
    ### Put in a little if loop here in case it has already been run??
    ### But freesurfer might just take care of this??
    echo "    Running freesurfer's recon-all"
    # If it's a brand new start:
    if [[ ! -f ${dir}/SURF/mri/orig/001.mgz ]]; then
        echo "============ START FROM THE BEGINNING ============="
        rm -rf ${dir}/SURF
        recon-all -all -i ${dir}/highres.nii.gz \
                    -s SURF \
                    -sd ${dir} >> ${logdir}/reconall 2>> ${logdir}/errors_reconall

    else
        echo '=============== MAKE ALL =============='
        recon-all -all -s SURF \
                    -sd ${dir} \
                    -make all >> ${logdir}/reconall 2>> ${logdir}/errors_reconall
    fi   
fi
                
#------------------------------------------------------------------------------
# And you're done!
echo "--------------------------------"
#------------------------------------------------------------------------------