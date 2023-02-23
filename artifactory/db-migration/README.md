**DB migration package**

*Purpose:*

To migrate MySQL DB to Postgres DB.

*Short description:*

This is package of shell scripts to migrate MySQL DB to Postgres DB. Based on pgloader utility.

*Main steps:*

```
 check connectifity to source db
 check the version of the source db
 check size of the source db
 check connectivity to destination db
 optionally it's possible to exclude some tables from migration
 create user and db in the dest db
 check connectivity and a new user and db were created on the dest db
 import ddl files to the dest db
 run pgloader to validate that Mysql and Postgres schemas are equal before actual data migration starts
 run pgloader to perform data migration from MySql to Postgres DB
 analyze pgloader migration results, search for migratin issues
 post restore steps
 run vacuumdb to analyze and vacuum newly imported db
```

*How to run:*

Edit parameter file: inp_params.sh populating relevant parameters:

* full path to the db migration script
* source db connection parameters
* destination db connecdtion parameters
* destination db super user credentials (required to create user and schema)
* is\_prev\_failed - receives False or True values. Migration script can be executed in 2 modes: 
	* dest db doesn't exist - script assumes dest db doesn't exist and creates everything from scratch. If will fail in case it encounters  that such db already exists. Parameter value is 0
	* dest db already exists - script will attempt to drop existing db and user. From that point it will run exactly in the same way as "create a new dest db" runs. This is useful when previous attempt to run migration script failed for some reason and there is a need to run it again. Parameter value is 1
* run status file - full path to the file that contains migration script status. Its value is set when script ends
* mysql ssl mode - mysql 5.6 requires that ssl mode will be disabled by default
* ddl file 1 - full path to first ddl file. Default value "none" when file is not set
* ddl file 2 - full path to second ddl file. Default value "none" when file is not set

Run the DB migration: ./inp_params.sh

*Trace:*

Once you run the DB migration script it will provide trace file details.

All the detailed trace information about DB migration will be there.


