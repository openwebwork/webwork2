# Apache::WeBWorK - The WeBWorK dispatcher module
# Place something like the following in your Apache configuration to load the
# WeBWorK module and install it as a handler for the WeBWorK system

# PerlModule Apache::WeBWorK
# PerlRequire /path/to/webwork/conf/init.pl
# PerlSetVar webwork_root /path/to/webwork
# <Location /webwork>
#	SetHandler perl-script
#	PerlHandler Apache::WeBWorK
# </Location>

# In addition, you will have to edit init.pl in what should be obvious ways.

package Apache::WeBWorK;

use strict;
use Apache::Constants qw(:common REDIRECT);
use Apache::Request;
use WeBWorK::CourseEnvironment;
use WeBWorK::Authen;
use WeBWorK::ContentGenerator::Test;
use WeBWorK::ContentGenerator::Login;
use WeBWorK::ContentGenerator::ProblemSets;
use WeBWorK::ContentGenerator::ProblemSet;
use WeBWorK::ContentGenerator::Problem;

# Sets up the common environment needed for every subsystem and then dispatches
# the page request to the appropriate content generator.
sub handler() {
	my $r = Apache::Request->new(shift); # have to deal with unpredictable GET or POST data ,and sift through it for the key.  So use Apache::Request

	# This stuff is pretty much copied out of the O'Reilly mod_perl book.
	# It's for figuring out the basepath.  I may change this up if I
	# find a better way to do it.
	my $path_info = $r->path_info;
	my $path_translated = $r->lookup_uri($path_info)->filename;
	my $current_uri = $r->uri;
	my $args = $r->args;
	
	# If it's a valid WeBWorK URI, it ends in a /.  This is assumed
	# alllll over the place.
	unless (substr($current_uri,-1) eq '/') {
		$r->header_out(Location => "$current_uri/" . ($args ? "?$args" : ""));
		return REDIRECT;
	}
	
	return OK if $r->header_only;

	my($junk, @components) = split "/", $path_info;
	my $webwork_root = $r->dir_config('webwork_root'); # From a PerlSetVar in httpd.conf
	my $course = shift @components;
	
	# Try to get the course environment.
	my $course_env = eval {WeBWorK::CourseEnvironment->new($webwork_root, $course);};
	if ($@) { # If no course exists matching the requested course
		# TODO: display an error page.  For now, 404 it.
		warn $@;
		return DECLINED;
	}
	
	# WeBWorK::Authen::verify erases the passwd field and sets the key field
	# if login is successful.
	if (!WeBWorK::Authen->new($r, $course_env)->verify) {
		return WeBWorK::ContentGenerator::Login->new($r, $course_env)->go;
	} else {
		my $arg = shift @components;
		if (!defined $arg) { # We want the list of problem sets
			return WeBWorK::ContentGenerator::ProblemSets->new($r, $course_env)->go;
		} elsif ($arg eq "prof") {
			###
		} elsif ($arg eq "prefs") {
			###
		} elsif ($arg eq "test") {
			return WeBWorK::ContentGenerator::Test->new($r, $course_env)->go;
		} else { # We've got the name of a problem set.
			my $problem_set = $arg;
			my $ps_arg = shift @components;

			if (!defined $ps_arg) {
				# list the problems in the problem set
				return WeBWorK::ContentGenerator::ProblemSet->new($r, $course_env)->go($problem_set);
			} elsif ($ps_arg eq "hardcopy") {
				###
			}
			else {
				# We've got the name of a problem
				my $problem = $ps_arg;
				return WeBWorK::ContentGenerator::Problem->new($r, $course_env)->go($problem_set, $problem);
			}
		}
		
		if (1) {
			return WeBWorK::ContentGenerator::Test->new($r, $course_env)->go;
		}
	}

	# If the dispatcher doesn't know any modules that want to handle
	# the current path, it'll claim that the path does not exist by
	# declining the request.
	return DECLINED;
}

1;
