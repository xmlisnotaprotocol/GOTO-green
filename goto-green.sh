#!/usr/bin/env bash

#########################################################
# Script to move idle workloads into to visibility_only #
#########################################################

# MoveToVisibilityRun${NOW}.tar.gz is left and contains:
# Before-YYYYMMDDHHMM.csv            A snapshot of workload states before the run
# mode-input-YYYYMMDDHHMM.csv        file of all workloads with status=green and GPO=yellow and no red check results
# After-YYYYMMDDHHMM.csv             A snapshot of workload states AFTER the run
# YYYYMMDDHHMM.log                   A log of all actions (e.g. for any backouts)
# YYYYMMDDHHMM.csv                   a list of compatibility reports for all idle workloads (examples below that would pass)


# YYYYMMDDHHMM Time stamp for this run
NOW=$(date +"%Y%m%d%H%M")

# Path to workloader ( https://github.com/brian1917/workloader/releases ) binary and pce.yaml for default-pce
WORKLOADER="./workloader --log-file ${NOW}.log --verbose"

# Set Proxy if required to reach default-pce
#${WORKLOADER} set-proxy default-pce http://proxy.com:8080

# Check for current workloader version
${WORKLOADER} check-version

# Get an export of workloads current state before the run
${WORKLOADER} wkld-export --output-file Before-${NOW}.csv

# Get a list of all idle workloads from the PCE and Retrieve compatibility reports for each workload in that list
${WORKLOADER} compatibility -m --output-file ${NOW}.csv 

# Any workload that is status green set to move to visibility_only
sed -i 's/mode/enforcement/g' mode-input-${NOW}.csv

# Any Windows workload that is status yellow and GroupPolicy=yellow and no reds set to move to visibility_only
awk -F, '/""Group_policy"":""Domain firewall GPO found"",""status"":""yellow""/&&!/,red,/{print $2",visibility_only"}' ${NOW}.csv >> mode-input-${NOW}.csv

# Move to visibility_only
${WORKLOADER} wkld-import mode-input-${NOW}.csv --allow-enforcement-changes --update-pce  --no-prompt
sleep 60 # give workloads time to sync

# Get an export of workloads state after the run
${WORKLOADER} wkld-export --output-file After-${NOW}.csv
# POSIX tar
tar --remove-files -czvf MoveToVisibilityRun${NOW}.tar.gz ${NOW}.log Before-${NOW}.csv ${NOW}.csv mode-input-${NOW}.csv After-${NOW}.csv
