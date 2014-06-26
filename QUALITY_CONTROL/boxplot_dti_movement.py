#!/usr/bin/env python

def boxplot_dti_movement(subs_df, figure_name):
    '''
    Create a boxplot showing the 6 different ways of calculating
    displacement for dti scans. Label the outliers with their subid.
    '''
    #===============================================================
    # IMPORTS
    #---------------------------------------------------------------
    import numpy as np
    import matplotlib.pylab as plt
    import pandas as pd
    import matplotlib as mpl
    
    #===============================================================
        
    #===============================================================
    # Define some measures we need
    #---------------------------------------------------------------
    
    # First: the columns we're going to plot
    cols = [ name for name in subs_df.columns if 'mean_rms' in name ]
    
    # The total number of subjects
    n = subs_df.subid.count()
    
    # Define the colorbar that you want to use
    cmap = mpl.cm.gist_ncar
    norm = mpl.colors.Normalize(vmin=0, vmax=1)
    map = mpl.cm.ScalarMappable( norm, cmap)
    
    # Start the color counter
    color_counter = 1.0

    # Make sure everyone is originally set with a color of 0
    subs_df['color'] = 0.0

    #===============================================================
    # Make the figure
    #---------------------------------------------------------------
    fig, ax = plt.subplots()
    
    # Make a box plot of the six different measures of movement
    box = plt.boxplot(subs_df[cols].values)

    # One of the pieces of information contained in the box variable
    # are the locations of the fliers (the outliers)
    for f in box['fliers']:

        # Get the information from each of the 12 positions that fliers
        # could be found in.
        # x_list: list of x positions, fliers_list: list of y positions
        x_list, fliers_list = f.get_data()
        
        # Sort the fliers_list so that they're in order smallest to largest
        # Note that you don't have to sort the x list because they're all the
        # same value :)
        fliers_list.sort()
        
        # Now loop through all the x, y pairs in the x_list and
        # fliers_list and define a counter (c)
        for c, (x, y) in enumerate(zip(x_list, fliers_list)):
        
            # You can find the subID for each of the outliers
            # by looking up the y value in the appropriate column
            #(indexed as x-1 because the plot doesn't start counting at 0)
            id = subs_df.subid[subs_df[cols[np.int(x-1)]]==y].values[0]

            # We're also going to set the color of each box so that it's the
            # same for each individual across plots. Note that you don't have to
            # do this step if the person already has a color.
            if subs_df.color[subs_df.subid==id] == 0:
                subs_df.color[subs_df.subid==id] = color_counter
                color_counter+=1
            
            # Get the sub_color_id, this is the number that's been filled in
            # in the subs_df for this participant, and define the color that
            # will be used in the annotation
            sub_color_id = subs_df.color[subs_df.subid==id]
            color = map.to_rgba(10.0*sub_color_id.values[0]/n)
                        
            # In order to make the labels flip sides left and right as
            # we go through each person we're going do something creative
            # with modulo division
            offset_x = -0.5 * np.float(c%2) + 0.25 + x
            offset_y = 0.25 + y
            
            # Annotate all the outliers with a box that contains their subid
            # and has a personalized color
            ax.annotate(id, xy=(x, y), xytext=(offset_x, offset_y),
                textcoords='data', ha='center', va='center',
                bbox=dict(boxstyle='round,pad=0.2', fc=color, alpha=0.5),
                arrowprops=dict(arrowstyle='->', 
                                color='black'))

    # Make the plot look nicer:
    # Lets make sure the labels all fit onto the x axis
    plt.xticks(range(1,len(cols)+1), cols, rotation=45)
    # And label the yaxis
    ax.set_ylabel('Displacement (mm)')
    # And set the y axis to being a little higher than the max so the labels fit!
    ylims = ax.get_ylim()
    ax.set_ylim(ylims[0], ylims[1]+0.5)
    # Don't know if this makes a difference, but hey, here's a try
    plt.tight_layout()
    # Name the figure and save it
    fig.savefig(figure_name, bbox_inches=0, dpi=100)
    
    return subs_df
