#!/bin/sh

# usage:   courseUserTableExists courseName  webworkWrite_password
#returns 1 if the course_users table exists
#        0 if the course_users table does not exist
#        null ('') if the password is incorrect


mysql -u mgage  -p$2 -B -N  -e "select count(*) from information_schema.tables where table_schema='webwork' and table_name = '${1}_user';"  2>/dev/null
#echo course $1
#echo password $2
