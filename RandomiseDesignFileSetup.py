#!/usr/bin/env python

"""
Name: DesignFileSetup.py

Created by: Kirstie Whitaker
            kw401@cam.ac.uk

This script takes a behavioral data file for MRIMPACT data
and a list of mri subjects who have usable data and then
creates a plethora of possible design files for randomise
analyes in FSL.

You could also use these files for feat analyses by copying 
the numbers into the "paste" window in the Feat GUI.

Version 0.1: 3rd April 2013
    Currently this script works but it needs to be
    tested rigorously. Also it currently uses random data
    for cortisol measurements.
    
    TO DO: Include grand mean measurement for Feat analyses

"""

#------------------------------------------------
### IMPORTS ###
#------------------------------------------------
import os
import sys
import numpy as np
from shutil import copy, rmtree
import itertools as it
import numpy.lib.recfunctions as nprf
from glob import glob
import filecmp

# Import your personal scripts
sys.path.insert(0, '/home/kw401/CAMBRIDGE_SCRIPTS/GENERAL_SCRIPTS/')
sys.path.insert(0, 'C:\\Users\\Kirstie\\Dropbox\\GitHub\\GENERAL_CODE\\')
import MyCoolFunctions as mcf
#------------------------------------------------

#------------------------------------------------
### FUNCTIONS ###
#------------------------------------------------

def usage():
    
    """
    Prints the usage to the command line
    
    Input: None
    Output: Text to terminal
    """
    
    print 'Randomise_setup.py <behav_file> <cortisol_file> <randomise_setup.py file> <usable_mri_sublist_file> <output_directory> '
    print '    <behav_file>: comma separated behavioral data with header'
    print '    <cortisol_file>: tab delimited file with cortisol data'
    print '                     probably output from Cortisol_PreProcessing.py'
    print '    <randomise_setup.py file>: randomise file that contains your personal options'
    print '    <useable_mri_sublist_file>: list of subids to be included in analyses'
    print '    <output_directory>: Name (and path) of output directory'
    print '\teg: Randomise_DTIROIS_setup.py BehavData_130321.csv dti_sublist TBSS_120314'

#------------------------------------------------
def setup_data(behav_filename):
    data = np.genfromtxt(behav_filename, dtype=None, names=True, delimiter=',')
    
    if not 'SubID' in data.dtype.names:
        ### SUBID
        # Create a SubID column that is just the subid without the letter M
        subids = data['ParticipantID']
        subids = np.char.strip(subids, 'M')
        subids = subids.astype(int)
        data = nprf.append_fields(base = data, names = 'SubID',
                                    data = subids, usemask=False)
    
    if not 'TreatmentArm' in data.dtype.names:
        ### TREATMENTARM
        # Convert the TreatmentGroup into TreatmentArm integer values
        treatment_dict = dict()
        treatment_dict[0] = 'Control'
        treatment_dict[1] = 'CBT'
        treatment_dict[2] = 'STPP'
        treatment_dict[3] = 'SCC'
    
        treatment_arm_array = np.ones(data['TreatmentGroup'].shape) * 999
        for i in range(4):
            treatment_arm_array[data['TreatmentGroup']==treatment_dict[i]] = i
            treatment_arm_array = treatment_arm_array.astype(int)
        data = nprf.append_fields(base = data, names='TreatmentArm',
                                    data = treatment_arm_array, usemask=False)

    if not 'Depressed' in data.dtype.names:
        ### DEPRESSED
        # Add in a column called Depressed - based on the TreatmentArm
        data = nprf.append_fields(base = data, names='Depressed',
                                    data = data['TreatmentArm'], usemask=False)
    
        # Replace the values in Depressed with 1s and 0s
        data['Depressed'][data['Depressed'] > 0] = 1
    
    if not 'Male' in data.dtype.names:
        ### MALE
        # Create Male column of 1s and 0s
        data = nprf.append_fields(base = data, names='Male',
                                    data = data['Sex'], usemask=False)
        data['Male'][data['Sex'] == 'M'] = 1
        data['Male'][data['Sex'] == 'F'] = 0
    
    return data

