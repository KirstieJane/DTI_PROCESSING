#!/bin/bash

#==============================================================================
#               NAME:  registrations.sh
#
#        DESCRIPTION:  This script takes, as an input directory, the
#                      individual participant's DTI directory that was passed
#                      to dti_preprocessing.sh and the MPRAGE directory that
#                      was passed to mprage_processing.sh. It then creates a 
#                      REG directory at the same level as the MPRAGE directory
#                      
#                      If an eddy_b0 number is passed as an argument then
#                      the dti registrations will be in their own directories
#                      called B0_<eddy_b0 number>.
#
#                      The REG directory contains all the necessary
#                      transformations to get between the following spaces:
#                      DTI, FSL_highres, Freesurfer, MNI152.
#
#              USAGE:  registrations.sh <dti_data_folder> <mprage_data_folder> <dti_run> <eddy_b0_vol>
#                           eg: registrations.sh ${dti_dir} ${mprage_dir} ${scan} ${b0}
#                           eg: registrations.sh /home/kw401/MRIMPACT/ANALYSES/1106/t1/DTI /home/kw401/MRIMPACT/ANALYSES/1106/t1/MPRAGE DTI_2A 14
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
#        PARAMETER 3:  DTI run
#                           eg: ${scan}
#                           eg: DTI_2A
#
#        PARAMETER 4:  Eddy correct target volume
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
    echo "registrations.sh <dti_data_folder> <mprage_data_folder> <dti_scan> <eddy_b0_vol>"
    echo "    eg: registrations.sh \${dti_dir} \${mprage_dir} \${scan} \${b0}"
    echo "    eg: registrations.sh /home/kw401/MRIMPACT/ANALYSES/1106/t1/DTI /home/kw401/MRIMPACT/ANALYSES/1106/t1/MPRAGE DTI_2A 14"
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

scan=$3

eddy_b0_vol=$4
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
# Make sure dti_ec_brain.nii.gz, highres_brain.nii.gz,
# highres.nii.gz, rawavg.mgz and orig.mgz files exist
for dti_file in ${dti_dir}/dti_ec_brain.nii.gz; do
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
reg_dir=(`dirname ${mprage_dir}`/REG)

# Make the LOGS dir
logdir=${reg_dir}/LOGS
mkdir -p ${logdir}

#------------------------------------------------------------------------------
# Register diffusion images to highres space using standard flirt

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

# b0 weighted file
if [[ ! -f ${dti_reg_dir}/diffB0_TO_highres.mat ]]; then
    echo "    Flirting dti_ec_brain to highres"
    flirt -ref ${mprage_dir}/highres_brain.nii.gz \
            -in ${dti_dir}/dti_ec_brain.nii.gz \
            -omat ${dti_reg_dir}/diffB0_TO_highres.mat

else
    echo "    dti_ec_brain already flirted to highres"

fi

# Invert this flirt transform
if [[ ! -f ${dti_reg_dir}/diffB0_TO_highres.mat ]]; then
    echo "    ERROR: Can't invert transform as flirt has not been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${dti_reg_dir}/highres_TO_diffB0.mat ]]; then
    echo "    Inverting flirt transform"
    convert_xfm -omat ${dti_reg_dir}/highres_TO_diffB0.mat \
                -inverse ${dti_reg_dir}/diffB0_TO_highres.mat

else
    echo "    Inverse flirt transform already calculated"

fi

#------------------------------------------------------------------------------
# Register diffusion images to highres space using BBR

# b0 weighted file
if [[ ! -f ${dti_reg_dir}/diffB0_TO_highres_BBR.mat ]]; then
    echo "    Flirting dti_ec_brain to highres using BBR"
    epi_reg --epi=${dti_dir}/dti_ec_brain.nii.gz \
            --t1=${mprage_dir}/highres.nii.gz \
            --t1brain=${mprage_dir}/highres_brain.nii.gz \
            --out=${dti_reg_dir}/diffB0_TO_highres_BBR 
else
    echo "    dti_ec_brain already BBR flirted to highres"

fi

# Invert this flirt transform
if [[ ! -f ${dti_reg_dir}/diffB0_TO_highres_BBR.mat ]]; then
    echo "    ERROR: Can't invert transform as flirt with BBR has not been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${dti_reg_dir}/highres_TO_diffB0_BBR.mat ]]; then
    echo "    Inverting flirt via BBR transform"
    convert_xfm -omat ${dti_reg_dir}/highres_TO_diffB0_BBR.mat \
                -inverse ${dti_reg_dir}/diffB0_TO_highres_BBR.mat

else
    echo "    Inverse flirt via BBR transform already calculated"

