#!/bin/bash

#==============================================================================
#               NAME:  mprage_processing.sh
#
#        DESCRIPTION:  This script takes an input directory that contains
#                      highres.nii.gz and a text file containing the center
#                      of mass of this image (called center_of_mass, note the 
#                      American spelling!) and runs FSL's BET and FAST 
#                      commands as well as Freesurfer's recon-all.
#
#              USAGE:  mprage_processing.sh <mprage_dir> <sub_id>
#                           eg: mprage_processing.sh ${mprage_dir} ${sub_id}
#                           eg: mprage_processing.sh /home/kw401/MRIMPACT/ANALYSES/1106/t1/MPRAGE 1106t1
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
#             AUTHOR:  Kirstie Whitaker
#                          kw401@cam.ac.uk
#
#            CREATED:  2nd July 2013
#==============================================================================

#------------------------------------------------------------------------------
# Define usage function
function usage {
    echo "USAGE:"
    echo "mprage_processing.sh <mprage_dir> <sub_id>"
    echo "    eg: mprage_processing.sh \${mprage_dir} \${sub_id}"
    echo "    eg: mprage_processing.sh /home/kw401/MRIMPACT/ANALYSES/1106/t1/MPRAGE 1106t1"
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
# Crop the 
if [[ ! -f ${dir}/highres_orig.nii.gz ]]; then
    echo "    Calculating robust field of view"
    cp ${dir}/highres.nii.gz ${dir}/highres_orig.nii.gz
    robustfov -i ${dir}/highres_orig.nii.gz \
                -r ${dir}/highres.nii.gz \
                -m ${dir}/robustfov.mat >> ${logdir}/robustfov
    
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
          -m -f 0.2 -c ${com[@]} >> ${logdir}/bet
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
            ${dir}/highres_brain.nii.gz >> ${logdir}/fast

else
    echo "    Brain already segmented"
fi

#------------------------------------------------------------------------------
# Run recon-all
recon-all -all -i ${dir}/highres_${sub}.nii.gz \
            -s SURF \
            -sd ${dir} >> ${logdir}/reconall

#------------------------------------------------------------------------------
# And you're done!
echo "--------------------------------"
#------------------------------------------------------------------------------