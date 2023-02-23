#!/bin/bash

#######################################################################
#
# Name: db_migration_script.sh
#
# Description: shell to migrate a db from one host to another host
#
# Main steps:
#
# 1. check if directory to dump postgres dbs exists
# 2. check connectifity to source db
# 3. check the version of the source db
# 4. check size of the source db
# 5. check connectivity to destination db
# 6. create user and db in the dest db
# 7. check connectivity and a new user and db were created on the dest db
# 10. run pgloader to migrate MySQL db to PG db
# 11. post restore steps
# 12. run vacuumdb to analyze and vacuum newly imported db
# 13. list tables and num_of_rows on the newly imported db
#
# Parameters:
# 
# src_host - source database host
# src_port - source database port, default is 5432
#
# dest_host - destination database host
# dest_port - destination database port, default is 5432
#
# db_name - source database name
# db_user - source database user
# db_pwd - source database pwd
#
# dest_db_superuser_user - destination database superuser user
# dest_db_superuser_pwd - destination database superuser pwd
#
# dest_db_name - destination database name 
# dest_db_user - destination user name
# dest_db_pwd - destination database pwd
#
# dump_dir_name - name of local directory where db dumps will be kept
#
# is_to_run_vacuum_analyze - optional [ 0 - No / 1 - Yes ] - is to run vacuum analyze
# is_to_list_tables_nrows - optional [ 0 - No / 1 - Yes ] - is to list tables and corresponding number of rows
# is_to_check_matching - optional [0 - No / 1 - Yes ]
#
# tables_to_exclude - list of tables to exclude separated by comma
#
# num_of_cores - number of cores to perform pg_dump and pg_restore. Will be implemented in future versions
#
# run_status_file - absolute path filename of run status file
#
# Author: Dmitry
#
# Date Created: 09-Mar-2021
#
# Date Modified: 31-Oct-2021
# 
# Version: 3.10
#
#######################################################################

status_A="RUN_IN_PROGRESS"
status_B="FINISHED"
status_C="ERROR_MIGRATION"

export run_status_path_and_file=${19}

if [ -z "$run_status_path_and_file" ]
then
      echo "Error: Parameter run_status_path_and_file is empty!"
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 12
fi

echo "run_status_path_and_file: $run_status_path_and_file"

echo "${status_A}" > ${run_status_path_and_file}

########################################################################
#
# Accept input parameters
#
########################################################################

echo " "
echo "Cloud Provider: AWS"
echo " "

echo "Num of input parameters: $#"
echo " "

echo "Print out input parameters:"

echo " "
echo "1: src_host: ${1}"
echo "2: src_port: ${2}"
echo "3: src_db_name: ${3}"
echo "4: src_db_user: ${4}"
echo "5: src_db_pwd: *****************"
echo "6: dest_host: ${6}"
echo "7: dest_port: ${7}"
echo "8: dest_db_name: ${8}"
echo "9: dest_db_user: ${9}"
echo "10: dest_db_pwd **************"
echo "11: dest_db_superuser_user: ${11}"
echo "12: dest_db_superuser_pwd: *********************"
echo "13: dump_dir_name: ${13}"
echo "14: is_to_run_vacuum_analyze: ${14}"
echo "15: is_to_list_tables_nrows: ${15}"
echo "16: is_to_check_matching: ${16}"
echo "17: the_tables_to_exclude: ${17}"
echo "18: num_of_cores: ${18}"
echo "19: run_status_path_and_file: ${19}"
echo "20: home_dir: ${20}"
echo "21: ssl_mode: ${21}"
echo "22: sql_execution_script_1: ${22}"
echo "23: sql_execution_script_2: ${23}"
echo "24: node_props_flag: ${24}"
echo "25: exclude_compared_tables: ${25}"
echo " "

if [ "$#" -ne 25 ]; then
    echo "Error! Illegal number of parameters."
    echo "${status_C}" > ${run_status_path_and_file}
    exit 20
fi

src_host="${1}"
src_port="${2}"
db_name="${3}"
db_user="${4}"
db_pwd="${5}"

dest_host="${6}"
dest_port="${7}"
dest_db_name="${8}"
dest_db_user="${9}"
dest_db_pwd="${10}"

dest_db_superuser_user="${11}"
dest_db_superuser_pwd="${12}"

dump_dir_name="${13}"

is_to_run_vacuum_analyze="${14}"
is_to_list_tables_nrows="${15}"
is_to_check_matching="${16}"

tables_to_exclude="${17}"

num_of_cores="${18}"

home_dir="${20}"

ssl_mode="${21}"

sql_execution_script_1="${22}"
sql_execution_script_2="${23}"

node_props_flag="${24}"
exclude_compared_tables="${25}"

echo "This is a regular run mode"
echo " "

########################################################################
#
# Check input parameters
#
########################################################################

# check free space in the dump directory

echo "pgloader config files dir: ${dump_dir_name}"

# check num_of_cores: 2 4 6 8 10 12 14 16

case $num_of_cores in
    "2"|"4"|"6"|"8"|"10"|"12"|"14"|"16")
        echo "num_of_cores: $num_of_cores";;
    *)
        echo "Error! num_of_cores ($num_of_cores) parameter is not set correctly!"
        echo " "
        echo "${status_C}" > ${run_status_path_and_file}
        exit 7
esac

#check ssl_mode:  DISABLED PREFERRED REQUIRED

case $ssl_mode in
    "DISABLED"|"PREFERRED"|"REQUIRED")
        echo "ssl_mode: $ssl_mode";;
    *)
        echo "Error! ssl_mode ($ssl_mode) parameter is not set correctly!"
        echo " "
        echo "${status_C}" > ${run_status_path_and_file}
        exit 7
esac

if [ -z "$src_host" ]
then
      echo "Error! Parameter src_host is empty."
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 10
fi

if [ -z "$src_port" ]
then
      echo "Error! Parameter src_port is empty."
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 11
fi

if [ -z "$dest_host" ]
then
      echo "Error! Parameter dest_host is empty."
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 12
fi

if [ -z "$dest_port" ]
then
      echo "Error! Parameter dest_port is empty."
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 13
fi

if [ -z "$db_name" ]
then
      echo "Error! Parameter db_name is empty."
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 15
fi

if [ -z "$db_pwd" ]
then
      echo "Error! Parameter db_pwd is empty."
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 16
fi

if [ -z "$dest_db_superuser_user" ]
then
      echo "Error! Parameter dest_db_superuser_user is empty."
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 17
fi