fi

#------------------------------------------------------------------------------
# Register highres to MNI152 standard space

# Flirt first to 1mm space
if [[ ! -f ${reg_dir}/highres_TO_MNI152_1mm.mat ]]; then
    echo "    Flirting highres to MNI"
    flirt -ref ${FSLDIR}/data/standard/MNI152_T1_1mm_brain.nii.gz \
            -in ${mprage_dir}/highres_brain.nii.gz \
            -omat ${reg_dir}/highres_TO_MNI152_1mm.mat

else
    echo "    Highres already flirted to MNI"

fi

# Invert this flirt transform
if [[ ! -f ${reg_dir}/highres_TO_MNI152_1mm.mat ]]; then
    echo "    ERROR: Can't invert transform as flirt has not been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${reg_dir}/MNI152_1mm_TO_highres.mat ]]; then
    echo "    Inverting flirt transform"
    convert_xfm -omat ${reg_dir}/MNI152_1mm_TO_highres.mat \
                -inverse ${reg_dir}/highres_TO_MNI152_1mm.mat

else
    echo "    Inverse flirt transform already calculated"

fi

# Flirt first to 1mm space
if [[ ! -f ${reg_dir}/highres_TO_MNI152_2mm.mat ]]; then
    echo "    Flirting highres to MNI"
    flirt -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
            -in ${mprage_dir}/highres_brain.nii.gz \
            -omat ${reg_dir}/highres_TO_MNI152_2mm.mat

else
    echo "    Highres already flirted to MNI"

fi

# Invert this flirt transform
if [[ ! -f ${reg_dir}/highres_TO_MNI152_2mm.mat ]]; then
    echo "    ERROR: Can't invert transform as flirt has not been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${reg_dir}/MNI152_2mm_TO_highres.mat ]]; then
    echo "    Inverting flirt transform"
    convert_xfm -omat ${reg_dir}/MNI152_2mm_TO_highres.mat \
                -inverse ${reg_dir}/highres_TO_MNI152_2mm.mat

else
    echo "    Inverse flirt transform already calculated"

fi


# Then fnirt highres to MNI152
if [[ ! -f ${reg_dir}/highres_TO_MNI152_NL.nii.gz ]]; then
    echo "    Fnirting highres to MNI"
    fnirt --in=${mprage_dir}/highres.nii.gz \
            --aff=${reg_dir}/highres_TO_MNI152.mat \
            --cout=${reg_dir}/highres_TO_MNI152_NL \
            --config=T1_2_MNI152_2mm

else
    echo "    Highres already fnirted to MNI"

fi

# And inverse this warp
if [[ ! -f ${reg_dir}/highres_TO_MNI152_NL.nii.gz ]]; then
    echo "    ERROR: Can't run registration because fnirt has not been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${reg_dir}/MNI152_TO_highres_NL.nii.gz ]]; then
    echo "    Inverting highres to MNI warp"
    invwarp --ref=${mprage_dir}/highres.nii.gz \
            --warp=${reg_dir}/highres_TO_MNI152_NL.nii.gz \
            --out=${reg_dir}/MNI152_TO_highres_NL.nii.gz

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
                --fslregout ${reg_dir}/freesurfer_TO_highres.mat \
                --noedit 
                
else
    echo "    Highres already registered to freesurfer space"

fi

if  [[ ! -f ${reg_dir}/freesurfer_TO_highres.mat ]]; then
    echo "    ERROR: Can't run registration because tkregister2 hasn't been completed"
    echo "    EXITING"
    exit

elif [[ ! -f ${reg_dir}/highres_TO_freesurfer.mat ]]; then
    echo "    Inverting freesurfer to highres transform"
    
    convert_xfm -omat ${reg_dir}/highres_TO_freesurfer.mat \
                -inverse ${reg_dir}/freesurfer_TO_highres.mat 

else
    echo "    Inverse freesurfer to highres transform already calculated"

fi

#------------------------------------------------------------------------------
# Register the FA map directly to the FA MNI target
if [[ ! -f ${dti_reg_dir}/diffFA_TO_MNI152_direct_NL.nii.gz ]]; then
    echo "    Copying nonlinear warp from tbss_dir"
    
    warp_file=(`ls -d ${dti_dir}/TBSS/FA/*_FA_FA_to_target_warp.nii.gz 2>/dev/null`)
    
    if [[ ! -f ${warp_file} ]]; then
        echo "    ERROR: No warp file found in TBSS directory"
        echo "    EXITING"
    
    else
    
        echo "    Copying nonlinear warp from tbss_dir"
        
        cp ${warp_file} ${dti_reg_dir}/diffFA_TO_MNI152_direct_NL.nii.gz
    
    fi

