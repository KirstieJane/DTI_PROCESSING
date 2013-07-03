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
#                           eg: registrations.sh ${dti_dir} ${mprage_dir}
#                           eg: registrations.sh /home/kw401/MRIMPACT/ANALYSES/1106/t1/DTI /home/kw401/MRIMPACT/ANALYSES/1106/t1/MPRAGE
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
#             AUTHOR:  Kirstie Whitaker
#                          kw401@cam.ac.uk
#
#            CREATED:  19th February 2013
#==============================================================================

#------------------------------------------------------------------------------
# Define usage function
function usage {
    echo "USAGE:"
    echo "registrations.sh <dti_data_folder> <mprage_data_folder>"
    echo "    eg: registrations.sh \${dti_dir} \${mprage_dir}"
    echo "    eg: registrations.sh /home/kw401/MRIMPACT/ANALYSES/1106/t1/DTI /home/kw401/MRIMPACT/ANALYSES/1106/t1/MPRAGE"
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

# Print the usage if necessary
if [[ ${print_usage} == 1 ]]; then
    usage
fi

### Step 2: Check data
# Make sure dti_ec_brain.nii.gz, highres_brain.nii.gz
# orig.mgz files exist
if [[ ! -f ${dti_dir}/dti_ec_brain.nii.gz ]]; then
    echo "    No dti_ec_brain.nii.gz file"
    echo "    Check that dti_preprocessing.sh has finished"
    print_usage=1
fi

if [[ ! -f ${mprage_dir}/highres.nii.gz ]]; then
    echo "    No highres.nii.gz file"
    echo "    Check that mprage_processing.sh has finished"
    print_usage=1
fi

if [[ ! -f ${surf_dir}/mri/orig.mgz ]]; then
    echo "    No orig.mgz file"
    echo "    Check that mprage_processing.sh has finished"
    print_usage=1
fi

# Print the usage if necessary
if [[ ${print_usage} == 1 ]]; then
    usage
fi
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Get started
echo "DTI_DIR: ${dti_dir}"
echo "MPRAGE_DIR: ${mprage_dir}"

reg_dir=(`dirname ${dti_dir}`)
# Make the LOGS dir
logdir=${reg_dir}/LOGS
mkdir -p ${logdir}

#------------------------------------------------------------------------------
# Register diffusion 
#------------------------------------------------------------------------------
# Register to standard space
# First flirt highres to MNI152
if [[ ! -f ${mprage_dir}/highres_brain.nii.gz ]]; then
    echo "    ERROR: Can't run registration because brain extraction has not been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${mprage_dir}/highres_TO_MNI152.mat ]]; then
    echo "    Flirting highres to MNI"
    flirt -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
            -in ${mprage_dir}/highres_brain.nii.gz \
            -omat ${mprage_dir}/highres_TO_MNI152.mat

else
    echo "    Highres already flirted to MNI"

fi

# Invert this flirt transform
if [[ ! -f ${mprage_dir}/highres_TO_MNI152.nii.gz ]]; then
    echo "    ERROR: Can't invert transform as flirt has not been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${mprage_dir}/MNI152_TO_highres.mat ]]; then
    echo "    Inverting flirt transform"
    convert_xfm -omat ${mprage_dir}/MNI152_TO_highres.mat \
                -inverse ${mprage_dir}/highres_TO_MNI152.mat

else
    echo "    Inverse flirt transform already calculated"

# Then fnirt highres to MNI152
if [[ ! -f ${mprage_dir}/highres_TO_MNI152_nlwarp.nii.gz ]]; then
    echo "Fnirting highres to MNI"
    fnirt --in=${mprage_dir}/highres.nii.gz \
            --aff=${mprage_dir}/highres_TO_MNI152.mat \
            --cout=${mprage_dir}/highres_TO_MNI152_nlwarp \
            --config=T1_2_MNI152_2mm
else
    echo "    Highres already fnirted to MNI"

fi

# And inverse this warp
if [[ ! -f ${mprage_dir}/highres_TO_MNI152_nlwarp.nii.gz ]]; then
    echo "    ERROR: Can't run registration because fnirt has not been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${mprage_dir}/MNI152_TO_highres_nl.nii.gz ]]; then
    echo "Inverting highres to MNI warp"
    invwarp --ref=${mprage_dir}/highres.nii.gz \
            --warp=${mprage_dir}/highres_TO_MNI152_nl.nii.gz \
            --out=${mprage_dir}/MNI152_TO_highres_nl.nii.gz
else
    echo "    Inverse fnirt warp already calculated"

fi


# First flirt high_res to MNI152
if [[ ! -f ${mprage_dir}/high_res_TO_MNI152.mat ]]; then
    echo "Flirting high_res to MNI"
    flirt -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
            -in ${mprage_dir}/high_res_brain.nii.gz \
            -omat ${mprage_dir}/high_res_TO_MNI152.mat
fi

# Then fnirt high_res to MNI152
if [[ ! -f ${mprage_dir}/high_res_TO_MNI152_nl.nii.gz ]]; then
    echo "Fnirting high_res to MNI"
    fnirt --in=${mprage_dir}/high_res.nii.gz \
            --aff=${mprage_dir}/high_res_TO_MNI152.mat \
            --cout=${mprage_dir}/high_res_TO_MNI152_nl \
            --config=T1_2_MNI152_2mm
fi

# And inverse this warp
if [[ ! -f ${mprage_dir}/MNI152_TO_high_res_nl.nii.gz ]]; then
    echo "Inverting high_res to MNI warp"
    invwarp --ref=${mprage_dir}/high_res.nii.gz \
            --warp=${mprage_dir}/high_res_TO_MNI152_nl.nii.gz \
            --out=${mprage_dir}/MNI152_TO_high_res_nl.nii.gz
fi

#------------------------------------------------------------------------------
# Rotate bvecs

if [[ ! -f ${dir}/bvecs ]]; then
    echo "    Rotating bvecs"
    ${rot_bvecs_script} ${dir}/bvecs_orig ${dir}/bvecs \
        ${dir}/dti_ec.ecclog >> ${logdir}/eddycorrect
else
    echo "    Bvecs already rotated"
fi

#------------------------------------------------------------------------------
# Brain extract
if [[ ! -f ${dir}/dti_ec.nii.gz ]]; then
    echo "    ERROR: Can't brain extract because eddy_correct has not been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${dir}/dti_ec_brain.nii.gz ]]; then
    echo "    Brain extracting"
    bet ${dir}/dti_ec.nii.gz ${dir}/dti_ec_brain.nii.gz -f 0.15 -m > ${logdir}/bet

else
    echo "    Brain already extracted"
fi

#------------------------------------------------------------------------------
# DTIfit (FDT)
if [[ ! -f ${dir}/dti_ec_brain_mask.nii.gz || ! -f ${dir}/bvecs ]]; then
    echo "    ERROR: Can't fit tensor because brain extraction has not been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${dir}/bvecs ]]; then
    echo "    ERROR: Can't fit tensor because bvecs file doesn't exist"
    echo "    EXITING"
    exit

elif [[ ! -f ${dir}/FDT/${sub}_MO.nii.gz ]]; then
    echo "    Fitting tensor"
    mkdir -p ${dir}/FDT
    dtifit -k ${dir}/dti_ec.nii.gz \
        -m ${dir}/dti_ec_brain_mask.nii.gz \
        -r ${dir}/bvecs \
        -b ${dir}/bvals \
        -o ${dir}/FDT/${sub} \
        > ${logdir}/dtifit
    
    fslmaths ${dir}/FDT/${sub}_L2.nii.gz -add ${dir}/FDT/${sub}_L3.nii.gz -div 2 \
        ${dir}/FDT/${sub}_L23.nii.gz

else
   echo "    Tensor already fit"
fi

#------------------------------------------------------------------------------
# BedpostX
if [[ ! -f ${dir}/BEDPOSTX.bedpostX/dyads2.nii.gz ]]; then
    echo "    Now starting bedpostX"
    mkdir -p ${dir}/BEDPOSTX
    cp ${dir}/bvals ${dir}/BEDPOSTX/
    cp ${dir}/bvecs ${dir}/BEDPOSTX/
    cp ${dir}/dti_ec_brain_mask.nii.gz \
    ${dir}/BEDPOSTX/nodif_brain_mask.nii.gz
    cp ${dir}/dti_ec.nii.gz ${dir}/BEDPOSTX/data.nii.gz
    bedpostx ${dir}/BEDPOSTX/ > ${logdir}/bedpostx
else
    echo "    bedpostX already complete"
fi

#------------------------------------------------------------------------------
# TBSS 1 and 2
if [[ ! -f ${dir}/FDT/${sub}_FA.nii.gz ]]; then
    echo "    ERROR: Can't run TBSS as tensor has not been fit"
    echo "    EXITING"
    exit

elif [[ ! -f ${dir}/TBSS/FA/reverse_fnirt_warp.nii.gz ]]; then
    echo "    Now starting tbss"
    if [[ ! -f ${dir}/TBSS/FA/${sub}_FA_FA_to_target_warp.nii.gz ]]; then
        echo "    Running TBSS"
        rm -rf ${dir}/TBSS
        mkdir -p ${dir}/TBSS
        cp ${dir}/FDT/*FA* ${dir}/TBSS/
        cd ${dir}/TBSS/
        tbss_1_preproc * > ${logdir}/tbss
        tbss_2_reg -T >> ${logdir}/tbss
    fi
    # Now create the inverse fnirt warp
    echo "    Inverting FNIRT warp"
    if [[ -d ${dir}/TBSS/FA && \
           ! -f ${dir}/TBSS/FA/reverse_fnirt_warp.nii.gz ]]; then
        invwarp -r ${dir}/TBSS/FA/${sub}_FA_FA.nii.gz \
                -w ${dir}/TBSS/FA/${sub}_FA_FA_to_target_warp.nii.gz \
                -o ${dir}/TBSS/FA/reverse_fnirt_warp.nii.gz
    fi
else
    echo "    TBSS already complete"
fi

#------------------------------------------------------------------------------
# And you're done!
echo "--------------------------------"
#------------------------------------------------------------------------------