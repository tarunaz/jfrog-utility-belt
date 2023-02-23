#!/bin/bash

if [ `tail -f -n +1 "$2" | grep -m 1 "Database error" |wc -l` -gt 0 ] ;
 then
   echo 'Stopping pgloader process, getting [Database error] from pgloader logs' | tee -a "$2"
   echo ERROR_MIGRATION > "$1" ;
   pkill --signal 9 pgloader;
   exit 1;
fi