if [ -z "$dest_db_superuser_pwd" ]
then
      echo "Error! Parameter dest_db_superuser_pwd is empty."
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 18
fi

if [ -z "$dest_db_name" ]
then
      echo "Error! Parameter dest_db_name is empty."
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 19
fi

if [ -z "$dest_db_pwd" ]
then
      echo "Error! Parameter dest_db_pwd is empty."
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 20
fi

if [ -z "$dump_dir_name" ]
then
      echo "Error! Parameter dump_dir_name is empty."
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 21
fi

if [ -z "$is_to_run_vacuum_analyze" ]
then
      echo "Error! Parameter is_to_run_vacuum_analyze is empty."
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 22
fi

if [ -z "$is_to_run_vacuum_analyze" ]
then
      echo "Error! Parameter is_to_run_vacuum_analyze is empty."
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 23
fi

if [ -z "$is_to_list_tables_nrows" ]
then
      echo "Error! Parameter is_to_list_tables_nrows is empty."
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 24
fi

if [[ "$src_host" == "$dest_host" ]]; then
    echo "Error! src_host and dest_host should be different."
    echo " "
    echo "${status_C}" > ${run_status_path_and_file}
    exit 14
fi

if [[ "${src_host}" == "None" ]]; then
    echo "Error! src_host cannot be None."
    echo " "
    echo "${status_C}" > ${run_status_path_and_file}
    exit 34
fi

if [[ "${dest_host}" == "None" ]]; then
    echo "Error! dest_host cannot be None."
    echo " "
    echo "${status_C}" > ${run_status_path_and_file}
    exit 35
fi

if [ -z "$sql_execution_script_1" ]
then
      echo "Info: Parameter sql_execution_script_1 is empty."
      echo " "
      #echo "${status_C}" > ${run_status_path_and_file}
      #exit 13
fi

if [ -z "$sql_execution_script_2" ]
then
      echo "Info: Parameter sql_execution_script_2 is empty."
      echo " "
      #echo "${status_C}" > ${run_status_path_and_file}
      #exit 13
fi

if [ -z "$node_props_flag" ]
then
      echo "Error! Parameter node_props_flag is empty."
      echo " "
      echo "${status_C}" > ${run_status_path_and_file}
      exit 22
fi

########################################################################
#
# Begin
#
########################################################################

current_date_time="$(date +'%Y%m%d_%H%M%S')"

echo " "

echo "[$(date +'%Y%m%d_%H%M%S')]: begin"
echo " "

########################################################################
#
# Check connectifity to source db
#
########################################################################

echo "Check connectivity to source db ${db_name} on host: ${src_host} port: ${src_port}"
echo " "

export MYSQL_PWD="${db_pwd}"

src_db_connectivity=$(mysql -h ${src_host} -P ${src_port} -u ${db_user} -D ${db_name} --ssl-mode=${ssl_mode} -N -s -e "SELECT COUNT(1) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '${db_name}'" )

if [ -z "$src_db_connectivity" ]
then
  echo "Error: connectivity problem to src db MySQL on host: ${src_host} port: ${src_port}"
  echo " "
  echo "${status_C}" > ${run_status_path_and_file}
  exit 1
else
  echo "Connectivity to the src db MySQL on the host: ${src_host} port: ${src_port} is Ok"
  echo " "
fi

if [ $src_db_connectivity -ne 1 ]
then
  echo "Error: db ${db_name} doesnot exist on source MySQL DB instance host: ${src_host} port: ${src_port}"
  echo " "
  echo "${status_C}" > ${run_status_path_and_file}
  exit 2
else
  echo "The src MySQL db ${db_name} on the host: ${src_host} port: ${src_port} existance check is Ok"
  echo " "
fi

########################################################################
#
# Check the version of the source db
#
########################################################################

echo "Get version of the source db: ${db_name} on host: ${src_host} port: ${src_port}"
echo " "

export MYSQL_PWD="${db_pwd}"

src_db_get_version=$(mysql -h ${src_host} -u ${db_user} -D ${db_name} --ssl-mode=${ssl_mode} -N -s << EOF
select version();
EOF
)

echo "Source DB version: $src_db_get_version"
echo " "

########################################################################
#
# Check size of the source db
#
########################################################################

echo "Get size of the source MySQL db: ${db_name} on host: ${src_host} port: ${src_port}"
echo " "

export MYSQL_PWD="${db_pwd}"

src_db_get_size=$(mysql -h ${src_host} -P ${src_port} -u ${db_user} -D ${db_name} --ssl-mode=${ssl_mode} -N -s  << EOF
SELECT 
        ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) DB_Size_in_MB
FROM information_schema.tables 
WHERE table_schema='${db_name}'
EOF
)

echo "Source DB size in MB: $src_db_get_size"
echo " "

########################################################################
#
# Source DB: List tables sizes
#
########################################################################

echo "List tables sizes of the Source MySQL DB: ${db_name} on host: ${src_host} port: ${src_port}"
echo " "

export MYSQL_PWD="${db_pwd}"

src_get_top_tables_sizes=$(mysql -h ${src_host} -P ${src_port} -u ${db_user} -D ${db_name} --ssl-mode=${ssl_mode}  --table << EOF
SELECT table_name AS Table_Name,
ROUND(((data_length + index_length) / 1024 / 1024), 2) AS Size_MB
FROM information_schema.TABLES
WHERE table_schema='${db_name}'
ORDER BY (data_length + index_length) DESC
EOF
)

echo "Source DB list tables size:"
echo "$src_get_top_tables_sizes"
echo " "

########################################################################
#
# Check connectivity to destination db
#
########################################################################


echo "Check connectivity to destination ${dest_db_name} on host: ${dest_host} port: ${dest_port}"
echo " "

export PGPASSWORD="${dest_db_superuser_pwd}"

dest_db_connectivity=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_superuser_user} -d postgres -t -c "select count(1) exists_or_not_exists from pg_database where datname='${dest_db_name}'" )

if [ -z "$dest_db_connectivity" ]
then
  echo "Error: connectivity problem to dest db postgres on host: ${dest_host} port: ${dest_port}"
  echo " "
  echo "${status_C}" > ${run_status_path_and_file}
  exit 1
else
  echo "Connectivity to the dest db postgres on the host: ${dest_host} port: ${dest_port} is Ok"
  echo " "
fi

