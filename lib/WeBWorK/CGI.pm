# choose one

# standard CGI -- will not work properly with apache2

use CGI qw(*ul *li escapeHTML);

# there are 2 CGI substitutes for apache2:

# below is a front end for CGIeasytags that imitates some of the 
# shortcuts of CGI. 
# It is probably not ready for prime time.
# It only concatenates arguments if the first 
# argument is a hash (possibly empty) of params.
# This enforces uniformity, but it is also annoying
# The error reporting however is fairly good.
# It is shorter than CGI, but it may not be easy to maintain
# if it seems desirable to use it then the code should be cleaned up
# There are many places where code can be factored out to improve speed
# increase reliability and readability

#use WeBWorK::CGIeasytags;

# below is a subclass of CGI that forces CGI to use the WeBWorK Request 
# object when finding "sticky" parameters

#use WeBWorK::CGIParamShim;
1;
