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
use WeBWorK::ContentGenerator::Feedback;
use WeBWorK::ContentGenerator::Login;
use WeBWorK::ContentGenerator::Logout;
use WeBWorK::ContentGenerator::Hardcopy;
use WeBWorK::ContentGenerator::Options;
use WeBWorK::ContentGenerator::Problem;
use WeBWorK::ContentGenerator::ProblemSet;
use WeBWorK::ContentGenerator::ProblemSets;
use WeBWorK::ContentGenerator::Professor;
use WeBWorK::ContentGenerator::Instructor;
use WeBWorK::ContentGenerator::Test;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;

# This module should be installed as a Handler for the location selected for
# WeBWorK on your webserver. Here is an example of a stanza that can be added
# to your httpd.conf file to achieve this:
#
# <IfModule mod_perl.c>
#   PerlFreshRestart On
#   <Location /webwork>
#     SetHandler perl-script
#     PerlHandler Apache::WeBWorK
#     PerlSetVar webwork_root /path/to/webwork-modperl
#     <Perl>
#       use lib '/path/to/webwork-modperl/lib';
#       use lib '/path/to/webwork-modperl/pglib';
#     </Perl>
#   </Location>
# </IfModule>

sub handler() {
	my $r = Apache::Request->new(shift); # have to deal with unpredictable GET or POST data, and sift through it for the key.  So use Apache::Request
	
	# This stuff is pretty much copied out of the O'Reilly mod_perl book.
	# It's for figuring out the basepath.  I may change this up if I
	# find a better way to do it.
	my $path_info = $r->path_info || "";
	my $current_uri = $r->uri;
	my $args = $r->args;
	
	$current_uri =~ m/^(.*)$path_info/;
	my $urlRoot = $1;
	
	# If it's a valid WeBWorK URI, it ends in a /.  This is assumed
	# alllll over the place.
	unless (substr($current_uri,-1) eq '/') {
		$r->header_out(Location => "$current_uri/" . ($args ? "?$args" : ""));
		return REDIRECT;
		# *** any post data gets lost here -- fix that.
	}
	
	# Create the @components array, which contains the path specified in the URL
	my($junk, @components) = split "/", $path_info;
	my $webwork_root = $r->dir_config('webwork_root'); # From a PerlSetVar in httpd.conf
	my $course = shift @components;
	
	# Try to get the course environment.
	my $ce = eval {WeBWorK::CourseEnvironment->new($webwork_root, $urlRoot, $course);};
	if ($@) { # If there was an error getting the requested course
		# TODO: display an error page.  For now, 404 it.
		warn $@;
		return DECLINED;
	}
	
	# If no course was specified, redirect to the home URL
	unless (defined $course) {
		$r->header_out(Location => $ce->{webworkURLs}->{home});
		return REDIRECT;
	}
	
	# Freak out if the requested course doesn't exist.  For now, this is just a
	# check to see if the course directory exists.
	if (!-e $ce->{webworkDirs}->{courses} . "/$course") {
		warn "Course directory for $course not found at "
			. $ce->{webworkDirs}->{courses} . "/$course" ."\n";
		return DECLINED;
	}
	
	# Bring up a connection to the database (for Authen/Authz, and eventually
	# to be passed to content generators, when we clean this file up).
	my $db = WeBWorK::DB->new($ce);
	
	### Begin dispatching ###
	
	# WeBWorK::Authen::verify erases the passwd field and sets the key field
	# if login is successful.
	if (!WeBWorK::Authen->new($r, $ce, $db)->verify) {
		return WeBWorK::ContentGenerator::Login->new($r, $ce, $db)->go;
	} else {
		# After we are authenticated, there are some things that need to be
		# sorted out, Authorization-wize, before we start dispatching to individual
		# content generators.
		my $user = $r->param("user");
		my $effectiveUser = $r->param("effectiveUser") || $user;
		my $su_authorized = WeBWorK::Authz->new($r, $ce, $db)->hasPermissions($user, "become_student", $effectiveUser);
		$effectiveUser = $user unless $su_authorized;
		$r->param("effectiveUser", $effectiveUser);
		
		my $arg = shift @components;
		if (!defined $arg) { # We want the list of problem sets
			return WeBWorK::ContentGenerator::ProblemSets->new($r, $ce, $db)->go;
		} elsif ($arg eq "hardcopy") {
			my $hardcopyArgument = shift @components;
			$hardcopyArgument = "" unless defined $hardcopyArgument;
			return WeBWorK::ContentGenerator::Hardcopy->new($r, $ce, $db)->go($hardcopyArgument);
		} elsif ($arg eq "instructor") {
			my $instructorArgument = shift @components;
			if (!defined $instructorArgument) {
				return WeBWorK::ContentGenerator::Instructor->new($r, $ce, $db)->go;
			} else {
			
			}
		} elsif ($arg eq "prof") {
			return WeBWorK::ContentGenerator::Professor->new($r, $ce, $db)->go;
		} elsif ($arg eq "options") {
			return WeBWorK::ContentGenerator::Options->new($r, $ce, $db)->go;
		} elsif ($arg eq "feedback") {
			return WeBWorK::ContentGenerator::Feedback->new($r, $ce, $db)->go;
		} elsif ($arg eq "logout") {
			return WeBWorK::ContentGenerator::Logout->new($r, $ce, $db)->go;
		} elsif ($arg eq "test") {
			return WeBWorK::ContentGenerator::Test->new($r, $ce, $db)->go;
		} else { # We've got the name of a problem set.
			my $problem_set = $arg;
			my $ps_arg = shift @components;

			if (!defined $ps_arg) {
				# list the problems in the problem set
				return WeBWorK::ContentGenerator::ProblemSet->new($r, $ce, $db)->go($problem_set);
			} else {
				# We've got the name of a problem
				my $problem = $ps_arg;
				return WeBWorK::ContentGenerator::Problem->new($r, $ce, $db)->go($problem_set, $problem);
			}
		}
		
	}
	
	# If the dispatcher doesn't know any modules that want to handle
	# the current path, it'll claim that the path does not exist by
	# declining the request.
	return DECLINED;
}

1;