if [ "$dest_db_connectivity" -ne 1 ]
then
  echo "Error: db ${dest_db_name} does not exist on the destination postgres ${dest_host} port: ${dest_port}"
  echo " "
  echo "${status_C}" > ${run_status_path_and_file}
  exit 1
fi

########################################################################
#
# Construct tables to be excluded by pgloader
#
########################################################################

echo "Parse tables to exclude data during migration"
echo " "

echo "tables_to_exclude: ${tables_to_exclude}"
echo " "

arr_tables_to_exclude=(`echo $tables_to_exclude | tr ',' ' '`)

num_of_tables_to_exclude=${#arr_tables_to_exclude[@]}

echo "num_of_tables_to_exclude: ${num_of_tables_to_exclude}"
echo " "

result_of_concat=""

for (( i=0; i<${num_of_tables_to_exclude}; i++ )); do
     result_of_concat+="'${arr_tables_to_exclude[$i]}',"  
done

result_of_concat+="'none'"

exclude_table_data_part=$result_of_concat

echo "exclude_table_data_part: ${exclude_table_data_part}"
echo " "

########################################################################
#
# Create user and db in the dest db
# NOT RELEVANT FOR SELF HOSTED CUSTOMERS
########################################################################

#echo "Create a new DB user ${dest_db_user} and a new DB ${dest_db_name} has been created on destination DB host: $dest_host"
#echo " "

#export PGPASSWORD="${dest_db_superuser_pwd}"

#create_new_user_and_new_db=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_superuser_user} -d postgres -t  << EOF

#create user ${dest_db_user} with password '${dest_db_pwd}';

#create database ${dest_db_name};

#grant all privileges on database ${dest_db_name} to ${dest_db_user};

#grant ${dest_db_user} to ${dest_db_superuser_user};

#EOF
#)

# grant "${dest_db_name}" to ${dest_db_superuser_user};

#echo "create_new_user_and_new_db: $create_new_user_and_new_db"

#echo "A new DB user ${dest_db_user} and a new DB ${dest_db_name} has been created on destination DB host: $dest_host"
#echo " "

########################################################################
#
# Post create dest user and create dest db steps
#
########################################################################

#echo "Post create user and create db steps to destination DB instance. User ${dest_db_user}. Destination DB: ${dest_db_name}, host: ${dest_host}, port: ${dest_port}"
#echo " "

#export PGPASSWORD="${dest_db_superuser_pwd}"

#post_restore_steps_new_db=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_superuser_user} -d postgres -t  << EOF

#alter database ${dest_db_name} owner to ${dest_db_user};

#revoke connect on database ${dest_db_name} from public;

#revoke temporary on database ${dest_db_name} from public;

#\l ${dest_db_name}

#EOF
#)

#echo "$post_restore_steps_new_db"
#echo " "

########################################################################
#
# Check user exists in the dest db

########################################################################

dest_user_exists=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_superuser_user} -d postgres -t -c "SELECT count(1) FROM pg_roles WHERE rolname='${dest_db_user}'" )

if [ "$dest_user_exists" -ne 1 ]
then
  echo "Error: User ${dest_db_user} does not exist on the destination postgres ${dest_host} port: ${dest_port}"
  echo " "
  echo "${status_C}" > ${run_status_path_and_file}
  exit 1
fi

########################################################################
#
# Check connectivity and a new user and db were created on the dest db
#
########################################################################

echo "Check connectivity to the new user ${dest_db_name} and to the new created destination db ${dest_db_name} on host: ${dest_host} port: ${dest_port}"
echo " "

export PGPASSWORD="${dest_db_pwd}"

dest_db_connectivity=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "select count(1) exists_or_not_exists from pg_database where datname='${dest_db_name}'")

if [ -z "$dest_db_connectivity" ]
then
  echo "Error: connectivity problem to dest db ${dest_db_name} on host: ${dest_host} port: ${dest_port}"
  echo " "
  echo "${status_C}" > ${run_status_path_and_file}
  exit 1
else
  echo "Connectivity to the dest db ${dest_db_name} on the host: ${dest_host} port: ${dest_port} is Ok"
  echo " "
fi

if [ $dest_db_connectivity -ne 1 ]
then
  echo "Error: db ${dest_db_name} doesnot exist on destination Postgres DB instance host: ${dest_host} port: ${dest_port}"
  echo " "
  echo "${status_C}" > ${run_status_path_and_file}
  exit 2
else
  echo "The destination db ${dest_db_name} on the host: ${dest_host} port: ${dest_port} existance check is Ok"
  echo " "
fi

########################################################################
#
# Check if Tables exist in the destination db
########################################################################
echo "Check tables exist and empty in destination db:"
export PGPASSWORD="${dest_db_pwd}"
drop_targetdb_function=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "DROP FUNCTION IF EXISTS fn_tables_exist();")
echo "drop_targetdb_function: $drop_targetdb_function"
create_target_db_function=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t  << EOF
CREATE OR REPLACE FUNCTION fn_tables_exist() RETURNS TABLE(name text,count int) AS
\$BODY$
DECLARE
    data record;
    v_sql text;
