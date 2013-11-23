#!/bin/bash

# When you have run all your various tests, you need to report the
# significant ones. This script finds the significant results, runs
# tbss_fill, and then re-runs randomise with 5000 permutations. It
# also reports a list of significant results so that future commands
# can focus only on those.

# USAGE: tbss_dir

tbss_dir=$1

