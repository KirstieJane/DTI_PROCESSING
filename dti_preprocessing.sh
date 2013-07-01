#!/bin/bash

#==============================================================================
#               NAME:  dti_preprocessing
#
#        DESCRIPTION:  This script takes an input directory that must contain
#                      dti.nii.gz, bvals and bvecs_orig, and then runs  
#                      eddy current correction, rotate bvecs, brain extraction,
#                      dtifit, bedpostX and tbss 1 and 2
#
#        PARAMETER 1:  DTI data folder (full path)
#                           If you're using this script as part of another
#                               eg: ${dti_dir}
#                           If you're using this script alone
#                               eg: /home/kw401/MRIMPACT/005/t1/DTI/
#
#        PARAMETER 2:  sub_id
#                           eg: ${subid}
#                           eg: 005
#
#              USAGE:  dti_preprocessing <dti_data_folder> <sub_id>
#                           eg: dti_preprocessing ${dti_dir} ${sub_id}
#                           eg: dti_preprocessing /home/kw401/MRIMPACT/005/t1/DTI 005
#
#             AUTHOR:  Kirstie Whitaker
#                          kw401@cam.ac.uk
#
#            CREATED:  19th February 2013
#==============================================================================

#------------------------------------------------------------------------------
# Define usage function
function usage {
    echo "dti_preprocessing <dti_data_folder> <sub_id>"
    echo "    eg: dti_preprocessing ${dti_dir} ${sub_id}"
    echo "    eg: dti_preprocessing /home/kw401/MRIMPACT/005/t1/DTI 005"
    exit
}
#------------------------------------------------------------------------------
 
#------------------------------------------------------------------------------
# Assign arguments
dir=$1
sub=$2
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Check inputs

### Step 1: check arguements
# Exit if dti directory doesn't exist
if [[ ! -d ${dir} ]]; then
    echo "    No DTI directory"
    print_usage=1
fi

# Exit if subID is an empty string
if [[ -n "${sub}" ]]; then
    echo "    SubID is blank"
    print_usage=1
fi

# Print the usage if necessary
if [[ ${print_usage} == 1 ]]; then
    usage
fi

### Step 2: Check data
# Make sure dti.nii.gz, bvals and bvecs_orig files exist
if [[ ! -f ${dir}/dti.nii.gz ]]; then
    echo "    No dti.nii.gz file"
    print_usage=1
fi
if [[ ! -f ${dir}/bvals ]]; then
    echo "    No bvals file"
    print_usage=1
fi
if [[ ! -f ${dir}/bvecs_orig ]]; then
    echo "    No bvecs_orig file"
    print_usage=1
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
# Eddy correct to the first volume
if [[ ! -f ${dir}/dti_ec.nii.gz ]]; then
    echo "    Starting eddy correction step"
    rm -f ${dir}/dti_ec.ecclog
    eddy_correct ${dir}/dti.nii.gz ${dir}/dti_ec.nii.gz 0 > ${logdir}/eddycorrect
else
    echo "    Eddy correction step already completed"
fi

#------------------------------------------------------------------------------
# Rotate bvecs
# NOTE - the path to this script is hard coded
rot_bvecs_script=(/home/kw401/CAMBRIDGE_SCRIPTS/FSL_SCRIPTS/fdt_rotate_bvecs.sh)

if [[ ! -f ${dir}/bvecs ]]; then
    echo "    Rotating bvecs"
    ${rot_bvecs_script} ${dir}/bvecs_orig ${dir}/bvecs \
        ${dir}/dti_ec.ecclog >> ${logdir}/eddycorrect
else
    echo "    Bvecs already rotated"
fi

#------------------------------------------------------------------------------
# Brain extract
if [[ ! -f ${dir}/dti_ec_brain.nii.gz ]]; then
    echo "    Brain extracting"
    bet ${dir}/dti_ec.nii.gz ${dir}/dti_ec_brain.nii.gz -f 0.15 -m > ${logdir}/bet
else
    echo "    Brain already extracted"
fi

#------------------------------------------------------------------------------
# DTIfit (FDT)
if [[ ! -f ${dir}/FDT/${sub}_MO.nii.gz ]]; then
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
if [[ ! -f ${dir}/TBSS/FA/reverse_fnirt_warp.nii.gz ]]; then
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