else

    echo "    Nonlinear warp already copied over"
    
fi

if [[ ! -f ${dti_reg_dir}/MNI152_TO_diffFA_direct_NL.nii.gz ]]; then
    echo "    Copying nonlinear warp from tbss_dir"
    
    inv_warp_file=(`ls -d ${dti_dir}/TBSS/FA/reverse_fnirt_warp.nii.gz 2>/dev/null`)
    
    if [[ ! -f ${inv_warp_file} ]]; then
        echo "    ERROR: No warp file found in TBSS directory"
        echo "    EXITING"
    
    else
    
        echo "    Copying nonlinear warp from tbss_dir"
        
        cp ${inv_warp_file} ${dti_reg_dir}/MNI152_TO_diffFA_direct_NL.nii.gz
    
    fi

else

    echo "    Nonlinear inverse warp already copied over"
    
fi  

#------------------------------------------------------------------------------
# Concatenate the linear diffusion and highres registrations
if [[ ! -f ${dti_reg_dir}/MNI152_TO_diffB0_BBR.mat || ! -f ${dti_reg_dir}/MNI152_TO_diffB0.mat ]]; then
    echo "    Concatenating and inverting remaining transforms"

    # diffB0 to freesurfer
    convert_xfm -omat ${dti_reg_dir}/diffB0_TO_freesurfer.mat \
                -concat ${dti_reg_dir}/diffB0_TO_highres.mat \
                        ${reg_dir}/highres_TO_freesurfer.mat 

    # freesurfer to diffB0
    convert_xfm -omat ${dti_reg_dir}/freesurfer_TO_diffB0.mat \
                -inverse ${dti_reg_dir}/diffB0_TO_freesurfer.mat

    # diffB0 BBR to freesurfer
    convert_xfm -omat ${dti_reg_dir}/diffB0_TO_freesurfer_BBR.mat \
                -concat ${dti_reg_dir}/diffB0_TO_highres_BBR.mat \
                        ${reg_dir}/highres_TO_freesurfer.mat 

    # freesurfer to diffB0 BBR
    convert_xfm -omat ${dti_reg_dir}/freesurfer_TO_diffB0_BBR.mat \
                -inverse ${dti_reg_dir}/diffB0_TO_freesurfer_BBR.mat

    # diffB0 to MNI152
    convert_xfm -omat ${dti_reg_dir}/diffB0_TO_MNI152_1mm.mat \
                -concat ${dti_reg_dir}/diffB0_TO_highres.mat \
                        ${reg_dir}/highres_TO_MNI152_1mm.mat 

    convert_xfm -omat ${dti_reg_dir}/diffB0_TO_MNI152_2mm.mat \
                -concat ${dti_reg_dir}/diffB0_TO_highres.mat \
                        ${reg_dir}/highres_TO_MNI152_2mm.mat 

    # MNI152 to diffB0
    convert_xfm -omat ${dti_reg_dir}/MNI152_1mm_TO_diffB0.mat \
                -inverse ${dti_reg_dir}/diffB0_TO_MNI152_1mm.mat

    convert_xfm -omat ${dti_reg_dir}/MNI152_2mm_TO_diffB0.mat \
                -inverse ${dti_reg_dir}/diffB0_TO_MNI152_2mm.mat


    # diffB0 to MNI152 BBR
    convert_xfm -omat ${dti_reg_dir}/diffB0_TO_MNI152_1mm_BBR.mat \
                -concat ${dti_reg_dir}/diffB0_TO_highres_BBR.mat \
                        ${reg_dir}/highres_TO_MNI152_1mm.mat 
                        
    convert_xfm -omat ${dti_reg_dir}/diffB0_TO_MNI152_2mm_BBR.mat \
                -concat ${dti_reg_dir}/diffB0_TO_highres_BBR.mat \
                        ${reg_dir}/highres_TO_MNI152_2mm.mat 

    # MNI152 to diffB0 BBR
    convert_xfm -omat ${dti_reg_dir}/MNI152_1mm_TO_diffB0_BBR.mat \
                -inverse ${dti_reg_dir}/diffB0_TO_MNI152_1mm_BBR.mat

    convert_xfm -omat ${dti_reg_dir}/MNI152_2mm_TO_diffB0_BBR.mat \
                -inverse ${dti_reg_dir}/diffB0_TO_MNI152_2mm_BBR.mat
                
else
    echo "    Remaining transforms already calculated"

fi


#------------------------------------------------------------------------------
# And you're done!
echo "--------------------------------"
#------------------------------------------------------------------------------