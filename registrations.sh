#!/bin/bash

#==============================================================================
#               NAME:  registrations.sh
#
#        DESCRIPTION:  This script takes, as an input directory, the
#                      individual participant's DTI directory that was passed
#                      to dti_preprocessing.sh and the MPRAGE directory that
#                      was passed to mprage_processing.sh. It then creates a 
#                      REG directory at the same level as the DTI directory
#                      called REG_<DTI_basename> or REG if the basename is 
#                      blank. This directory contains all the necessary
#                      transformations to get between the following spaces:
#                      DTI, FSL_highres, Freesurfer, MNI152.
#
#              USAGE:  registrations.sh <dti_data_folder> <mprage_data_folder>
#                           eg: registrations.sh ${dti_dir} ${mprage_dir} ${subid}
#                           eg: registrations.sh /home/kw401/MRIMPACT/ANALYSES/1106/t1/DTI /home/kw401/MRIMPACT/ANALYSES/1106/t1/MPRAGE 1106t1
#
#        PARAMETER 1:  DTI data folder (full path)
#                           If you're using this script as part of another
#                               eg: ${dti_dir}
#                           If you're using this script alone
#                               eg: /home/kw401/MRIMPACT/ANALYSES/1106/t1/DTI 
#
#        PARAMETER 2:  MPRAGE data folder (full path)
#                           If you're using this script as part of another
#                               eg: ${mprage_dir}
#                           If you're using this script alone
#                               eg: /home/kw401/MRIMPACT/ANALYSES/1106/t1/MPRAGE
#
#        PARAMETER 3:  subject ID
#                           eg: ${subid}
#                           eg: 1106t1
#
#             AUTHOR:  Kirstie Whitaker
#                          kw401@cam.ac.uk
#
#            CREATED:  19th February 2013
#==============================================================================

#------------------------------------------------------------------------------
# Define usage function
function usage {
    echo "USAGE:"
    echo "registrations.sh <dti_data_folder> <mprage_data_folder> <subid>"
    echo "    eg: registrations.sh \${dti_dir} \${mprage_dir} \${subid}"
    echo "    eg: registrations.sh /home/kw401/MRIMPACT/ANALYSES/1106/t1/DTI /home/kw401/MRIMPACT/ANALYSES/1106/t1/MPRAGE 1106t1"
    exit
}
#------------------------------------------------------------------------------
 
#------------------------------------------------------------------------------
# Assign arguments
dti_dir=$1
if [[ ! -d /${dti_dir} ]]; then
    dir=`pwd`/${dti_dir}
fi

mprage_dir=$2
if [[ ! -d /${mprage_dir} ]]; then
    dir=`pwd`/${mprage_dir}
fi

surf_dir=${mprage_dir}/SURF/

sub=$3
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Check inputs

### Step 1: check arguments
# Exit if dti directory doesn't exist
if [[ ! -d ${dti_dir} ]]; then
    echo "    No DTI directory"
    print_usage=1
fi

# Exit if mprage directory doesn't exist
if [[ ! -d ${mprage_dir} ]]; then
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
# Make sure dti_ec_brain.nii.gz, <subid>_FA.nii.gz, highres_brain.nii.gz,
# highres.nii.gz, rawavg.mgz and orig.mgz files exist
for dti_file in ${dti_dir}/dti_ec_brain.nii.gz \
                    ${dti_dir}/FDT/${sub}_FA.nii.gz; do
    if [[ ! -f ${dti_file} ]]; then
        echo "    No `basename ${dti_file}` file"
        echo "    Check that dti_preprocessing.sh has finished"
        print_usage=1
    fi
done

for highres_file in ${mprage_dir}/highres.nii.gz ${mprage_dir}/highres_brain.nii.gz; do
    if [[ ! -f ${highres_file} ]]; then
        echo "    No `basename ${highres_file}` file"
        echo "    Check that mprage_processing.sh has finished"
        print_usage=1
    fi
done

for surf_file in ${surf_dir}/mri/rawavg.mgz ${surf_dir}/mri/orig.mgz ; do
    if [[ ! -f ${surf_file} ]]; then
        echo "    No `basename ${surf_file}` file"
        echo "    Check that mprage_processing.sh has finished"
        print_usage=1
    fi
done

# Print the usage if necessary
if [[ ${print_usage} == 1 ]]; then
    usage
