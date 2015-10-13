#usage 
#   check_problems_in_dir.s  directory_name
#cd $1 
echo "Checking problems in directory $1"
echo "Results sent to" 
echo "webwork2/DATA/bad_problems.txt";
find $1 -name "*.pg" -exec /Volumes/WW_test/opt/local/bin/perl $WEBWORK_ROOT/clients/checkProblem.pl {} ';' &
tail -f /Volumes/WW_test/opt/webwork/webwork2/DATA/bad_problems.txt


