#!/bin/sh

# usage:   courseUserTableExists courseName  webworkWrite_password
#returns 1 if the course_users table exists
#        0 if the course_users table does not exist
#        null ('') if the password is incorrect


mysql -u $2  -p$3 -B -N -h db -e "select count(*) from information_schema.tables where table_schema='webwork' and table_name = '${1}_user';"  2>/dev/null
#echo course $1
#echo database user (webworkWrite) $2
#echo password $3