def merge_cort(data, cortisol_filename):
    
    cort_data = np.genfromtxt(cortisol_filename, dtype=None, names=True, delimiter='\t')
    
    names = list(cort_data.dtype.names)
    
    # Find all the columns in cort_data that have 'av' in their title
    # and not '_mask'
    drop_names = names[8:]

    cort_data = nprf.drop_fields(cort_data, drop_names, usemask=False, asrecarray=True)
    
    data = nprf.join_by('SubID', data, cort_data, jointype='leftouter',
                            r1postfix='KW', r2postfix='KW2', usemask=False,asrecarray=True)
    
    # Bizzarely, the join_by function pads with the biggest numbers it can think of!
    # So we're going to replace everything over 999 with 999
    for name in names[1:8]:
        data[name][data[name]>999] = 999
    
    # Define a UsableCort field: 1 if ANY of the cortisol values are not 999
    cort_array = np.vstack( [ data[name] for name in names[1:8]])
    usable_cort_array = np.ones(cort_array.shape[1])
    usable_cort_array[np.any(cort_array<>999, axis=0)] = 1
    
    data = nprf.append_fields(base = data, names='UsableCort', data = usable_cort_array, usemask=False)

    return data
    
def make_subs_array(data):
    """
    A very simple little function that just adds t1 to the
    end of the subIDs incase you need it.
    """
    # Create the subs array - adding t1 to the end of each subid
    t1 = np.ones_like(data['SubID']).astype(str)
    t1[:] = 't1'
    subs_array = np.char.add(data['SubID'].astype(str), t1)
    return subs_array
    
#------------------------------------------------

def create_mask_all(data, usable_mri_subs):
    """
    This function excludes people who have abnormal brains or braces
    and only includes participants who have usable MRI data
    """
    # Only include data for people who do not have abnormal brains or braces
    ab_brain_mask = data['AbnormalBrain']==0
    braces_mask = data['Braces']==0

    # Only include subs who have usable mri data
    '''
    AMAAAAZING tip here - np.in1d
    stolen from http://stackoverflow.com/questions/13629061/numpy-mask-based-on-if-a-value-is-in-some-other-list
    '''
    mri_mask = np.in1d(data['SubID'], usable_mri_subs)

    # Generate an overall mask
    mask_all = ab_brain_mask * braces_mask * mri_mask
    
    # If you have chosen to require all measures then this
    # this function also masks everyone who has 999 for any values
    # of any measure
    if req_all_measures:
        all_vars = set(measures + covars)
        all_var_array = np.vstack([ data[var] for var in all_vars ])
        # Mask any rows that have a value of 999
        all_var_mask = np.all(all_var_array<>999, axis=0)
        mask_all = mask_all * all_var_mask

    return mask_all

#------------------------------------------------

def excl_999s(data, measure, combo, mask):
    all_vars = []
    if not measure == '':
        all_vars.append(measure)
    all_vars.extend(combo)
    if not all_vars == []:
        all_var_array = np.vstack([ data[var] for var in all_vars ])
        # Mask any rows that have a value of 999
        all_var_mask = np.all(all_var_array<>999, axis=0)
        mask = mask * all_var_mask
    
    return data, mask

