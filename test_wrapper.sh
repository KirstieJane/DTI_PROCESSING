#!/bin/bash

dir=`pwd`
sublist=${dir}/sublist

echo "1106t1" > ${sublist}

mkdir -p ${dir}/SCRIPTS
wget -O ${dir}/SCRIPTS/GitHubCode https://github.com/HappyPenguin/DTI_PROCESSING/archive/master.zip

unzip -of ${dir}/SCRIPTS/GitHubCode -d ${dir}/SCRIPTS/

chmod +x ${dir}/SCRIPTS/DTI_PROCESSING-master/*
dos2unix ${dir}/SCRIPTS/DTI_PROCESSING-master/*


for sub in `cat ${sublist}`; do
    echo ${sub}
    ${dir}/SCRIPTS/DTI_PROCESSING-master/dti_preprocessing.sh ${dir}/SUB_DATA/${sub}/DTI/ ${sub}
    ${dir}/SCRIPTS/DTI_PROCESSING-master/mprage_preprocessing.sh ${dir}/SUB_DATA/${sub}/MPRAGE/ ${sub}
    ${dir}/SCRIPTS/DTI_PROCESSING-master/dti_registrations.sh ${dir}/SUB_DATA/${sub}/DTI/ ${dir}/SUB_DATA/${sub}/MPRAGE/

done
