#!/bin/bash

##########################################################################################
#
# Name: get_status_db_migration_script.sh
#
# Purpose: Get status of db migration script
#
# Input parameters:
#
# No
#
# Output:
#  IN_PROGRESS - status means the db migration in progress
#  FINISH - status means the db migration has finished
#
# Author: Dmitry
#
# Date Created: 06-Apr-2021
#
# Date Modified: 20-Jul-2021
#
# Version: 3.00
#
##########################################################################################

home_dir="${HOME}/my_postgres"
run_status_file="current_status"
run_status_path="${home_dir}/run_status"

cat "${run_status_path}/${run_status_file}"

##########################################################################################
#
# End
#
##########################################################################################