def write_files(subs_array, mat_array, con_array, test_name, dir):
    """
    Writes out .mat, .con and subs design files
    
    Inputs:
        subs_array      List of subIDs to be written out
        mat_array       Data for .mat file
        con_array       Data for .con file
        test_name       String that will be part of file name
        dir             Output_dir

    Output:
        Files saved in locations specified by filenames:
        subs file       List of sub ids (just the 4 digit number)
        subs_t1_file    List of sub ids with t1 appended
        mat_file        Mat file for FSL analyses
        con_file        Con file for FSL analyses
    """
    # Make sure output dir exists
    mcf.KW_mkdirs(dir)
    
    # Name the files
    subs_t1_filename = os.path.join(dir, 'subs_t1')
    subs_filename = os.path.join(dir, 'subs')
    mat_filename = os.path.join(dir, test_name + '.mat')
    con_filename = os.path.join(dir, test_name + '.con')

    # Write out the subs with t1 appended to the subs_t1_filename
    np.savetxt(subs_t1_filename, subs_array[mask], fmt = '%s')
    
    # Write out the subs ids alone to the subs filename
    np.savetxt(subs_filename, data['SubID'][mask], fmt = '%s')
    
    # Only save files if there are no empty colums
    # (eg: Controls and Meds -- the Meds column will be all 0s)
    # ndim is the number of dimensions that the array has
    # but we need to index from 1 below that
    if mat_array.ndim == 1:
        test = mat_array.std() == 0.0
    else:
        test = 0.0 in mat_array.std(axis=mat_array.ndim-1)
    if not test:
        # Save the mat data
        np.savetxt(mat_filename, mat_array.T, fmt = '%2.6f')

        if mat_array.ndim == 1:
            waves = 1
            points = mat_array.shape[0]
        else:
            waves = mat_array.shape[0]
            points = mat_array.shape[1]
        # Now create the matrix header
        '''
        I stole how to do this from
        http://www.gossamer-threads.com/lists/python/dev/736081
        '''
        # read the current contents of the file 
        f = open(mat_filename)
        text = f.read() 
        f.close() 
        # open the file again for writing
        f = open(mat_filename, 'w') 
        f.write('/NumWaves    ' + str(waves) + '\n')
        f.write('/NumPoints    ' + str(points) + '\n')
        f.write('/Matrix \n')
        # write the original contents 
        f.write(text) 
        f.close() 
        
        # Repeat for the contrast data
        np.savetxt(con_filename, con_array, fmt = '%2.4f')
        # Now write the header
        # Read in the original data
        f = open(con_filename)
        text = f.read()
        f.close()
        # First the header
        f = open(con_filename, 'w')
        f.write('/NumWaves    ' + str(waves) + '\n')
        f.write('/NumContrasts    ' + str(con_array.shape[0]) + '\n')
        f.write('/Matrix \n')
        # Now write in the original contents
        f.write(text)
        f.close()

#------------------------------------------------

def create_arrays(data, mask, measure, combo):
    """
    This function creates mat and con arrays and test_name
    from data for a measure of interest (measure) and
    a combination of covariates of no interest.
    Both measure and combo can be empty
    
    INPUTS:
        data        The rec array that contains the data
        mask        The mask created by mask_all that
                        defines which participants you
                        will include in this array
        measure     The measure that will be included as
                        a measure of INTEREST
                        There can only be ONE measure
                        (or none)
        combo       A combination of covariates of NO
                        interest. This combination can
                        be as long as needed (including
                        an empty combination)
    """
    # First thing is to put all the data together
    # and get rid of any rows that have 999s in them
    # (Note that this has to happen before demeaning
    # because otherwise they aren't 999s anymore!!)
    data, mask = excl_999s(data, measure, combo, mask)

    # If measure exists then create a var_array from
    # the measure of interest and demean it
    if measure:
        var_array = data[measure][mask]
        var_array = var_array - var_array.mean()
    
    # If combo exists then create a covar_array from 
    # the covariates of no interest
    if combo:
        # Stack together the covar data
        '''
        Another example of lovely list comprehension
        http://docs.python.org/2/tutorial/datastructures.html#list-comprehensions
        '''
        covar_array = np.vstack([ data[covar][mask] for covar in combo ])
        # Demean the columns
        if covar_array.ndim == 1:
            covar_array = covar_array - covar_array.mean()
        else:
            '''
            This is a use of the [None] slicing - it adds a additional axis
            so that the 1 dimensional means can be subtracted from the 
            2 dimensional covar_array
            '''
            covar_array = covar_array - covar_array.mean(axis=1)[None].T
        
    # The mat array is just the stacking together of both of these arrays
    # obviously depending on if you have them all etc
    if measure and combo:
        mat_array = np.vstack([var_array, covar_array])

        test_name = 'Corr_' + measure
        covar_name = '_'.join(covar for covar in combo)
        test_name = test_name + '_Covar_' + covar_name

    elif measure:
        test_name = 'Corr_' + measure
        mat_array = var_array

    elif combo:
        covar_name = '_'.join(covar for covar in combo)
        test_name = 'Covar_' + covar_name
        mat_array = covar_array

    else:
        test_name = ''
        mat_array = np.array([])

    # Create a contrast array by creating a bunch of zeros
    # and then put 1 and -1 at the beginning of the two lines
    template = np.array([[1],[-1]])
    if mat_array.ndim == 1 and len(mat_array) > 0:
        con_array = template
    elif mat_array.ndim > 1:
        con_array = np.zeros([2, mat_array.shape[0]])
        con_array[:,:1] = template
    else:
        con_array = np.array([])

    return test_name, mat_array, con_array
    
