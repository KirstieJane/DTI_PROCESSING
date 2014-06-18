#!/bin/bash

# RunTopup.sh <run1_dir> <run2_dir> <combo_dir>

# Read in your arguments
run1_dir=$1
run2_dir=$2
combo_dir=$3

# Make the combo directory
mkdir -p ${combo_dir}

#extract the b0 from DTI_Run 1 (in my case this was volume 0 hence use 0 1 for the parameters for fslroi"
i=1
for dir in ${run1_dir} ${run2_dir}; do
    if [[ ! -f ${combo_dir}/dti_ec_b0_${i}.nii.gz ]]; then
        echo "\tExtracting b0 from run ${i}"
        fslroi ${dir}/dti_ec.nii.gz ${combo_dir}/dti_ec_b0_${i}.nii.gz
    fi
    let i=${i}+1
done

if [[ ! -f ${combo_dir}/dti_ec_b0_comb.nii.gz ]]; then
    echo "\tMerging b0s"
    fslmerge -t ${combo_dir}/dti_ec_b0_comb.nii.gz `ls -d ${combo_dir}/dti_ec_b0_?.nii.gz`

else 
    echo "\tDti_ec_b0_comb already made"
fi

#-------------------------------------------
#run topup and applytopup 

if [[ ! -f ${combo_dir}/topup_result_APPA_fieldcoef.nii.gz ]]; then
    echo "\tRunning topup"
    topup --imain=${combo_dir}/dti_ec_b0_comb.nii.gz \
            --datain=${run1_dir}/acq_params.txt \
            --config=b02b0.cnf \
            --out=${combo_dir}/topup_result
    echo "\tTopup complete"
else
    echo "\tTopup already complete"
fi

if [[ ! -f ${dir}/apply_topup_result.nii.gz ]]; then
    echo "\tRunning applytopup"
    applytopup --imain=${run1_dir}/dti_ec.nii.gz,${run2_dir}/dti_ec.nii.gz \
                --inindex=1,2 \
                --datain=${run1_dir}/acq_params.txt \
                --topup=${combo_dir}/topup_result \
                --method=jac \
                --out=${combo_dir}/dti_ec
                
    echo "\tApplytopup complete"
else
    echo "\tApplytopup already complete"
fi
#-------------------------------------------