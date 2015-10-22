#!/bin/bash
#usage 
#   check_problems_in_dir.s  directory_name

echo "Checking problems in directory $1"
echo '' > "$WEBWORK_ROOT/DATA/bad_problems.txt"
echo "Results sent to" 
echo "$WEBWORK_ROOT/DATA/bad_problems.txt"
time find $1 -name "*.pg" -exec /Volumes/WW_test/opt/local/bin/perl $WEBWORK_ROOT/clients/checkProblem.pl {} ';'  #tail -f /Volumes/WW_test/opt/webwork/webwork2/DATA/bad_problems.txt;
echo "start search"
#tail -f "$WEBWORK_ROOT/DATA/bad_problems.txt"
echo "Time for  $1";
echo ""
echo ""
exit

