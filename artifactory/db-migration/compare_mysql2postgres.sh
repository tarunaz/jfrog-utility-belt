#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -h hostname1 -p port1 -s ssl_mode -d dbname1 -l dbuser1 -g hostname2 -q port2 -e dbname2 -m dbuser2 -w srcPwd -z destPwd -t excludeTbls"
   echo -e "\t-h Mysql hostname1"
   echo -e "\t-p Mysql port1"
   echo -e "\t-s Mysql SSL Mode"
   echo -e "\t-d Mysql db1 to compare"
   echo -e "\t-l Mysql dbuser1"
   echo -e "\t-w Mysql db1 pwd"
   echo -e "\t-g Postgres hostname2"
   echo -e "\t-q Postgers port2"
   echo -e "\t-e Postgres db2 to compare"
   echo -e "\t-m Postgres dbuser2"
   echo -e "\t-z Postgres db2 pwd"
   echo -e "\t-t Exclude tables" 
   exit 1 # Exit script after printing help
}

echo " "
echo " --- start of compare Mysql 2 Postgres DBs script ---"
echo " "

while getopts "h:p:s:d:l:g:q:e:m:w:z:t:" opt
do
   case "$opt" in
      h ) src_host="$OPTARG" ;;
      p ) src_port="$OPTARG" ;;
      s ) ssl_mode="$OPTARG" ;;
      d ) db_name="$OPTARG" ;;
      l ) db_user="$OPTARG" ;;
      g ) dest_host="$OPTARG" ;;
      q ) dest_port="$OPTARG" ;;
      e ) dest_db_name="$OPTARG" ;;
      m ) dest_db_user="$OPTARG" ;;
      w ) db_pwd="$OPTARG" ;;
      z ) dest_db_pwd="$OPTARG" ;;
      t ) exclude_tables="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

if [ -z "$src_host" ] || [ -z "$db_name" ] || [ -z "$db_user" ] || [ -z "$db_pwd" ] || [ -z "$src_port" ] || [ -z "$ssl_mode" ] || [ -z "$dest_host" ] || [ -z "$dest_db_name" ]  || [ -z "$dest_db_user" ]  || [ -z "$dest_db_pwd" ] || [ -z "$dest_port" ]
then
	echo "Some or all input parameters are empty";
	helpFunction
fi

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
psql -h ${dest_host} -p ${dest_port} -U ${dest_db_user} -d ${dest_db_name} -t -c "SELECT LOWER(table_name) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' order by table_name" >  $postgres_tables

#remove last 1 line from the postgres file
head -n -1 $postgres_tables  > $tmp_file ; mv $tmp_file $postgres_tables

#remove first character in every row in the postgres  file
cut -c 2- < $postgres_tables  > $tmp_file && mv $tmp_file $postgres_tables

tblsIgnoreArr=($(echo "$exclude_tables" | tr ',' '\n'))
#remove ignored tables from comparison
echo "Print excluded compared tables:"
for ex_tbl in "${tblsIgnoreArr[@]}"
do
        echo "table: $ex_tbl"
	lower_ex_tbl="$(echo ${ex_tbl,,})"
        sed "/${lower_ex_tbl}/d"  $mysql_tables > $tmp_file; mv $tmp_file $mysql_tables
        sed "/${lower_ex_tbl}/d"  $postgres_tables > $tmp_file; mv $tmp_file $postgres_tables
done
echo " "
#get all records from file 1 that are not in file 2
cmp1=$(combine $mysql_tables not $postgres_tables)
cmp2=$(combine $postgres_tables not $mysql_tables)

rm -f $mysql_tables
rm -f $postgres_tables

if [ -z "$cmp1" ] &&  [ -z "$cmp2" ]
then
    echo  "Comparison successful. No differences found"
elif  [ ! -z  "$cmp1" ]
then
    echo "Error: Following tables exist in Mysql but don't exist in Postgres:"
    echo "$cmp1"
    exit 1;
elif  [  ! -z "$cmp2" ]
then
   echo "Error: Following tables exist in Postgres but don't exist in Mysql:"
   echo "$cmp2"
   exit 1;
fi

echo " "
echo " --- end of compare 2 DBs script ---"
echo " "
