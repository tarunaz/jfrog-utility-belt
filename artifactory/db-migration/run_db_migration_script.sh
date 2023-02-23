#!/bin/bash

##########################################################################################
#
# Name: run_db_migration_script.sh
#
# Purpose: Get input parameters and run the script db_migration_script.sh in background
#          This is MySQL to Postgres DB migration 
#
# Input parameters:
#
# src_host - source DB hostname
# src_port - source DB port
# src_db_name - source DB name
# src_user_name - source DB name
# src_db_pwd - source DB pwd
#
# dest_host - destination DB hostname
# dest_port - destination DB port
# dest_db_name - destination DB name
# dest_user_name - destination DB name
# dest_db_pwd - destination DB pwd
#
# dest_db_superuser_user - destination DB root/admin user
# dest_db_superuser_pwd - destination DB root/admin pwd
#
# dump_dir_name - directory where DB dumps will be placed
#
# is_to_run_vacuum_analyze - is to run vacuum analyze after migration or not [0-no/1-yes]
#
# is_to_list_tables_nrows - is to list tables and their number of row after migration or not [0-no/1-yes]
#
# the_tables_to_exclude - the table list with , separator, that should be excluded from migration process
#
# sql_execution_script_1 - ddl 1 emigration script. Contains postgres database structure to be loaded
# sql_execution_script_2 - ddl 2 migration script. Contains postgres database structure to be loaded
#
# node_props_flag - flag that solves DOPS-7606 issue
#
# Author: Dmitry
#
# Date Created: 31-Mar-2021
#
# Date Modified: 8-Nov-2021
#
# Version: 3.10
#
##########################################################################################

export the_num_of_inp_parameters=19

########################################################################
#
# Accept input parameters
#
########################################################################

export current_date_time="$(date +'%Y%m%d_%H%M%S')"

echo " "
echo "Started at ${current_date_time}"
echo " "

echo "Cloud Provider: AWS"
echo " "

echo "Num of input parameters: $#"

if [ "$#" -ne $the_num_of_inp_parameters ]; then
    echo "Error: Illegal number of parameters. It should be $the_num_of_inp_parameters input parameters!"
    exit 20
fi

export the_tables_to_exclude="none"

export src_host="${1}"
export src_port="3306"
export db_name="${2}"
export db_user="${3}"
export db_pwd="${4}"

export src_db_name="${db_name}"
export src_db_user="${db_user}"
export src_db_pwd="${db_pwd}"

export dest_host="${5}"
export dest_port="5432"
export dest_db_name="${6}"
export dest_db_user="${7}"
export dest_db_pwd="${8}"

export dest_db_superuser_user="${9}"
export dest_db_superuser_pwd="${10}"

export the_tables_to_exclude=${11}

export is_prev_failed=${12}
export n_of_cores=${13}
export run_status_file=${14}

export home_dir=${15}
export ssl_mode=${16}

export sql_execution_script_1=${17}
export sql_execution_script_2=${18}

export node_props_flag=${19}

export db_user="${db_name}"
export dest_db_user="${dest_db_user}"

export dump_dir_name="pgloader_config_files"

export is_to_run_vacuum_analyze=1
export is_to_list_tables_nrows=0
export is_to_check_matching=1
export exclude_compared_tables="schema_change_log,md_temp_prerelease_groups"

######################################################################
#
# Home directory to run the script
#
######################################################################

# export home_dir="${HOME}/my_postgres"

cd ${home_dir}

export output_trace="${home_dir}/mysql_to_pg_db_migration_traces/db_migration_${current_date_time}.trc"

touch ${output_trace}

filler=" "

echo " "
echo "Input parameters:"
echo "${filler}"
echo "home_dir: $home_dir"
echo "${filler}"
echo "src_host: $src_host"
echo "src_port: $src_port"
echo "src_db_name: $src_db_name"
echo "src_db_user: $src_db_user"
echo "src_db_pwd: ***********"
echo "${filler}"
echo "dest_host: $dest_host"
echo "dest_port: $dest_port"
echo "dest_db_name: $dest_db_name"
echo "dest_db_user: $dest_db_user"
echo "dest_db_pwd: ************"
echo "${filler}"
echo "dest_db_superuser_user: $dest_db_superuser_user"
echo "dest_db_superuser_pwd: **********************"
echo "${filler}"
echo "dump_dir_name: $dump_dir_name"
echo "${filler}"
echo "is_to_run_vacuum_analyze: $is_to_run_vacuum_analyze"
echo "is_to_list_tables_nrows: $is_to_list_tables_nrows"
echo "is_to_check_matching: $is_to_check_matching"
echo "${filler}"
echo "the_tables_to_exclude: $the_tables_to_exclude"
echo "${filler}"
echo "ssl_mode: $ssl_mode"
echo "sql_execution_script_1: $sql_execution_script_1"
echo "sql_execution_script_2: $sql_execution_script_2"
echo "${filler}"
echo "is_prev_failed: $is_prev_failed"
echo "n_of_cores: $n_of_cores"
echo "node_props_flag: $node_props_flag"
echo "exclude_compared_tables: $exclude_compared_tables"
echo "${filler}"

if [ -z "$home_dir" ]
then
      echo "Error: Parameter home_dir is empty!"
      echo " "
      exit 1
fi

if [ -z "$n_of_cores" ]
then
      echo "Error: Parameter n_of_cores is empty!"
      echo " "
      exit 1
fi

if [ -z "$run_status_file" ]
then
      echo "Error: Parameter run_status_file is empty!"
      echo " "
      exit 1
fi

#check if moreutils package installed - combine utility is used to compare files
moreutils_installed=$(dpkg -l | grep moreutils)
if [ -z "$moreutils_installed" ]
then
      echo  "Error! Package 'moreutils' is not installed!"
      echo " "
      exit 1
fi

#case "$is_prev_failed" in

#        "True")

#            nohup ${home_dir}/db_migration_script_rerun.sh $src_host $src_port $src_db_name $src_db_user $src_db_pwd $dest_host $dest_port $dest_db_name $dest_db_user $dest_db_pwd $dest_db_superuser_user $dest_db_superuser_pwd $dump_dir_name $is_to_run_vacuum_analyze $is_to_list_tables_nrows $is_to_check_matching $the_tables_to_exclude $n_of_cores $run_status_file $home_dir $ssl_mode $sql_execution_script_1 $sql_execution_script_2 $node_props_flag $exclude_compared_tables > ${output_trace} 2>&1 &

#            echo "trace_file: ${output_trace}"
#	    echo " "
#            echo "run_status_file: ${run_status_file}"
#            echo " "
#            ;;

 #       "False")

            nohup ${home_dir}/db_migration_script.sh $src_host $src_port $src_db_name $src_db_user $src_db_pwd $dest_host $dest_port $dest_db_name $dest_db_user $dest_db_pwd $dest_db_superuser_user $dest_db_superuser_pwd $dump_dir_name $is_to_run_vacuum_analyze $is_to_list_tables_nrows $is_to_check_matching $the_tables_to_exclude $n_of_cores $run_status_file $home_dir $ssl_mode $sql_execution_script_1 $sql_execution_script_2 $node_props_flag $exclude_compared_tables > ${output_trace} 2>&1 &

            echo "trace_file: ${output_trace}"
	    echo " "
	    echo "run_status_file: ${run_status_file}"
            echo " "
  #          ;;
  #      *)
  #          echo "Error: is_prev_failed parameter can be True or False"
  #          exit 1

#esac

#######################################################################################
#
# The End
#
#######################################################################################