#------------------------------------------------

def create_correlations(dir, mask, data, subs_array):
    """
    This function sets up all the correlations for each subject list
    """
    # Create all the correlation design files
    # For each individual measure you care about
    for measure in measures:
        # We're going to loop over all the combinations of
        # the various covariates of no interest
        # eg: Age, Age_Male, Age_Male_Meds, Male, Male_Meds, Meds
        for i in range(0,len(covars)+1):
            for combo in it.combinations(covars, i):
                # Don't repeat measures
                # you'll have the same column in there twice!
                if not measure in combo:
                  
                    # Use create_arrays function to create mat and con arrays
                    test_name, mat_array, con_array = create_arrays(data, mask, measure, combo)

                    # Use write_files function to save the files
                    write_files(subs_array, mat_array, con_array, test_name, dir)

#------------------------------------------------                    

def create_arrays_ttest(mask, data, perm_list, index, measure, combo):
    """
    INPUTS:
        mask        boolean mask that selects appropriate subjects
        data        rec array containing the data
                        mask should fit this data
        perm_list   list of permutations of covariates
        index       location within perm_list that you want to test
                        with the ttest - eg if the list is 2,2,2
                        and index is 1 then you'll split on the
                        2nd value in the list and leave the others
                        as they are
        measure     covariate of interest
        combo       combination of addition covariates to include
                        but NOT test. Covariates of NO interest
    """
    # Define the two column arrays - mask here
    col1 = data[split_vars[index]][mask]
    col2 = (col1 * -1) + 1
    
    ttest_array = np.vstack([col1, col2])

    # Use create_arrays function to create mat and con arrays
    corr_test_name, mat_array, con_array = create_arrays(data, mask, measure, combo)
        
    if measure or combo:
        # Append this mat_array to the ttest_array
        ttest_array = np.vstack([ttest_array, mat_array])

    # Define the test_name
    if measure:
        measure_name = '_Corr_' + measure
    else:
        measure_name = ''

    if combo:
        covar_name = '_'.join(covar for covar in combo)
        covar_name = '_Covar_' + covar_name
    else:
        covar_name = ''
        
    ttest_name = ( 'TTest_' 
                + group_dict[split_vars[index] + '_1']
                + group_dict[split_vars[index] + '_0']
                + measure_name
                + covar_name )        
    
    # Create a contrast array by creating a bunch of zeros
    # and then put 1 and -1 at the beginning of the two
    # lines
    con_array = np.zeros([2, ttest_array.shape[0]])
    template = np.array([[1,-1],[-1,1]])
    con_array[:,:2] = template
    
    # Lastly - we have to create the interactions not just the
    # correlations
    ttest_array_2col = np.vstack([col1, col2])
    if measure:
        if combo:
            interaction_array = ttest_array_2col * mat_array[0,:]
            ttest_array_2col = np.vstack([ttest_array_2col, interaction_array, mat_array[1:,:]])

        else:
            interaction_array = ttest_array_2col * mat_array
            ttest_array_2col = np.vstack([ttest_array_2col, interaction_array])
        
        measure_name = '_Int_' + measure

        ttest_name_2col = ( 'TTest_' 
                + group_dict[split_vars[index] + '_1']
                + group_dict[split_vars[index] + '_0']
                + measure_name
                + covar_name )        
    
        # Create a contrast array by creating a bunch of zeros
        # and then put 1 and -1 at the beginning of the two
        # lines
        con_array_2col = np.zeros([2, ttest_array_2col.shape[0]])
        template = np.array([[1,-1],[-1,1]])
        con_array_2col[:,2:4] = template
    
    else:
        ttest_name_2col = ''
        ttest_array_2col = np.array([])
        con_array_2col = np.array([])

    return ttest_name, ttest_name_2col, ttest_array, ttest_array_2col, con_array, con_array_2col