fi
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Get started
echo "DTI_DIR: ${dti_dir}"
echo "MPRAGE_DIR: ${mprage_dir}"
echo "SURF_DIR: ${surf_dir}"

# Define the registration directory
reg_dir=(`dirname ${dti_dir}`)

# Make the LOGS dir
logdir=${reg_dir}/LOGS
mkdir -p ${logdir}

#------------------------------------------------------------------------------
# Register diffusion images to highres space using Flirt

# b0 weighted file
if [[ ! -f ${reg_dir}/diffB0_TO_highres.mat ]]; then
    echo "    Flirting dti_ec_brain to highres"
    flirt -ref ${mprage_dir}/highres_brain.nii.gz \
            -in ${dti_dir}/dti_ec_brain.nii.gz \
            -omat ${reg_dir}/diffB0_TO_highres.mat

else
    echo "    dti_ec_brain already flirted to highres"

fi

# Invert this flirt transform
if [[ ! -f ${reg_dir}/diffB0_TO_highres.mat ]]; then
    echo "    ERROR: Can't invert transform as flirt has not been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${reg_dir}/highres_TO_diffB0.mat ]]; then
    echo "    Inverting flirt transform"
    convert_xfm -omat ${reg_dir}/highres_TO_diffB0.mat \
                -inverse ${reg_dir}/diffB0_TO_highres.mat

else
    echo "    Inverse flirt transform already calculated"

fi

# FA file
if [[ ! -f ${reg_dir}/diffFA_TO_highres.mat ]]; then
    echo "    Flirting <subid>_FA to highres"
    flirt -ref ${mprage_dir}/highres_brain.nii.gz \
            -in ${dti_dir}/FDT/${sub}_FA.nii.gz \
            -omat ${reg_dir}/diffFA_TO_highres.mat

else
    echo "    dti_ec_brain already flirted to highres"

fi

# Invert this flirt transform
if [[ ! -f ${reg_dir}/diffFA_TO_highres.mat ]]; then
    echo "    ERROR: Can't invert transform as flirt has not been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${reg_dir}/highres_TO_diffFA.mat ]]; then
    echo "    Inverting flirt transform"
    convert_xfm -omat ${reg_dir}/highres_TO_diffFA.mat \
                -inverse ${reg_dir}/diffFA_TO_highres.mat

else
    echo "    Inverse flirt transform already calculated"

fi

#------------------------------------------------------------------------------
# Register highres to MNI152 standard space
# Save these in both the mprage_dir and the reg_dir so that you don't have
# to re-run them if you're dealing with multiple dti directories
# (This is for Kirstie's original use of comparing various dti acquisitions!)

# Flirt first
if [[ ! -f ${mprage_dir}/highres_TO_MNI152.mat ]]; then
    echo "    Flirting highres to MNI"
    flirt -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
            -in ${mprage_dir}/highres_brain.nii.gz \
            -omat ${mprage_dir}/highres_TO_MNI152.mat
    cp ${mprage_dir}/highres_TO_MNI152.mat ${reg_dir}/highres_TO_MNI152.mat

else
    echo "    Highres already flirted to MNI"

fi

# Invert this flirt transform
if [[ ! -f ${reg_dir}/highres_TO_MNI152.mat ]]; then
    echo "    ERROR: Can't invert transform as flirt has not been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${mprage_dir}/MNI152_TO_highres.mat ]]; then
    echo "    Inverting flirt transform"
    convert_xfm -omat ${mprage_dir}/MNI152_TO_highres.mat \
                -inverse ${mprage_dir}/highres_TO_MNI152.mat
    cp ${mprage_dir}/MNI152_TO_highres.mat ${reg_dir}/MNI152_TO_highres.mat

else
    echo "    Inverse flirt transform already calculated"

fi

# Then fnirt highres to MNI152
if [[ ! -f ${reg_dir}/highres_TO_MNI152_nlwarp.nii.gz ]]; then
    echo "    Fnirting highres to MNI"
    fnirt --in=${mprage_dir}/highres.nii.gz \
            --aff=${mprage_dir}/highres_TO_MNI152.mat \
            --cout=${mprage_dir}/highres_TO_MNI152_nlwarp \
            --config=T1_2_MNI152_2mm

    cp ${mprage_dir}/highres_TO_MNI152_nlwarp.nii.gz \
        ${reg_dir}/highres_TO_MNI152_nlwarp.nii.gz

else
    echo "    Highres already fnirted to MNI"

fi

