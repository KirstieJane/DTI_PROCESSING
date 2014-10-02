#!/bin/bash

#==============================================================================
# Extract DTI and MPM measures from freesurfer ROIs
# along with surface parameters from various parcellations
# Created by Kirstie Whitaker
# Contact kw401@cam.ac.uk
#==============================================================================

#==============================================================================
# Define the usage function
#==============================================================================

function usage {

    echo "USAGE: freesurfer_extract_rois.sh <data_dir> <subid>"
    echo "Note that data dir expects to find SUB_DATA within it"
    echo "and then the standard NSPN directory structure"
    echo ""
    echo "DESCRIPTION: This code will register the DTI B0 file to freesurfer space,"
    echo "apply this registration to the DTI measures in the <dti_dir>/FDT folder,"
    echo "transform the MPM files to freesurfer space," 
    echo "and then create the appropriate <measure>_wmparc.stats and "
    echo "<measure>_aseg.stats files for each subject separately"
    echo "Finally, it will also extract surface stats from the parcellation schemes"
    exit
}

#=============================================================================
# CHECK INPUTS
#=============================================================================
data_dir=$1
sub=$2

# This needs to be in the same directory as this script
# Fine if you download the git repository but not fine 
# if you've only take the script itself!
lobes_ctab=`dirname ${0}`/LobesStrictLUT.txt
parc500_ctab=`dirname ${0}`/parc500LUT.txt

if [[ ! -d ${data_dir} ]]; then
    echo "${data_dir} is not a directory, please check"
    print_usage=1
fi

if [[ -z ${sub} ]]; then
    echo "No subject id provided"
    print_usage=1
fi

if [[ ! -f ${lobes_ctab} ]]; then
    echo "Can't find lobes color look up table file"
    echo "Check that LobesStrictLUT.txt is in the same directory"
    echo "as this script"
    print_usage=1
fi

if [[ ${print_usage} == 1 ]]; then 
    usage
fi

#=============================================================================
# START A LOOP OVER TIMEPOINTS
#=============================================================================

for occ in 0; do

#=============================================================================
# SET A COUPLE OF USEFUL VARIABLES
#=============================================================================
    surfer_dir=${data_dir}/SUB_DATA/${sub}/SURFER/MRI${occ}/
    dti_dir=${data_dir}/SUB_DATA/${sub}/DTI/MRI${occ}/
    reg_dir=${data_dir}/SUB_DATA/${sub}/REG/MRI${occ}/
    mpm_dir=${data_dir}/SUB_DATA/${sub}/MPM/MRI${occ}/

    SUBJECTS_DIR=${surfer_dir}/../
    surf_sub=`basename ${surfer_dir}`

#=============================================================================
# REGISTER B0 TO FREESURFER SPACE
#=============================================================================
    # The first step is ensuring that the dti_ec (B0) file
    # has been registered to freesurfer space
    if [[ ! -f ${reg_dir}/diffB0_TO_surf.dat ]]; then
        bbregister --s ${surf_sub} \
                   --mov ${dti_dir}/dti_ec.nii.gz \
                   --init-fsl \
                   --reg ${reg_dir}/diffB0_TO_surf.dat \
                   --t2
    fi

#=============================================================================
# TRANSFORM DTI MEASURES FILES TO FREESURFER SPACE
#=============================================================================
    # If the dti measure file doesn't exist yet in the <surfer_dir>/mri folder
    # then you have to make it
    for measure in FA MD MO L1 L23 sse; do
    
        measure_file_dti=`ls -d ${dti_dir}/FDT/*_${measure}.nii.gz 2> /dev/null`
        if [[ ! -f ${measure_file_dti} ]]; then 
            echo "${measure} file doesn't exist in dti_dir, please check"
            usage
        fi
        
        # If the measure file has particularly small values
        # then multiply this file by 1000 first
        if [[ "MD L1 L23" =~ ${measure} ]]; then
            if [[ ! -f ${measure_file_dti/.nii/_mul1000.nii} ]]; then
                fslmaths ${measure_file_dti} -mul 1000 ${measure_file_dti/.nii/_mul1000.nii}
            fi
            measure_file_dti=${measure_file_dti/.nii/_mul1000.nii}
        fi
        
        # Now transform this file to freesurfer space
        if [[ ! -f ${surfer_dir}/mri/${measure}.mgz ]]; then
            
            echo "    Registering ${measure} file to freesurfer space"
            mri_vol2vol --mov ${measure_file_dti} \
                        --targ ${surfer_dir}/mri/T1.mgz \
                        --o ${surfer_dir}/mri/${measure}.mgz \
                        --reg ${reg_dir}/diffB0_TO_surf.dat \
                        --no-save-reg

        else
            echo "    ${measure} file already in freesurfer space"
           
        fi
    done

#=============================================================================
# TRANSFORM MPM MEASURES FILES TO FREESURFER SPACE
#=============================================================================
    # If the mpm measure file doesn't exist yet in the <surfer_dir>/mri folder
    # then you have to make it

    # Loop through the mpm outputs that you're interested in
    for mpm in R1 MT R2s A; do
        mpm_file=`ls -d ${mpm_dir}/${mpm}_head.nii.gz 2> /dev/null`

        # If the measure file has particularly small values
        # then multiply this file by 1000 first
        if [[ ${mpm} == "R2s" ]]; then
            if [[ ! -f ${mpm_file/.nii/_mul1000.nii} ]]; then
                fslmaths ${mpm_file} -mul 1000 ${mpm_file/.nii/_mul1000.nii}
            fi
            mpm_file=${mpm_file/.nii/_mul1000.nii}
        fi
        
        if [[ ! -f ${surfer_dir}/mri/${mpm}.mgz ]]; then
            # Align the mgz file to "freesurfer" anatomical space
            mri_vol2vol --mov ${mpm_file} \
                        --targ ${surfer_dir}/mri/T1.mgz \
                        --regheader \
                        --o ${surfer_dir}/mri/${mpm}.mgz \
                        --no-save-reg
        fi
    done
        
