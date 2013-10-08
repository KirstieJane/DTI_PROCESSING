#!/bin/bash

#==============================================================================
#               NAME:  roistats.sh
#
#        DESCRIPTION:  This script takes, as an input directory, the
#                      individual participant's DTI directory that was passed
#                      to dti_preprocessing.sh and the REG directory that
#                      was created during registrations.sh, along with an roi
#                      file. It then extracts a plethora of information about
#                      the values inside the ROI from each of the FDT files.
#
#              USAGE:  roistats.sh <rois_dir> <dti_data_folder> <reg_folder> <dti_run> <eddy_b0_vol> 
#                           eg: registrations.sh ${rois_dir} ${dti_dir} ${mprage_dir} ${scan} ${b0}
#                           eg: registrations.sh ROIS 1106/t1/DTI 1106/t1/MPRAGE DTI_2A 14
#
#        PARAMETER 1:  ROIS  folder (full path)
#                           If you're using this script as part of another
#                               eg: ${rois_dir}
#                           If you're using this script alone
#                               eg: /home/kw401/MRIMPACT/ANALYSES/ROIS/
#
#        PARAMETER 2:  DTI data folder (full path)
#                           If you're using this script as part of another
#                               eg: ${dti_dir}
#                           If you're using this script alone
#                               eg: /home/kw401/MRIMPACT/ANALYSES/1106/t1/DTI 
#
#        PARAMETER 3:  MPRAGE data folder (full path)
#                           If you're using this script as part of another
#                               eg: ${mprage_dir}
#                           If you're using this script alone
#                               eg: /home/kw401/MRIMPACT/ANALYSES/1106/t1/MPRAGE
#
#        PARAMETER 4:  DTI run
#                           eg: ${scan}
#                           eg: DTI_2A
#
#        PARAMETER 5:  Eddy correct target volume
#                           eg: ${b0}
#                           eg: 14
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
    echo "registrations.sh <rois_folder> <dti_data_folder> <mprage_data_folder> <dti_scan> <eddy_b0_vol>"
    echo "    eg: registrations.sh \${rois_dir} \${dti_dir} \${mprage_dir} \${scan} \${b0}"
    echo "    eg: registrations.sh ROIS 1106/t1/DTI 1106/t1/MPRAGE DTI_2A 14"
    exit
}
#------------------------------------------------------------------------------
 
#------------------------------------------------------------------------------
# Assign arguments
rois_dir=$1
if [[ ! -d ${rois_dir} ]]; then
    dir=`pwd`/${rois_dir}
fi

dti_dir=$2
if [[ ! -d /${dti_dir} ]]; then
    dir=`pwd`/${dti_dir}
fi

reg_dir=$3
if [[ ! -d /${reg_dir} ]]; then
    dir=`pwd`/${reg_dir}
fi

scan=$4

eddy_b0_vol=$5

#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Check inputs

### Step 1: check arguments
# Exit if dti directory doesn't exist
if [[ ! -d ${dti_dir} ]]; then
    echo "    No DTI directory"
    print_usage=1
fi

# Exit if reg directory doesn't exist
if [[ ! -d ${reg_dir} ]]; then
    echo "    No REG directory"
    print_usage=1
fi

# Print the usage if necessary
if [[ ${print_usage} == 1 ]]; then
    usage
fi

#------------------------------------------------------------------------------

if [[ ! -z ${scan} ]]; then
    dti_reg_dir=${reg_dir}/${scan}
    mkdir -p ${dti_reg_dir}
else
    dti_reg_dir=${reg_dir}
fi

if [[ ! -z ${eddy_b0_vol} ]]; then
    dti_reg_dir=${dti_reg_dir}/B0_${eddy_b0_vol}
    mkdir -p ${dti_reg_dir}
fi

fdt_dir=${dti_dir}/FDT

masks_dir=${reg_dir/REG/MASKS}
dti_masks_dir=${dti_reg_dir/REG/MASKS}

mkdir -p ${masks_dir}
mkdir -p ${dti_masks_dir}

#------------------------------------------------------------------------------

# First thing is to transform the ROI into the correct space

for roi_file in `ls -d ${rois_dir}/*nii.gz`; do
    
    roi_name=`basename ${roi_file} .nii.gz`
    
    # MNI to DIFF directly via nonlinear FA matching
    if [[ -f ${dti_masks_dir}/MNI_DIFF_FA_DIRECT/ROI_${roi_name}.nii.gz \
            && -f ${dti_reg_dir}/MNI_TO_diffFA_direct_NL.nii.gz ]]; then

        mkdir -p ${dti_masks_dir}/MNI_DIFF_FA_DIRECT
        
        applywarp --ref=${dti_dir}/${sub}_FA.nii.gz \
            --in=${roi_file} \
            --warp=${dti_reg_dir}/MNI_TO_diffFA_direct_NL.nii.gz \
            --out=${dti_masks_dir}/MNI_DIFF_FA_DIRECT/ROI_${roi_name}.nii.gz \
            --interp=nn 

    fi
    
    # MNI to DIFF via highres nonlinear and BBR
    if [[ -f ${masks_dir}/MNI_DIFF_VIA_HIGHRES_NL_BBR/ROI_${roi_name}.nii.gz \
            && -f ${dti_reg_dir}/highres_TO_diffB0_BBR.mat \
            && -f ${reg_dir}/MNI152_TO_highres_nlwarp.nii.gz ]]; then
        
        mkdir -p ${dti_masks_dir}/MNI_DIFF_VIA_HIGHRES_NL_BBR
        
        applywarp --ref=${dti_dir}/${sub}_FA.nii.gz \
            --in=${roi_file} \
            --warp=${reg_dir}/MNI_TO_highres_nlwarp.nii.gz \
            --postmat=${dti_reg_dir}/highres_TO_diffB0_BBR.mat \
            --out=${dti_masks_dir}/MNI_DIFF_VIA_HIGHRES_NL_BBR/ROI_${roi_name}.nii.gz \
            --interp=nn 

    fi
    
    # MNI to DIFF via highres linear
    if [[ -f ${masks_dir}/MNI_DIFF_VIA_HIGHRES_LIN/ROI_${roi_name}.nii.gz \
            && -f ${dti_reg_dir}/MNI152_TO_diffB0.mat ]]; then
        
        mkdir -p ${dti_masks_dir}/MNI_DIFF_VIA_HIGHRES_LIN
        
        flirt -in ${roi_file} \
                -ref ${dti_dir}/${sub}_FA.nii.gz \
                -applyxfm \
                -init ${dti_reg_dir}/MNI152_TO_diffB0.mat \
                -out ${dti_masks_dir}/MNI_DIFF_VIA_HIGHRES_LIN/ROI_${roi_name}.nii.gz \
                -interp nearestneighbour

    fi
    
done

#------------------------------------------------------------------------------
# And you're done!
echo "--------------------------------"
#------------------------------------------------------------------------------