#------------------------------------------------

def create_ttests(perm_list, dir, mask, data, subs_array):
    """
    This function sets up all the ttests for each comparison
    Basically it looks for where the permutations have a
    2 because that's used to define "IgnoreVariable".
    The script then loops through all the places that there
    is a 2 and generates t-tests for that variable.
    """
    # Find all the places that this permutation has a 2
    indices = [ i for i,x in enumerate(perm_list) if x == 2 ]
    
    for index in indices:

        # For this one you need to include having no measure
        # as well as all the ones you care about
        for measure in [ '' ] + measures:

            # We're going to loop over all the combinations
            # of the various covariates you want to control for
            # eg: Age, Age_Male, Age_Male_Meds, Male, Male_Meds, Meds
            for i in range(0,len(covars)+1):
                for combo in it.combinations(covars, i):
                    if not measure in combo:
                        # Exclude your 999 values
                        data, mask = excl_999s(data, measure, combo, mask)

                        # Use create_arrays function to create mat and con arrays
                        ttest_name, ttest_name_2col, ttest_array, ttest_array_2col, con_array, con_array_2col = create_arrays_ttest(mask, data, perm_list, index, measure, combo)

                        # Use write_files function to save the files
                        write_files(subs_array, ttest_array, con_array, ttest_name, dir)
                        
                        if measure:
                            write_files(subs_array, ttest_array_2col, con_array_2col, ttest_name_2col, dir)

#------------------------------------------------
### READ IN ARGUMENTS ###
#------------------------------------------------
try:
    behav_filename= sys.argv[1]
    cortisol_filename = sys.argv[2]
    randomise_setup_options_file = sys.argv[3]
    usable_mri_subs_filename = sys.argv[4]
    output_dir = sys.argv[5]

# If there aren't enough arguments then exit the script and print 
# the reason to the screen
except IndexError:
    print 'EXITING - Check your input arguments'
    usage()
    sys.exit()
#------------------------------------------------

#------------------------------------------------
### START CODE ###
#------------------------------------------------
# Define some variables
glm_dir = os.path.join(output_dir, 'GLM')

# Set up the data columns
data = setup_data(behav_filename)

# Set up the cortisol data and merge with the data array
#data = merge_cort(data, cortisol_filename)
# Now load in the data
usable_mri_subs = np.loadtxt(usable_mri_subs_filename, dtype=str)
usable_mri_subs = np.char.replace(usable_mri_subs, 't1', '').astype(int)

#------------------------------------------------
### START CODE ###
#------------------------------------------------

# Read in the personalised options:
execfile(randomise_setup_options_file)

# Make the subs array
subs_array = make_subs_array(data)

# Mask the data so you only include people that you have mri data for
mask_all = create_mask_all(data, usable_mri_subs)

