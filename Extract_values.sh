#!/bin/bash

tbss_dir=$1
sublist=$2

# Define some variables
results_dir=${tbss_dir}/RESULTS/
pre_proc_dir=${tbss_dir}/PRE_PROCESSING/stats

subs=(`cat ${sublist}`)
output_file=${results_dir}/roi_values.txt


# Write the sub numbers on the first line
echo -e "SubNumber " > ${output_file}

# Now write all the subids into a line
# There's this stupid hack for mrimpact data because the
# subids are stupid
if [[ ${results_dir} == *mrimpact* ]]; then

    for sub in ${subs[@]}; do
        echo -n "${sub:0:4} " >> ${output_file}
    done

else
    for sub in ${subs[@]}; do
        echo -n "${sub} " >> ${output_file}
    done

fi

# Now loop through all the significant results
# and write them to the output file
for group_dir in `ls -d ${results_dir}/*`; do
    group_name=`basename ${group_dir}`
    
    for test_dir in `ls -d ${group_dir}/*`; do
        test_name=`basename ${test_dir}`
        
        if [[ `ls -d ${test_dir}/*FILL* 2>/dev/null | wc -l` -gt 0 ]]; then
            echo ${group_name}
            echo ${test_name}
            
            for fill_file in `ls -d ${test_dir}/*FILL_bin.nii.gz`; do
                fill_file_name=`basename ${fill_file}`
                not_fill_file=${fill_file%_FILL_bin.nii.gz}.nii.gz
                
                for measure in FA MD L1 L23 MO; do
                    direction=${not_fill_file:(-8):1}
                    test_measure=${fill_file_name%_500*}
                    
                    echo "    ${test_measure} ${direction} ${measure}"
                    
                    values=`fslmeants -i ${pre_proc_dir}/all_${measure}.nii.gz \
                                -m ${fill_file}`
                    echo ${group_name}__${test_name}__${test_measure}__${direction}__${measure}__fill ${values} >> ${output_file}
                    
                    values=`fslmeants -i ${pre_proc_dir}/all_${measure}_skeletonised.nii.gz \
                                -m ${not_fill_file}`
                    echo ${group_name}__${test_name}__${test_measure}__${direction}__${measure}__skel ${values} >> ${output_file}
                    
                done
            done
        fi
    done
done
    
# Finally, transpose the output file
temp_dir=`dirname ${output_file}`

n_cols=`head ${output_file} -n 1 | wc -w`
for i in $(seq ${n_cols}); do
    awk -v X=$i '{print $X}' ${output_file} | tr '\n' ' ' > ${temp_dir}/temp_${i}
    echo '' >> ${temp_dir}/temp_${i}
done
temp_files=(`ls -d ${temp_dir}/temp*`)
cat ${temp_files[@]} > ${output_file}
