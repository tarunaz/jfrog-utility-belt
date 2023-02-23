#!/bin/bash

export path_to_dbmigration_packages="..."

export src_host="some_src_host"
export db_name="some_src_db_name"
export db_user="some_src_db_user"
export db_pwd='some_src_db_pwd'
export dest_host="some_dest_host"
export dest_db_name="some_dest_db_name"
export dest_db_user="some_dest_db_user"
export dest_db_pwd='some_dest_db_pwd'
export dest_db_superuser_user="some_dest_superuser_user"
export dest_db_superuser_pwd='some_dest_superuser_pwd'
export the_tables_to_exclude="none"
export is_prev_failed="False"
export n_of_cores="8"
export run_status_file="run_status_file_full_path"
export mysql_sslmode="DISABLED"
export sql_execution_script_1="none"
export sql_execution_script_2="none"
export node_props_flag="False"

${path_to_dbmigration_packages}/run_db_migration_script.sh "${src_host}" "${db_name}" "${db_user}" "${db_pwd}" "${dest_host}" "${dest_db_name}" "${dest_db_user}" "${dest_db_pwd}" "${dest_db_superuser_user}" "${dest_db_superuser_pwd}" "${the_tables_to_exclude}" "${is_prev_failed}" "${n_of_cores}" "${run_status_file}" "${path_to_dbmigration_packages}" "${mysql_sslmode}" "${sql_execution_script_1}" "${sql_execution_script_2}" "${node_props_flag}"

