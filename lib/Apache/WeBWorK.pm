################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package Apache::WeBWorK;

=head1 NAME

Apache::WeBWorK - The WeBWorK dispatcher module.

=cut

use strict;
use warnings;
use Apache::Constants qw(:common REDIRECT);
use Apache::Request;
use WeBWorK::Authen;
use WeBWorK::Authz;
use WeBWorK::ContentGenerator::Login;
use WeBWorK::ContentGenerator::Hardcopy;
use WeBWorK::ContentGenerator::Problem;
use WeBWorK::ContentGenerator::ProblemSet;
use WeBWorK::ContentGenerator::ProblemSets;
use WeBWorK::ContentGenerator::Test;
use WeBWorK::CourseEnvironment;

# This module should be installed as a Handler for the location selected for
# WeBWorK on your webserver. Here is an example of a stanza that can be added
# to your httpd.conf file to achieve this:
#
# <IfModule mod_perl.c>
#     PerlFreshRestart On
#     <Location /modperl-sam>
#         SetHandler perl-script
#         PerlSetVar webwork_root /opt/webwork
#         <Perl>
#             use lib '/opt/webwork/lib';
#         </Perl>
#         PerlHandler Apache::WeBWorK
#     </Location>
# </IfModule>

sub handler() {
	my $r = Apache::Request->new(shift); # have to deal with unpredictable GET or POST data, and sift through it for the key.  So use Apache::Request
	
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
	
	# Create the @components array, which contains the path specified in the URL
	my($junk, @components) = split "/", $path_info;
	my $webwork_root = $r->dir_config('webwork_root'); # From a PerlSetVar in httpd.conf
	my $course = shift @components;
	
	# If no course was specified, phreak out.
	# Eventually, display a list of courses, or something.
	unless (defined $course) {
		return DECLINED;
	}
	
	# Try to get the course environment.
	my $course_env = eval {WeBWorK::CourseEnvironment->new($webwork_root, $course);};
	if ($@) { # If there was an error getting the requested course
		# TODO: display an error page.  For now, 404 it.
		warn $@;
		return DECLINED;
	}

	# Freak out if the requested course doesn't exist.  For now, this is just a
	# check to see if the course directory exists.
	if (!-e $course_env->{webworkDirs}->{courses} . "/$course") {
		return DECLINED;
	}
	
	### Begin dispatching ###
	
	# WeBWorK::Authen::verify erases the passwd field and sets the key field
	# if login is successful.
	if (!WeBWorK::Authen->new($r, $course_env)->verify) {
		return WeBWorK::ContentGenerator::Login->new($r, $course_env)->go;
	} else {
		# After we are authenticated, there are some things that need to be
		# sorted out, Authorization-wize, before we start dispatching to individual
		# content generators.
		my $effectiveUser = $r->param("effectiveUser") || "";
		my $user = $r->param("user");
		my $su_authorized = WeBWorK::Authz->new($r, $course_env)->hasPermissions($user, "become_student", $effectiveUser);
		# This hoary statement has the effect of forcing effectiveUser to equal user unless
		# the user is otherwise authorized.
		if (!($user ne $effectiveUser && $su_authorized) || !defined $effectiveUser) {
			$r->param("effectiveUser",$user);
		}
		
		my $arg = shift @components;
		if (!defined $arg) { # We want the list of problem sets
			return WeBWorK::ContentGenerator::ProblemSets->new($r, $course_env)->go;
		} elsif ($arg eq "hardcopy") {
			my $hardcopyArgument = shift @components || "";
			return WeBWorK::ContentGenerator::Hardcopy->new($r, $course_env)->go($hardcopyArgument);
		} elsif ($arg eq "prof") {
			# ***
		} elsif ($arg eq "prefs") {
			# ***
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
		
	}

	# If the dispatcher doesn't know any modules that want to handle
	# the current path, it'll claim that the path does not exist by
	# declining the request.
	return DECLINED;
}

1;
