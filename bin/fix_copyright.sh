#!/bin/sh
sed -i .bak '/Copyright/c\
# Copyright &copy; 2000-2019. The WeBWorK Project. https://github.com/openwebwork/webwork2\
' $1



#obtained by trial and error after much toil -- mostly error.
# this version works on a mac
# the space after -i might need to be removed for linux.
# produces $1.bak file

# use as 
# find . -name course.conf -exec /Volumes/WW_test/opt/webwork/courses/gage_course/fix_copyright.sh {} ';'