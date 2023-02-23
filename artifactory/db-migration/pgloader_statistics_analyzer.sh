#!/bin/bash

# #####################################################
# Standalone script that analyzes pgloader trace file. It searches for migration and data loss errors.
# It prints to the standard output:
# 1. Migration errors that appear in the pgloader trace log 
# 2. Differences between read and imported column in the pgloader summary table 
# Input parameters:
# trace_file - file that contains pgloader summary log
# base_folder - full path to trace_file
# #####################################################

#input parameters
base_folder="/home/ubuntu/pgloader/statistics/"
trace_file="pgloader_run_trace_20220117_1241.out"

current_date_time="$(date +'%Y%m%d_%H%M%S')"
stats=$base_folder$trace_file"_"$current_date_time".tmp"
cp $base_folder$trace_file  $stats

echo "[$(date +'%Y%m%d_%H%M%S')]: Analyze Pgloader Statistics"
echo " "

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
#delete 2 last lines - footer
sed -i "$(( $(wc -l <$stats)-2+1 )),$ d" $stats

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
else
    echo "Pgloader Summary: No errors found"
    echo " "
fi

rm -f "$stats"