BEGIN
    DROP TABLE IF EXISTS tmp_tst_demo;
    CREATE TEMP TABLE tmp_tst_demo (name text,count int);
    FOR data in (SELECT table_name FROM INFORMATION_SCHEMA.tables WHERE table_schema = 'public')    LOOP
        v_sql := 'INSERT INTO tmp_tst_demo SELECT '''||data.table_name||''', exists( select 1 FROM '||data.table_name||')::int' ;
        EXECUTE v_sql;
    END LOOP;
    RETURN QUERY (SELECT * FROM tmp_tst_demo);
END
\$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
EOF
)

echo "create_target_db_function: $create_target_db_function"

if [ "$create_target_db_function" = "CREATE FUNCTION" ]
then
    #check if there are any tables in dest db. Fail otherwise
    target_db_exist=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "select count(*) from fn_tables_exist()")
    if [ "$?" -ne 0 ] #function execution throws error
    then
         echo "Error: Syntax error in plpgsql function"
         echo " "
         echo "${status_C}" > ${run_status_path_and_file}
         exit 1
    fi
    
    echo "number of tables in target db: $target_db_exist"

    if  [ ! "$target_db_exist" -ne 0 ]
    then
         echo "Error: There are no tables in dest db ${dest_db_name} on host: ${dest_host} port: ${dest_port}"
         echo " "
         echo "${status_C}" > ${run_status_path_and_file}
         psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "DROP FUNCTION IF EXISTS fn_tables_exist()"
         exit 1
    fi

    #check that that all tables in dest db are empty. Fail otherwise
    target_db_tables_empty=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "select count(*) from fn_tables_exist() where count>0")
    echo "number of non empty tables in target db: $target_db_tables_empty"
    echo " "
    if  [ "$target_db_tables_empty" -ne 0 ]
    then
         echo "Error: There are non empty tables in dest db ${dest_db_name} on host: ${dest_host} port: ${dest_port}"
         echo " "
         echo "${status_C}" > ${run_status_path_and_file}
         psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "DROP FUNCTION IF EXISTS fn_tables_exist()"
         exit 1
    fi
else
    echo "Problem with creation of fn_tables_exist function "
    echo "${status_C}" > ${run_status_path_and_file}
    exit 1
fi

#drop function that counts tables
psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "DROP FUNCTION IF EXISTS fn_tables_exist()"

########################################################################
#
# Import DDL files to Postgres
# NOT RELEVANT FOR SELF HOSTED CUSTOMERS
########################################################################

#echo "Import DDL files when defined in configuration"
#echo " "
#ddl_file_flag=0
# Check if first ddl file is defined and exist
#if [ ! "${sql_execution_script_1,,}" = 'none' ] && [ ! -s "$sql_execution_script_1" ]
#then
#      echo "Error! Parameter sql_execution_script_1: $sql_execution_script_1 does not exist or empty."
#      echo " "
#      echo "${status_C}" > ${run_status_path_and_file}
#      exit 10
#fi

#Import first ddl file if it's defined
#if  [ ! "${sql_execution_script_1,,}" = 'none' ]
#then
#     export PGPASSWORD="${dest_db_pwd}"
#     psql -v ON_ERROR_STOP=1 -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name}  -f ${sql_execution_script_1}
#     if [ ! $? = 0 ]
#     then
#	echo "Error: import DDL $sql_execution_script_1 failed"
#	echo "${status_C}" > ${run_status_path_and_file}
#	exit 10
#     else
#	echo "Inport DDL $sql_execution_script_1 - success"
#	ddl_file_flag=1
#     fi
#else
      echo "INFO: Skipping import DDL file for sql_execution_script_1 parameter"
      echo " "
#fi

# Check if second ddl file is defined and exist 
#if [ ! "${sql_execution_script_2,,}" = 'none' ] && [ ! -s "$sql_execution_script_2" ]
#then
#      echo "Error! Parameter sql_execution_script_2: $sql_execution_script_2 does not exist or empty."
#      echo " "
#      echo "${status_C}" > ${run_status_path_and_file}
#      exit 10
#fi

# Import econd ddl file if it's defined
#if  [ ! "${sql_execution_script_2,,}" = 'none' ]
#then
#     export PGPASSWORD="${dest_db_pwd}"
#     psql -v ON_ERROR_STOP=1 -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -f ${sql_execution_script_2}
#     if [ ! $? = 0 ]
#     then
#        echo "Error: import DDL $sql_execution_script_2 failed"
#	echo "${status_C}" > ${run_status_path_and_file}
#        exit 10
#     else
#        echo "Inport DDL $sql_execution_script_2 - success"
#	ddl_file_flag=1
#     fi
#else
      echo "INFO: Skipping import DDL file for sql_execution_script_2 parameter"
      echo " "
#fi

echo " "

########################################################################
#
# Make schema changes to conform between Mysql and Posgres schemas
#
########################################################################

#table md_temp_prerelease_groups
export MYSQL_PWD="${db_pwd}"
md_table_mysql=$(mysql -h ${src_host} -P ${src_port} -u ${db_user} --ssl-mode=${ssl_mode} -N -s -e "select table_name from information_schema.tables where table_schema='${db_name}' and table_name='md_temp_prerelease_groups'")
export PGPASSWORD="${dest_db_pwd}"
md_table_pg=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "select table_name from information_schema.tables where table_schema='public' and table_name='md_temp_prerelease_groups'")

#if table exists in pg but doesn't exist in mysql  -> drop it from pg
if [ ! -z "$md_table_pg" ] && [ -z "$md_table_mysql" ]
then
	export PGPASSWORD="${dest_db_pwd}"
	echo "Table md_temp_prerelease_groups doesn't exist in source ${db_name} db (Mysql). Hence it's dropped from destination ${dest_db_name} db (Postgres)"
	md_table_pg_drop=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "drop table md_temp_prerelease_groups")
	echo "Table md_table_pg_drop dropped: $md_table_pg_drop"
fi

#if table exists in mysql but doesn't exist in pg -> fail the script
if [  -z "$md_table_pg" ] && [ ! -z "$md_table_mysql" ]
then
	echo "Error! Table md_temp_prerelease_groups exists source ${db_name} db (Mysql) but doesn't exist in destination ${dest_db_name} db (Postgres)"
	echo "${status_C}" > ${run_status_path_and_file}
	exit 10
fi

#remove NOT NULL constraint on binaries.sha256 
export MYSQL_PWD="${db_pwd}"
sha256_tables=$(mysql -h ${src_host} -P ${src_port} -u ${db_user} -D ${db_name} --ssl-mode=${ssl_mode} -N -s -e "show tables")
sha256_exists=$(echo "$sha256_tables" | grep binaries)

if [ ! -z "$sha256_exists" ]
then
	export MYSQL_PWD="${db_pwd}"
	sha256_mysql=$(mysql -h ${src_host} -P ${src_port} -u ${db_user} -D ${db_name} --ssl-mode=${ssl_mode} -N -s -e "SELECT COUNT(1) FROM binaries WHERE sha256 is null")
	echo "Remove Not Null constraint from binaries.sha256:"

	if  [ "$sha256_mysql" != "0" ]
	then
		export PGPASSWORD="${dest_db_pwd}"
		sha256_pg=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "ALTER TABLE binaries ALTER COLUMN sha256 DROP NOT NULL")
		echo  "update sha256_pg: $sha256_pg"
		echo "Not Null constraint removed from binaries.sha256"
	else
		echo "Table binaries does not contain null values in sha256 column"
	fi
	echo " "
fi

#drop and rebuild indexes to ensure prop_value in node_props table is bigger than  2700 bytes 

if [ "${node_props_flag,,}" = "true" ]
then
	export PGPASSWORD="${dest_db_pwd}"
	query="SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' and table_name='node_props'"
	node_props_table_exists=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "$query")

	if [ ! -z "$node_props_table_exists" ]
	then
		echo "Drop node_props indexes:"
		export PGPASSWORD="${dest_db_pwd}"
		node_props_pg=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t  <<-EOF
		drop index node_props_node_prop_value_idx;
		drop index node_props_prop_key_value_idx;
		drop index node_props_prop_value_key_idx;
		EOF
		)

	        echo "node_props_pg: $node_props_pg"
        	echo "node_props indexes deleted successfully"
	else
		echo "node_props table doesn't exist in ${dest_db_name}"
	fi
	echo " "
fi

#alter Mysql column type to conform with Postgres column type
export MYSQL_PWD="${db_pwd}"
column_exists=$(mysql -h ${src_host} -P ${src_port} -D ${db_name} -u ${db_user} --ssl-mode=${ssl_mode} -N -s -e "select table_name from information_schema.columns where table_schema='$db_name' and table_name='access_master_key_status' and column_name='is_unique_key'")
if [ ! -z $column_exists ]
then
	export MYSQL_PWD="${db_pwd}"
	echo "Alter access_master_key_status.is_unique_key colunn type in Mysql"
	unique_key_mysql=$(mysql -h ${src_host} -P ${src_port} -u ${db_user} -D ${db_name} --ssl-mode=${ssl_mode} -N -s -e "alter table access_master_key_status modify column is_unique_key smallint")
	echo "Column access_master_key_status.is_unique_key type altered"
	echo " "
fi

#alter Mysql column type to conform with Postgres column type
export MYSQL_PWD="${db_pwd}"
column_exists=$(mysql -h ${src_host} -P ${src_port} -D ${db_name} -u ${db_user} --ssl-mode=${ssl_mode} -N -s -e "select table_name from information_schema.columns where table_schema='$db_name' and table_name='master_key_status' and column_name='is_unique_key'")
if [ ! -z $column_exists ]
then
	export MYSQL_PWD="${db_pwd}"
        echo "Alter master_key_status.is_unique_key colunn type in Mysql"
        unique_key_mysql=$(mysql -h ${src_host} -P ${src_port} -u ${db_user} -D ${db_name} --ssl-mode=${ssl_mode} -N -s -e "alter table master_key_status modify column is_unique_key smallint")
        echo "Column master_key_status.is_unique_key type altered"
        echo " "
fi

#truncate table blob_infos. The table content is rebuilt by application
export MYSQL_PWD="${db_pwd}"
query="SELECT table_name FROM information_schema.tables WHERE table_schema='$db_name' and table_name='blob_infos'"
table_exists=$(mysql -h ${src_host} -P ${src_port} -D ${db_name} -u ${db_user} --ssl-mode=${ssl_mode} -N -s -e "$query")
if [ ! -z $column_exists ]
then
	export MYSQL_PWD="${db_pwd}"
	echo "Truncate table blob_infos"
	mysql -h ${src_host} -P ${src_port} -u ${db_user} -D ${db_name} --ssl-mode=${ssl_mode} -N -s -e "truncate table blob_infos"
	echo "Table blob_infos truncated successfully"
	echo " "
fi

# Replace unique index in nodes table with a regular one 

export MYSQL_PWD="${db_pwd}"
query="SELECT table_name FROM information_schema.tables WHERE table_schema='$db_name' and table_name='nodes'"
table_exists=$(mysql -h ${src_host} -P ${src_port} -D ${db_name} -u ${db_user} --ssl-mode=${ssl_mode} -N -s -e "$query")
if [ ! -z $table_exists ]
then
    export MYSQL_PWD="${db_pwd}"
    query="select count(1) result from nodes where repo_path_checksum is null"
    null_values_exist=$(mysql -h ${src_host} -P ${src_port} -D ${db_name} -u ${db_user} --ssl-mode=${ssl_mode} -N -s -e "$query")
    if [ ! -z $null_values_exist ]
    then
        echo "Drop Unique index in nodes table over column repo_path_checksum"
        export PGPASSWORD="${dest_db_pwd}"
        psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name}  -t -c"drop index nodes_repo_path_checksum"
        echo "Create regular index in nodes table over column repo_path_checksum"
    fi

fi

###########################################################################
#
# Compare Mysql and Postgres Schemas before Running Pgloader Data Migration
#
###########################################################################

timestamp=$(date +%s)
mysql_tables="/tmp/mysql_tables_"$timestamp".out"
postgres_tables="/tmp/postgres_tables_"$timestamp".out"
tmp_file="/tmp/temp_"$timestamp".txt"

#export mysql tables
query="SELECT LOWER(table_name) FROM information_schema.tables WHERE table_type ='BASE TABLE' AND table_schema='"${db_name}"' order by table_name"
export MYSQL_PWD="${db_pwd}"
mysql -h ${src_host} -P ${src_port} -u ${db_user} --ssl-mode=${ssl_mode} -N -s -e "$query" >  $mysql_tables

#export postgres tables
export PGPASSWORD="${dest_db_pwd}"
query="SELECT LOWER(table_name) FROM information_schema.tables WHERE table_schema='public'  AND table_type='BASE TABLE' order by table_name"
psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "$query" >  $postgres_tables

#parse postgres file
head -n -1 $postgres_tables  > $tmp_file ; mv $tmp_file $postgres_tables
cut -c 2- < $postgres_tables  > $tmp_file && mv $tmp_file $postgres_tables

#remove ignored tables from comparison
excluded_tbls="$tables_to_exclude,$exclude_compared_tables"
tblsIgnoreArr=($(echo "$excluded_tbls" | tr ',' '\n'))
for ex_tbl in "${tblsIgnoreArr[@]}"
do
	lower_ex_tbl="$(echo ${ex_tbl,,})"
	sed "/${lower_ex_tbl}/d"  $mysql_tables > $tmp_file; mv $tmp_file $mysql_tables
	sed "/${lower_ex_tbl}/d"  $postgres_tables > $tmp_file; mv $tmp_file $postgres_tables
done

#get all records from file 1 that are not in file 2
cmp1=$(combine $mysql_tables not $postgres_tables) #exist in mysql but not in postgres
cmp2=$(combine $postgres_tables not $mysql_tables) #exist in postgres but not in mysql

rm -f $mysql_tables
rm -f $postgres_tables

if [ ! -z "$cmp2" ]
then
	echo "Error! Following tables exist in Postgres but don't exist in Mysql"
	echo "$cmp2"
	echo "${status_C}" > ${run_status_path_and_file}
	exit 1
fi

#run pgloader to import schema from Mysql to Postgres
if [ ! -z "$cmp1" ]
then
	echo "Run Pgloader to import DDL schema from Mysql to Postgres for the following tables:"
	echo "$cmp1"
	echo " "
	mt=$(echo "$cmp1" | paste -s -d',')
	missing_tables=$(echo "$mt" | sed -r "s/[,]+/\',\'/g")

	pgloader_configfile="${dump_dir_name}/config_file_${current_date_time}"
	echo "pgloader_configfile: $pgloader_configfile"
	echo " "
	touch "${pgloader_configfile}"
	pgloader_src_db_pwd=(`echo "${db_pwd}" | sed 's/@/@@/g' `)
	pgloader_dest_db_pwd=(`echo "${dest_db_pwd}" | sed 's/@/@@/g' `)
	echo "LOAD DATABASE" > "${pgloader_configfile}"
	ssl_mode_pgloader='disable'
	if [ "$ssl_mode" = "PREFERRED" ]
	then
	    ssl_mode_pgloader='prefer'
	elif [ "$ssl_mode" = "REQUIRED" ]
	then
	    ssl_mode_pgloader='require'
	fi

	echo "FROM mysql://${db_user}:$pgloader_src_db_pwd@${src_host}/${db_name}?sslmode=${ssl_mode_pgloader}" >> "${pgloader_configfile}"
	echo "INTO postgresql://${dest_db_user}:$pgloader_dest_db_pwd@${dest_host}/${dest_db_name}" >> "${pgloader_configfile}"
	echo "  " >> "${pgloader_configfile}"
	echo "WITH schema only" >> "${pgloader_configfile}"
	echo "INCLUDING ONLY TABLE NAMES MATCHING '$missing_tables'" >> "${pgloader_configfile}"
	echo "ALTER SCHEMA '${db_name}' RENAME TO 'public';" >> "${pgloader_configfile}"

	pgloader --verbose "${pgloader_configfile}"
	if [ $? -eq 0 ]; then
	    echo "Mising tables were imported  successfully!"
	    echo " "
	else
	    echo "Error! Pgloader failed to import missing tables!"
	    echo "${status_C}" > ${run_status_path_and_file}
	    exit 7
	fi
	rm -f $pgloader_configfile
fi

########################################################################
#
# Run pgloader
#
########################################################################

# Run pgloader failure checker before running pgloader process
nohup ${home_dir}/check_pgloader_failures.sh "$run_status_path_and_file" $output_trace 2>&1 &

echo "[$(date +'%Y%m%d_%H%M%S')]: started pgloader"
echo "copying src MySQL db:${db_name} on host ${src_host} on port ${src_port} db_user ${db_user}"
echo "to dest PG db:${dest_db_name} on host ${dest_host} on port ${dest_port} db_user ${dest_db_user}"
echo " "

pgloader_configfile="${dump_dir_name}/config_file_${current_date_time}"

echo "pgloader_configfile: $pgloader_configfile"
echo " "

touch "${pgloader_configfile}"
pgloader_src_db_pwd=(`echo "${db_pwd}" | sed 's/@/@@/g' `)
pgloader_dest_db_pwd=(`echo "${dest_db_pwd}" | sed 's/@/@@/g' `)
echo "LOAD DATABASE" > "${pgloader_configfile}"

ssl_mode_pgloader='disable'
if [ "$ssl_mode" = "PREFERRED" ]
then
    ssl_mode_pgloader='prefer'
elif [ "$ssl_mode" = "REQUIRED" ]
then
    ssl_mode_pgloader='require'
fi

echo "FROM mysql://${db_user}:$pgloader_src_db_pwd@${src_host}/${db_name}?sslmode=${ssl_mode_pgloader}" >> "${pgloader_configfile}"
echo "INTO postgresql://${dest_db_user}:$pgloader_dest_db_pwd@${dest_host}/${dest_db_name}" >> "${pgloader_configfile}"
echo "  " >> "${pgloader_configfile}"

echo "WITH" >> "${pgloader_configfile}"

#if  [ $ddl_file_flag = 1 ]
#then
    echo "data only, create no indexes,"  >> "${pgloader_configfile}"
#fi

#performance improvements for pgloader
echo "workers = 8, concurrency = 1, multiple readers per thread, rows per range = 10000, batch rows = 10000" >> "${pgloader_configfile}"
echo "SET PostgreSQL PARAMETERS " >> "${pgloader_configfile}"
echo "maintenance_work_mem to '512MB', work_mem to '48MB'"  >> "${pgloader_configfile}"
echo "SET MySQL PARAMETERS " >> "${pgloader_configfile}"
echo "net_read_timeout = '5000', " >> "${pgloader_configfile}"
echo "net_write_timeout = '5000' " >> "${pgloader_configfile}"

echo "EXCLUDING TABLE NAMES MATCHING ${exclude_table_data_part} " >> "${pgloader_configfile}"
echo "ALTER SCHEMA '${db_name}' RENAME TO 'public';" >> "${pgloader_configfile}"


pgloader --verbose "${pgloader_configfile}"

if [ $? -eq 0 ]; then
    echo "pgloader has been finished successfully!"
    echo " "
else
    echo "Error! The pgloader has been failed!"
    pkill 'tail'
    echo "${status_C}" > ${run_status_path_and_file}
    exit 7
fi

echo " "
echo "[$(date +'%Y%m%d_%H%M%S')]: finished pgloader"
echo " "

########################################################################
#
#  Review Pgloader Statistics. Saarch for migration errors
#
########################################################################

echo "[$(date +'%Y%m%d_%H%M%S')]: Analyze Pgloader Statistics"
echo " "

err_found=0
stats="/tmp/pgloader_stat_${current_date_time}"
sed -n '/started pgloader/, /pgloader has been finished successfully/p'  $output_trace >$stats

errors=$(grep 'Database error' $stats)
total=$(grep "Total import time" $stats)
err_num=$(echo $total | awk '{print $4}')
re='^[0-9]+$'

#if errors exist or number of errors is not empty fail
if  ! [ -z "$errors" ] || [[ $errors  =~ $re ]] ;
then
    err_found=1
fi

#Search for data loss
#delete all rows before pgloader summary table
sed '/LOG report summary reset/,$!d' -i  $stats
#delete first 3 lines - header
sed -i '1,3d' $stats
#delete 3 last lines - footer
sed -i "$(( $(wc -l <$stats)-3+1 )),$ d" $stats
#replace spaces with underscores in summary
sed -i 's/fetch meta data/fetch_meta_data/' $stats
sed -i 's/Drop Foreign Keys/Drop_Foreign_Keys/' $stats
sed -i 's/COPY Threads Completion/COPY_Threads_Completion/' $stats
sed -i 's/Reset Sequences/Reset_Sequences/' $stats
sed -i 's/Create Foreign Keys/Create_Foreign_Keys/' $stats
sed -i 's/Install Comments/Install_Comments/' $stats
sed -i 's/Total import time/Total_import_time/' $stats

#traverse log and search for errors and inconsistencies
cat "$stats" | while read record
do
  table=$(echo "$record"| awk '{print $1}')
  error=$(echo "$record"| awk '{print $2}')
  read=$(echo "$record"| awk '{print $3}')
  import=$(echo "$record"| awk '{print $4}')

  if [ "$error" == '---------' ];
  then
       continue;
  fi

  if [ "$error" -ne "0" ]
  then
     echo "Pgloader Error: $table - found migration errors"
     err_found=1
  fi
  if [ "$read" -ne "$import" ]
  then
     echo "Pgloader Error: $table - Read and Import not equal"
     err_found=1
  fi
done

if [ "$err_found" == 1 ]
then
    if  ! [ -z "$errors" ] || [[ $errors  =~ $re ]]
    then
         echo "Number of errors: $err_num"
         echo "Pgloader migration contains following errors:"
         echo "$errors"
    fi
    echo  "Pgloader Migration Failed"
    echo " "
    echo "${status_C}" > ${run_status_path_and_file}
    exit  12
else
    echo "Pgloader Summary: No errors found"
    echo " "
fi

#delete temporary file with pgloader statistics
rm -f "$stats"

########################################################################
#
# Update sequences in the newly imported db
#
########################################################################
export MYSQL_PWD="${db_pwd}"
query="SELECT table_name FROM information_schema.tables WHERE table_name='node_events' AND table_schema='${db_name}'"
sequence_table_exists=$(mysql -h ${src_host} -P ${src_port} -u ${db_user} -D ${db_name} --ssl-mode=${ssl_mode} -N -s -e "$query")

if [ ! -z "$sequence_table_exists" ]
then
      echo "[$(date +'%Y%m%d_%H%M%S')]: Update node_events_event_id_seq sequence"
      echo " "
      echo  "Print sequence value before update "

      query="SELECT max(event_id)  FROM node_events"
      export MYSQL_PWD="${db_pwd}"
      seq_value_mysql=$(mysql -h ${src_host} -P ${src_port} -u ${db_user} -D ${db_name} --ssl-mode=${ssl_mode} -N -s -e "$query")
      echo  "current_id: $seq_value_mysql"

      if [ ! -z "$seq_value_mysql" ]
      then
	  #check if it exists in postgres
	  query="select sequencename from pg_sequences where sequencename='node_events_event_id_seq'"
	  export PGPASSWORD="${dest_db_pwd}"
	  seq_exists_pg=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -c "$query")
	  if [ ! -z "$seq_exists_pg" ]
	  then
		new_seq="$((seq_value_mysql + 1000000))"
		echo "Updated sequence value: $new_seq"
		query="ALTER SEQUENCE node_events_event_id_seq RESTART WITH $new_seq"
		export PGPASSWORD="${dest_db_pwd}"
		psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -c "$query"
		if [ $? -eq 0  ]
		then
		    echo "Sequence updated successfully"
		else
		    echo "Error! The update sequences failed"
		fi
	  else
		echo "Sequence node_events_event_id_seq doesn't exist in ${dest_db_name} db in Postgres"
	  fi
     else
	  echo "Sequence unique_ids.current_id in Mysql is empty"
     fi
fi
echo " "

########################################################################
#
# Run vacuumdb to analyze and vacuum newly imported db
#
########################################################################

if [ $is_to_run_vacuum_analyze -eq 1 ]
then
  echo "According to input parameter it will be run vacuum and analyze statistics on destination DB ${dest_db_name}, host: ${dest_host}, port: ${dest_port}"
  echo "[$(date +'%Y%m%d_%H%M%S')]: started collect statistics for imported DB"
  export PGPASSWORD="${dest_db_pwd}"
  vacuumdb -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -j 4 -z ${dest_db_name}
  echo "[$(date +'%Y%m%d_%H%M%S')]: ended collect statistics for imported DB"
  echo " "
else
  echo "According to input parameter it will not be run vacuum and analyze statistics on destination DB ${dest_db_name}, host: ${dest_host}, port: ${dest_port}"
  echo " "
fi

########################################################################
#
# List tables and num_of_rows on the newly imported db
#
########################################################################

if [ $is_to_list_tables_nrows -eq 1 ]
then
  echo "According to input parameter it will be listed tables and their num of rows on destination DB ${dest_db_name}, host: ${dest_host}, port: ${dest_port}"
  echo " "

  export PGPASSWORD="${dest_db_pwd}"

  list_tables_and_num_of_rows=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t  << EOF

  select n.nspname as table_schema,
         c.relname as table_name,
         c.reltuples as rows
  from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
  where c.relkind = 'r'
        and n.nspname not in ('information_schema','pg_catalog')
   order by c.reltuples desc;

EOF
)

  echo "$list_tables_and_num_of_rows"
  echo " "
else
  echo "According to input parameter it will not be listed tables and their num of rows on destination DB ${dest_db_name}, host: ${dest_host}, port: ${dest_port}"
  echo " "
fi

########################################################################
#
# Compare Source and Destination DBs 
#
########################################################################

if [ $is_to_check_matching -eq 1 ]
then

    echo "According to input parameter check matching of DBs: source vs destination."

    echo "Source: host ${src_host} port ${src_port} db_name ${db_name} dbuser ${db_user}"

    echo "Destination: host ${dest_host} port ${dest_port} db_name ${dest_db_name} dbuser ${dest_db_user}"

    echo "DBs matching check has started"

    ${home_dir}/compare_mysql2postgres.sh -h ${src_host} -p ${src_port} -s ${ssl_mode} -d ${db_name} -l ${db_user} -g ${dest_host} -q ${dest_port} -e ${dest_db_name} -m ${dest_db_user} -w ${db_pwd} -z ${dest_db_pwd} -t ${excluded_tbls}

    if [ $? -eq 0 ]; then
      echo "Compare Source DB vs Destination DB has been finished successfully! According to the check the Source and Destination DBs are identical."
    else
      echo "Error! Compare Source DB vs Destination DB has been failed! According to the check the Source and Destination DBs are NOT identical!"
      echo "${status_C}" > ${run_status_path_and_file}
      exit 7
    fi

    echo "DBs matching check has been finished"

else
    echo "According to input parameter dont check matching of DBs."
fi


########################################################################
#
# Destination DB: List tables sizes
#
########################################################################

echo "List tables sizes of the Destination DB ${dest_db_name} on host: ${dest_host} port: ${dest_port}"
echo " "

export PGPASSWORD="${dest_db_pwd}"

dest_get_top_tables_sizes=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t  << EOF
select schemaname as table_schema,
    relname as table_name,
    pg_size_pretty(pg_total_relation_size(relid)) as total_size,
    pg_size_pretty(pg_relation_size(relid)) as data_size,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid))
      as external_size
from pg_catalog.pg_statio_user_tables
order by pg_total_relation_size(relid) desc,
         pg_relation_size(relid) desc
EOF
)

echo "Destination DB list tables size:"
echo "$dest_get_top_tables_sizes"
echo " "

########################################################################
#
# Post Migration Tasks
#
########################################################################

#truncate table access_db_check. It's content rebuilt by application

export MYSQL_PWD="${db_pwd}"
ac_table_mysql=$(mysql -h ${src_host} -P ${src_port} -u ${db_user} --ssl-mode=${ssl_mode} -N -s -e "select table_name from information_schema.tables where table_schema='${db_name}' and table_name='access_db_check'")
if  [ ! -z "$ac_table_mysql" ]
then
	echo "Truncate table access_db_check in  ${dest_db_name} db (Postgres)"
	export PGPASSWORD="${dest_db_pwd}"
    table_pg_truncate=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "truncate table access_db_check")
    echo "Table access_db_check truncated: $table_pg_truncate"
    echo " "
fi

# create node_props indexes

#check if flag is true
if [ "${node_props_flag,,}" = "true" ]
then
        #validate that table exists
        if [ ! -z "$node_props_table_exists" ]
        then
            echo "Create node_props indexes:"
            export PGPASSWORD="${dest_db_pwd}"
            query="select count(ctid) from node_props where (pg_column_size(node_id)+ pg_column_size(prop_key) + pg_column_size(prop_value)) > 2680"
            index_cnt=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "$query")
            is_long_index=$(echo "$index_cnt" | sed 's/ //g' )

            echo "Number of index records longer 2700: $is_long_index"
            #create indexes depending on data length
		if [ "$is_long_index" = "0" ] #there are no long records
		then
			#create original indexes
			export PGPASSWORD="${dest_db_pwd}"
                        node_props_new_index=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t  <<-EOF
			CREATE INDEX node_props_node_prop_value_idx ON node_props (node_id, prop_key varchar_pattern_ops, prop_value varchar_pattern_ops);
			CREATE INDEX node_props_prop_key_value_idx ON node_props (prop_key varchar_pattern_ops, prop_value varchar_pattern_ops);
			CREATE INDEX node_props_prop_value_key_idx ON node_props (prop_value varchar_pattern_ops, prop_key varchar_pattern_ops);
			EOF
                	)
                        np_indexes="'node_props_node_prop_value_idx','node_props_node_prop_value_idx','node_props_prop_value_key_idx'"
		else #exist records with length > than 2700 chars
			#create new indexes
			export PGPASSWORD="${dest_db_pwd}"
                        node_props_new_index=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t  <<-EOF
			CREATE INDEX node_props_node_id_idx ON node_props(node_id);
			CREATE INDEX node_props_prop_key_node_id_idx ON node_props(prop_key varchar_pattern_ops, node_id);
			EOF
                	)
                        np_indexes="'node_props_node_id_idx','node_props_prop_key_node_id_idx'"
		fi
		echo "Create node_props indexes: $np_indexes"
                query="select count(*) from pg_indexes where schemaname!='pg_catalog' and indexname in ($np_indexes)"
                export PGPASSWORD="${dest_db_pwd}"
                created_ind=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "$query")
    if [ "$created_ind" = "0" ] #new indexes not created
    then
           echo "Error! Indexes in node_props table failed to be created!"
           echo " "
           echo "${status_C}" > ${run_status_path_and_file}
           exit 1
    else #indexes created successfully
           echo "node_props_new_index: $node_props_new_index"
           echo "node_props indexes created successfully"
    fi
	else
		echo "node_props table doesn't exist in ${dest_db_name}"
	fi
	echo " "
fi

# Update access_schema_version  after migraiton 
export PGPASSWORD="${dest_db_pwd}"
query="SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' and table_name='access_schema_version'"
acc_schema_table_exist=$(psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "$query")

if [ ! -z "$acc_schema_table_exist" ]
then
    #create backup table
    echo "Update access_schema_version Table"
    echo "Create access_schema_version_backup"
    query="create table access_schema_version_backup as select * from access_schema_version"
    export PGPASSWORD="${dest_db_pwd}"
    psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -c "$query"
    echo "Update installed_rank with max value"
    query="update access_schema_version set version = (select version from access_schema_version where installed_rank = (select max(installed_rank) from access_schema_version)) where installed_rank =1"
    export PGPASSWORD="${dest_db_pwd}"
    psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -c "$query"
    echo "Delete from access_schema_version all records besides where installed_rank equals 1"
    query="delete from access_schema_version where installed_rank !=1"
    export PGPASSWORD="${dest_db_pwd}"
    psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -c "$query"
fi


########################################################################
#
# Put to source DB sign that it was migrated          
#
########################################################################

export MYSQL_PWD="${db_pwd}"

mark_source_db_it_was_migrated=$(mysql -h ${src_host} -P ${src_port} -u ${db_user} -D ${db_name} --ssl-mode=${ssl_mode}  << EOF

create table if not exists db_migration_tool_status(the_datetime TIMESTAMP, the_status VARCHAR(300));

insert into db_migration_tool_status values (now(), 'This DB was migrated MySQL2PG from host: ${src_host} to host: ${dest_host}');

EOF
)

echo "[$(date +'%Y%m%d_%H%M%S')]: end"
echo " "
echo "Status: Finished Successfully!"
echo " "
# Killing check pgloader failure
pkill '.*check_pgloader_failures'

echo "${status_B}" > ${run_status_path_and_file}

echo "The End"

########################################################################
#
# The end
#
########################################################################