#=============================================================================
# EXTRACT THE STATS FROM THE SEGMENTATION FILES
#=============================================================================
# Specifically this will loop through the following segmentations:
#     wmparc
#     aseg
#     lobesStrict
#     500.aparc_cortical_consecutive
#     500.aparc_cortical_expanded_consecutive_WMoverlap
#=============================================================================
  
    for measure in R1 MT R2s A FA MD MO L1 L23 sse; do
        if [[ -f ${surfer_dir}/mri/${measure}.mgz ]]; then

            #=== wmparc
            if [[ ! -f ${surfer_dir}/stats/${measure}_wmparc.stats ]]; then
                mri_segstats --i ${surfer_dir}/mri/${measure}.mgz \
                             --seg ${surfer_dir}/mri/wmparc.mgz \
                             --ctab ${FREESURFER_HOME}/WMParcStatsLUT.txt \
                             --sum ${surfer_dir}/stats/${measure}_wmparc.stats \
                             --pv ${surfer_dir}/mri/norm.mgz
            fi
            
            #=== aseg
            if [[ ! -f ${surfer_dir}/stats/${measure}_aseg.stats ]]; then
                mri_segstats --i ${surfer_dir}/mri/${measure}.mgz \
                             --seg ${surfer_dir}/mri/aseg.mgz \
                             --sum ${surfer_dir}/stats/${measure}_aseg.stats \
                             --pv ${surfer_dir}/mri/norm.mgz \
                             --ctab ${FREESURFER_HOME}/ASegStatsLUT.txt 
            fi
            
            #=== lobesStrict
            if [[ ! -f ${surfer_dir}/stats/${measure}_lobesStrict.stats ]]; then
                mri_segstats --i ${surfer_dir}/mri/${measure}.mgz \
                             --seg ${surfer_dir}/mri/lobes+aseg.mgz \
                             --sum ${surfer_dir}/stats/${measure}_lobesStrict.stats \
                             --pv ${surfer_dir}/mri/norm.mgz \
                             --ctab ${lobes_ctab}
            
            fi
            
            #=== 500.aparc_cortical_consecutive.nii.gz
            # Extract measures from the cortical regions in the 500 parcellation
#            if [[ ! -f ${surfer_dir}/stats/${measure}_500cortConsec.stats 
#                    && -f ${surfer_dir}/parcellation/500.aparc_cortical_consecutive.nii.gz ]]; then
                mri_segstats --i ${surfer_dir}/mri/${measure}.mgz \
                             --seg ${surfer_dir}/parcellation/500.aparc_cortical_consecutive.nii.gz  \
                             --sum ${surfer_dir}/stats/${measure}_500cortConsec.stats \
                             --pv ${surfer_dir}/mri/norm.mgz \
                             --ctab ${parc500_ctab}
#            fi
            
            #=== 500.aparc_cortical_expanded_consecutive_WMoverlap
            # Only run this if there is a 500 cortical parcellation
#            if [[ ! -f ${surfer_dir}/stats/${measure}_500cortExpConsecWMoverlap.stats \
#                    && -f ${surfer_dir}/parcellation/500.aparc_cortical_expanded_consecutive.nii.gz ]]; then
                
                # Create the overlap file if it doesn't already exist
                if [[ ! -f ${surfer_dir}/parcellation/500.aparc_cortical_expanded_consecutive_WMoverlap.nii.gz ]]; then
                
                    fslmaths ${surfer_dir}/parcellation/500.aparc_whiteMatter.nii.gz \
                                -bin \
                                -mul ${surfer_dir}/parcellation/500.aparc_cortical_expanded_consecutive.nii.gz \
                                ${surfer_dir}/parcellation/500.aparc_cortical_expanded_consecutive_WMoverlap.nii.gz
                fi
                
                mri_segstats --i ${surfer_dir}/mri/${measure}.mgz \
                             --seg ${surfer_dir}/parcellation/500.aparc_cortical_expanded_consecutive_WMoverlap.nii.gz \
                             --sum ${surfer_dir}/stats/${measure}_500cortExpConsecWMoverlap.stats \
                             --pv ${surfer_dir}/mri/norm.mgz \
                             --ctab ${parc500_ctab}


#            fi
            
        else
            echo "${measure} file not transformed to Freesurfer space"
        fi
    done
    
#=============================================================================
# EXTRACT THE STATS FROM THE SURFACE PARCELLATION FILES
#=============================================================================
# Specifically this will loop through the following segmentations:
#     aparc
#     500.aparc
#     lobesStrict
#=============================================================================

    # Loop over both left and right hemispheres
    for hemi in lh rh; do
        # Loop over parcellations
        for parc in aparc 500.aparc lobesStrict; do

            if [[ ! -f ${surfer_dir}/stats/${hemi}.${parc}.stats \
                    && -f ${surfer_dir}/label/${hemi}.${parc}.annot ]]; then
                mris_anatomical_stats -a ${surfer_dir}/label/${hemi}.${parc}.annot \
                                        -f ${surfer_dir}/stats/${hemi}.${parc}.stats \
                                        ${surf_sub} \
                                        ${hemi}
            fi
            
        done # Close parcellation loop
    done # Close hemi loop

#=============================================================================
# CLOSE THE OCC LOOP
#=============================================================================
done

#=============================================================================
# Well done. You're all finished :)
#=============================================================================
