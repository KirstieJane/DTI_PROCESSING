#!/bin/bash

# Script written by Mark Jenkinson of FMRIB; posted in reply to Charlotte's question on the FSL forum 11/01/2011
# https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=FSL;4f8352a3.1101

# Commented and edited by Kirstie Whitaker (kw401@cam.ac.uk) on 3rd February 2014

# Define usage function
if [[ $# -lt 2 ]] ; then 
  echo "Usage: `basename $0` <eddy current ecclog file> <bvals file>"
  exit 1;
fi

# Read in ecclog file
logfile=$1;

# Define the directory in which the ecclog file resides
dwi_dir=`dirname ${logfile}`

# Remove files that are created by this script
rm -f ${dwi_dir}/ec_disp.txt
rm -f ${dwi_dir}/ec_rot.txt
rm -f ${dwi_dir}/ec_trans.txt

# Get the basename (which is also the basename of the eddy corrected nifti file)
basenm=`basename $logfile .ecclog`;

# Find the line numbers for the line before each of the registration matrices
# by searching for the word "Final", which precedes 4 rows that look like:
#    Final result:                                  line number: n
#    1.000000 0.000000 0.000000 0.000000            line number: n1
#    0.000000 1.000000 0.000000 0.000000 
#    0.000000 0.000000 1.000000 0.000000 
#    0.000000 0.000000 0.000000 1.000000            line number: n2
# or
#     Final result:                                 line number: n
#     1.011887 -0.002517 0.010715 -1.205730         line number: n1
#     0.002287 1.007846 0.002932 -1.780132
#     -0.012578 -0.000272 1.002718 1.177598 
#     0.000000 0.000000 0.000000 1.000000           line number: n2
#
# The variable nums contains the line numbers of the word "Final"
nums=`grep -n 'Final' $logfile | sed 's/:.*//'`; 

# Create grot.mat file
touch ${dwi_dir}/grot.mat

# Set a variable saying that we're starting so we know to keep the next file as
# the first volume for calculating the absolute movement
firsttime=yes;

# Set a counter going for each registration matrix
m=1;

# Loop through each of the registration volumes
for n in $nums ; do 

    # Print each numbered volume to screen
    echo "Timepoint $m"

    # Calculate the line numbers of the first (n1) and last (n2) lines
    # for the regisration matrix (see above for example)
    n1=`echo $n + 1 | bc` ; 
    n2=`echo $n + 5 | bc` ;

    # Write the matrix into the grot.mat file
    # note that this overwrites the file each time
    sed -n  "$n1,${n2}p" $logfile > ${dwi_dir}/grot.mat ; 

    # If this is the first time you're running this loop
    # then save the matrix as grot.refmat, change the firsttime marker
    # and copy over the matrix to grot.oldmat
    if [ $firsttime = yes ]; then
        firsttime=no
        cp ${dwi_dir}/grot.mat ${dwi_dir}/grot.refmat
        cp ${dwi_dir}/grot.mat ${dwi_dir}/grot.oldmat
    fi

    # The refmat will be the same for all the rest of the comparisons
    # and the oldmat will be the one directly before the current matrix

    # Now calculate the root mean square difference between the
    # current matrix and the refmat - the ABSOLUTE rms - and
    # save as a variable
    absval=`$FSLDIR/bin/rmsdiff ${dwi_dir}/grot.mat ${dwi_dir}/grot.refmat $basenm`

    # Now calculate the root mean square difference between the
    # current matrix and the oldmat - the RELATIVE rms - and
    # save as a variable
    relval=`$FSLDIR/bin/rmsdiff ${dwi_dir}/grot.mat ${dwi_dir}/grot.oldmat $basenm`

    # Copy over the current matrix to grot.oldmat ready for the next loop
    cp ${dwi_dir}/grot.mat ${dwi_dir}/grot.oldmat

    # Write the absolute and relative rms values into the ec_disp.txt file
    echo $absval $relval >> ${dwi_dir}/ec_disp.txt

    # Now find all the rotations and translations from the current matrix
    # and save them in ec_rot.txt and ec_trans.txt
    $FSLDIR/bin/avscale --allparams ${dwi_dir}/grot.mat $basenm | grep 'Rotation Angles' | sed 's/.* = //' >> ${dwi_dir}/ec_rot.txt ;
    $FSLDIR/bin/avscale --allparams ${dwi_dir}/grot.mat $basenm | grep 'Translations' | sed 's/.* = //' >> ${dwi_dir}/ec_trans.txt ;

    # Finally, increase the counter and carry on the loop
    m=`echo $m + 1 | bc`;
done

# Create a time series plot of the mean displacement
# Set up the grot_labels. txt file
echo "absolute" > ${dwi_dir}/grot_labels.txt
echo "relative" >> ${dwi_dir}/grot_labels.txt
# And make the plot from ec_disp.txt (created above) saved as ec_disp.png
$FSLDIR/bin/fsl_tsplot -i ${dwi_dir}/ec_disp.txt -t 'Eddy Current estimated mean displacement (mm)' -l ${dwi_dir}/grot_labels.txt -o ${dwi_dir}/ec_disp.png

# Create a timeseries plot of the rotations and translations
# Update the labels
echo "x" > ${dwi_dir}/grot_labels.txt
echo "y" >> ${dwi_dir}/grot_labels.txt
echo "z" >> ${dwi_dir}/grot_labels.txt
# Make the plots from the ec_rot.txt and ec_trans.txt files created above
$FSLDIR/bin/fsl_tsplot -i ${dwi_dir}/ec_rot.txt -t 'Eddy Current estimated rotations (radians)' -l ${dwi_dir}/grot_labels.txt -o ${dwi_dir}/ec_rot.png
$FSLDIR/bin/fsl_tsplot -i ${dwi_dir}/ec_trans.txt -t 'Eddy Current estimated translations (mm)' -l ${dwi_dir}/grot_labels.txt -o ${dwi_dir}/ec_trans.png

# clean up temp files
/bin/rm ${dwi_dir}/grot_labels.txt ${dwi_dir}/grot.oldmat ${dwi_dir}/grot.refmat ${dwi_dir}/grot.mat 