# Loop through all the differen permutations of these split criteria
'''
NOTE on ITERTOOLS.PRODUCT
We're using the product command from itertools to make all the possible
combinations - rather than combinations or permutations because we're
basically nesting for loops - and this does it for us :)
'''
# Note that the range(3) here refers to the 0,1,2 codes
# for each group splitting
for perm in it.product(range(3), repeat = len(split_vars)):
    # Write these names from the dictionary into a names list
    '''
    The j counter keeps the split_vars in the right position
    and calls the appropriate values from the perm iterable
    and calls the appropriate values from the perm iterable
    j will always count from 0 to 2 because we've coded the 
    groups as 0, 1 and 2 in the dictionary
    '''
    names = [ group_dict[split_vars[j] + '_' + str(perm[j])] for j in range(len(split_vars)) ]

    # Join the names all together
    '''
    '_' is the joining string
    '''
    group_dirname = '_'.join(name for name in names)
    print group_dirname
    
    group_dir = os.path.join(glm_dir, group_dirname)
    
    # Now create the mask you need for this data
    # Initally mask is mask_all
    mask = mask_all
    for j in range(len(split_vars)):
        '''
        I want to test the controls against the medicated patients.
        So in this line I set the Control's 'Meds' value to
        equal whatever the current permutation is so that they're
        always included based on Medications (they may be excluded for
        another reason in a different criterion!)
        '''
        
        data['Meds'][data['Depressed']==0] = perm[j]
        
        '''
        This is a pretty kickass awesome line of code that takes
        advantage of list comprehensions
        http://docs.python.org/2/tutorial/datastructures.html#list-comprehensions
        It creates the split mask for each split_var (indexed by j)
        (eg: split_vars[0] is 'Depressed') where it is equal to the
        perm value (eg: if perm is (1 2 1) then the perm value for
        'Depressed' (split_vars[0]) would be perm[0] --> 1)
        So eg: mask asks where Depressed == 1
        If the perm var is 2 it just keeps mask_all because 2 is used
        to code "Ignore that measure for splitting"
        '''
        
        split_mask = np.array(data [split_vars[j]]==perm[j] if perm[j] < 2 else mask_all)
        mask = mask * split_mask

    # Don't do anything if the mask is empty
    if mask.any():
        # Create the correlation design files
        create_correlations(group_dir, mask, data, subs_array)
        
        # If you have two groups within this group then create t-tests
        if 2 in list(perm):
            perm_list = list(perm)
            create_ttests(perm_list, group_dir, mask, data, subs_array)

'''
I'd like to include a clean up here so that folders that aren't necessary are deleted
'''
# List all the group directories that you've made
dir_list = [ os.path.join(os.path.abspath(glm_dir), d) for d in os.listdir(glm_dir) ]


# The keep names are the names for the "combined" groups
# For example these could be 'IgMed', 'IgCort', 'All' etc
keep_names = [ group_dict[key] for key in group_dict.keys() if key.endswith('2') ]

delete_list = []

# Loop through all the pairs of directories
for d1, d2 in it.combinations(dir_list, 2):
    # Run the filecmp.cmpfiles command 
    # which compares the contents of two directories
    same, diff, err = filecmp.cmpfiles(d1, d2, os.listdir(d1))
    
    # We need to remove the matlist files because they'll be
    # different just because they contain their own directory
    # path name
    diff_noMatlist = [ f for f in diff if 'matlist' not in f ]
    
    # If the length of diff_noMatlist is 0 then the directories
    # are identical and we want to remove one of them
    if len(diff_noMatlist) == 0:
        
        # Check to see if either of these directories are named with one
        # of the "keep_names"
        keep_name = list(set(keep_names) & set(d1.split('_') + d2.split('_')))
        
        # If neither are "keep directores" then we want to remove both of them!
        if len(keep_name) == 0:
            delete_list.append(d1)
            delete_list.append(d2)
        
        # If only one is in "keep directories" then we want to remove the other
        elif not keep_name[0] in d1:
            delete_list.append(d1)
        
        elif not keep_name[0] in d2:
            delete_list.append(d2)

# Look through the list and select the unique directories
delete_list = list(set(delete_list))
# And delete them
for d in delete_list:
    rmtree(d)

#------------------------------------------------
### THE END ###
# Today is April 3rd and the sun in shining in Cambridge
#------------------------------------------------