# And inverse this warp
if [[ ! -f ${reg_dir}/highres_TO_MNI152_nlwarp.nii.gz ]]; then
    echo "    ERROR: Can't run registration because fnirt has not been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${reg_dir}/MNI152_TO_highres_nlwarp.nii.gz ]]; then
    echo "    Inverting highres to MNI warp"
    invwarp --ref=${mprage_dir}/highres.nii.gz \
            --warp=${mprage_dir}/highres_TO_MNI152_nlwarp.nii.gz \
            --out=${mprage_dir}/MNI152_TO_highres_nlwarp.nii.gz

    cp ${mprage_dir}/MNI152_TO_highres_nlwarp.nii.gz \
        ${reg_dir}/MNI152_TO_highres_nlwarp.nii.gz

else
    echo "    Inverse fnirt warp already calculated"

fi

#------------------------------------------------------------------------------
# Register highres to freesurfer space

if [[ ! -f ${reg_dir}/freesurfer_TO_highres.mat ]]; then
    echo "    Registering highres to freesurfer space"

    tkregister2 --mov ${surf_dir}/mri/orig.mgz \
                --targ ${surf_dir}/mri/rawavg.mgz \
                --regheader \
                --reg junk \
                --fslregout ${mprage_dir}/freesurfer_TO_highres.mat \
                --noedit 

    cp ${mprage_dir}/freesurfer_TO_highres.mat \
        ${reg_dir}/freesurfer_TO_highres.mat

else
    echo "    Highres already registered to freesurfer space"

fi

if  [[ ! -f ${reg_dir}/freesurfer_TO_highres.mat ]]; then
    echo "    ERROR: Can't run registration because tkregister2 hasn't been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${reg_dir}/highres_TO_freesurfer.mat ]]; then
    echo "    Inverting freesurfer to highres transform"
    
    convert_xfm -omat ${mprage_dir}/highres_TO_freesurfer.mat \
                -inverse ${mprage_dir}/freesurfer_TO_highres.mat 

    cp ${mprage_dir}/highres_TO_freesurfer.mat \
        ${reg_dir}/highres_TO_freesurfer.mat

else
    echo "    Inverse freesurfer to highres transform already calculated"

fi


#------------------------------------------------------------------------------
# Concatenate the diffusion and highres registrations
if [[ ! -f ${reg_dir}/MNI152_TO_diffFA.mat ]]; then
    echo "    Concatenating and inverting remaining transforms"

    # diffB0 to freesurfer
    convert_xfm -omat ${reg_dir}/diffB0_TO_freesurfer.mat \
                -concat ${reg_dir}/diffB0_TO_highres.mat \
                        ${reg_dir}/highres_TO_freesurfer.mat 

    # freesurfer to diffB0
    convert_xfm -omat ${reg_dir}/freesurfer_TO_diffB0.mat \
                -inverse ${reg_dir}/diffB0_TO_freesurfer.mat

    # diffFA to freesurfer
    convert_xfm -omat ${reg_dir}/diffFA_TO_freesurfer.mat \
                -concat ${reg_dir}/diffFA_TO_highres.mat \
                        ${reg_dir}/highres_TO_freesurfer.mat 

    # freesurfer to diffFA
    convert_xfm -omat ${reg_dir}/freesurfer_TO_diffFA.mat \
                -inverse ${reg_dir}/diffFA_TO_freesurfer.mat

    # diffB0 to MNI152
    convert_xfm -omat ${reg_dir}/diffB0_TO_MNI152.mat \
                -concat ${reg_dir}/diffB0_TO_highres.mat \
                        ${reg_dir}/highres_TO_MNI152.mat 

    # MNI152 to diffB0
    convert_xfm -omat ${reg_dir}/MNI152_TO_diffB0.mat \
                -inverse ${reg_dir}/diffB0_TO_MNI152.mat

    # diffFA to MNI152
    convert_xfm -omat ${reg_dir}/diffFA_TO_MNI152.mat \
                -concat ${reg_dir}/diffFA_TO_highres.mat \
                        ${reg_dir}/highres_TO_MNI152.mat 

    # MNI152 to diffB0
    convert_xfm -omat ${reg_dir}/MNI152_TO_diffFA.mat \
                -inverse ${reg_dir}/diffFA_TO_MNI152.mat
            
else
    echo "    Remaining transforms already calculated"

fi


#------------------------------------------------------------------------------
# And you're done!
echo "--------------------------------"
#------------------------------------------------------------------------------