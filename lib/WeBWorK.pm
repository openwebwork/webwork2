################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK;

=head1 NAME

WeBWorK - Dispatch requests to the appropriate content generator.

=head1 SYNOPSIS

 my $r = Apache->request;
 my $result = eval { WeBWorK::dispatch($r) };
 die "something bad happened: $@" if $@;

=head1 DESCRIPTION

C<WeBWorK> is the dispatcher for the WeBWorK system. Given an Apache request
object, it performs authentication and determines which subclass of
C<WeBWorK::ContentGenerator> to call.

=head1 REQUEST FORMAT

 FIXME: write this part
 summary: the URI controls 

=cut

BEGIN { $main::VERSION = "2.0"; }

use strict;
use warnings;
use Apache::Constants qw(:common REDIRECT DONE);
use Apache::Request;
use WeBWorK::Authen;
use WeBWorK::Authz;
use WeBWorK::ContentGenerator::Feedback;
use WeBWorK::ContentGenerator::GatewayQuiz;
use WeBWorK::ContentGenerator::Hardcopy;
use WeBWorK::ContentGenerator::Instructor::AddUsers;
use WeBWorK::ContentGenerator::Instructor::Assigner;
use WeBWorK::ContentGenerator::Instructor::Index;
#use WeBWorK::ContentGenerator::Instructor::Index2;
use WeBWorK::ContentGenerator::Instructor::PGProblemEditor;
use WeBWorK::ContentGenerator::Instructor::ProblemList;
use WeBWorK::ContentGenerator::Instructor::ProblemSetEditor;
use WeBWorK::ContentGenerator::Instructor::ProblemSetList;
use WeBWorK::ContentGenerator::Instructor::UserList;
use WeBWorK::ContentGenerator::Instructor::SendMail;
use WeBWorK::ContentGenerator::Instructor::ShowAnswers;
use WeBWorK::ContentGenerator::Instructor::Scoring;
use WeBWorK::ContentGenerator::Instructor::ScoringDownload;
use WeBWorK::ContentGenerator::Instructor::ScoringTotals;
use WeBWorK::ContentGenerator::Instructor::Stats;
use WeBWorK::ContentGenerator::Login;
use WeBWorK::ContentGenerator::Logout;
use WeBWorK::ContentGenerator::Options;
use WeBWorK::ContentGenerator::Problem;
use WeBWorK::ContentGenerator::ProblemSet;
use WeBWorK::ContentGenerator::ProblemSets;
use WeBWorK::ContentGenerator::Test;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Timing;

=head1 THE C<&dispatch> FUNCTION

The C<&dispatch> function takes an Apache request object (REQUEST) and returns
an apache status code. Below is an overview of its operation:

=over

=cut

sub dispatch($) {
	my ($apache) = @_;
	my $r = Apache::Request->new($apache);
		# have to deal with unpredictable GET or POST data, and sift
		# through it for the key. So use Apache::Request
	
	# This stuff is pretty much copied out of the O'Reilly mod_perl book.
	# It's for figuring out the basepath. I may change this up if I find a
	# better way to do it.
	my $path_info = $r->path_info || "";
	$path_info =~ s!/+!/!g; # strip multiple forward slashes
	my $current_uri = $r->uri;
	my $args = $r->args;
	
	my ($urlRoot) = $current_uri =~ m/^(.*)$path_info/;

=item Ensure that the URI ends with a "/"

Parts of WeBWorK assume that the current URI of a request ends with a "/". If
this is not the case, a redirection is issued to add the "/". This action will
discard any POST data associated with the request, so it is essential that all
POST requests include a "/" at the end of the URI.

=cut
	
	# If it's a valid WeBWorK URI, it ends in a /.  This is assumed
	# alllll over the place.
	unless (substr($current_uri,-1) eq '/') {
		$r->header_out(Location => "$current_uri/" . ($args ? "?$args" : ""));
		return REDIRECT;
		# *** any post data gets lost here -- fix that.
		# (actually, it's not a problem, since all URLs generated
		# from within the system have trailing slashes, and we don't  
		# need POST data from outside the system anyway!)
	}
	
	# Create the @components array, which contains the path specified in the URL
	my($junk, @components) = split "/", $path_info;
	my $webwork_root = $r->dir_config('webwork_root'); # From a PerlSetVar in httpd.conf
	my $pg_root = $r->dir_config('pg_root'); # From a PerlSetVar in httpd.conf
	my $course = shift @components;

=item Read the course environment

C<WeBWorK::CourseEnvironment> is used to read the F<global.conf> configuration
file. If a course name was given in the request's URI, it is passed to
C<WeBWorK::CourseEnvironment>. In this case, the course-specific configuration
file (usually F<course.conf>) is also read by C<WeBWorK::CourseEnvironment> at
this point.

See also L<WeBWorK::CourseEnvironment>.

=cut
	
	# Try to get the course environment.
	my $ce = eval {WeBWorK::CourseEnvironment->new($webwork_root, $urlRoot, $pg_root, $course);};
	if ($@) { # If there was an error getting the requested course
		die "Failed to read course environment for $course: $@";
	}

=item If no course was given, go to the site home page

If the URI did not include the name of a course, a redirection is issued to the
site home page, given but the course environemnt variable
C<$ce-E<gt>{webworkURLs}-E<gt>{home}>.

=cut
	
	# If no course was specified, redirect to the home URL
	unless (defined $course) {
		$r->header_out(Location => $ce->{webworkURLs}->{home});
		return REDIRECT;
	}

=item If the given course does not exist, fail

If the URI did include the name of a course, but the course directory was not
found, an exception is thrown.

=cut
	
	# Freak out if the requested course doesn't exist.  For now, this is just a
	# check to see if the course directory exists.
	my $courseDir = $ce->{webworkDirs}->{courses} . "/$course";
	unless (-e $courseDir) {
		die "Course directory for $course ($courseDir) not found. Perhaps the course does not exist?";
	}

=item Initialize the database system

A C<WeBWorK::DB> object is created from the current course environment.

See also L<WeBWorK::DB>.

=cut
	
	# Bring up a connection to the database (for Authen/Authz, and eventually
	# to be passed to content generators, when we clean this file up).
	my $db = WeBWorK::DB->new($ce);
	
	### Begin dispatching ###
	
	#my $dispatchTimer = WeBWorK::Timing->new(__PACKAGE__."::dispatch");
	#$dispatchTimer->start;
	
	my $result;

=item Check authentication

Use C<WeBWorK::Authen> to verify that the remote user has authenticated.

See also L<WeBWorK::Authen>.

=cut
	
	# WeBWorK::Authen::verify erases the passwd field and sets the key field
	# if login is successful.
	if (!WeBWorK::Authen->new($r, $ce, $db)->verify) {
		$result = WeBWorK::ContentGenerator::Login->new($r, $ce, $db)->go;
	} else {

=item Determine if the user is allowed to set C<effectiveUser>

Use C<WeBWorK::Authz> to determine if the user is allowed to set
C<effectiveUser>. If so, set it to the requested value (or set it to the real
user name if no value is supplied). If not, set it to the real user name.

See also L<WeBWorK::Authz>.

=cut
	
		# After we are authenticated, there are some things that need to be
		# sorted out, Authorization-wize, before we start dispatching to individual
		# content generators.
		my $user = $r->param("user");
		my $effectiveUser = $r->param("effectiveUser") || $user;
		my $su_authorized = WeBWorK::Authz->new($r, $ce, $db)->hasPermissions($user, "become_student", $effectiveUser);
		$effectiveUser = $user unless $su_authorized;
		$r->param("effectiveUser", $effectiveUser);

=item Create and call the appropriate subclass of C<WeBWorK::ContentGenerator> based on the URI.

The dispatcher logic currently looks like this:

 FIXME: write this part
 for now, consult the code

=cut
		
		my $arg = shift @components;
		if (!defined $arg) { # We want the list of problem sets
			$result = WeBWorK::ContentGenerator::ProblemSets->new($r, $ce, $db)->go;
		} elsif ($arg eq "hardcopy") {
			
			my $hardcopyArgument = shift @components;
			$hardcopyArgument = "" unless defined $hardcopyArgument;
			$WeBWorK::timer1 = WeBWorK::Timing->new("hardcopy: $hardcopyArgument");
			$WeBWorK::timer1->start;
			
			my $result = WeBWorK::ContentGenerator::Hardcopy->new($r, $ce, $db)->go($hardcopyArgument);
			$WeBWorK::timer1 ->stop;
			$WeBWorK::timer1 ->save;
			return $result;
		} elsif ($arg eq "instructor2") {  
			my $instructorArgument = shift @components;
			if (!defined $instructorArgument) {
				$result = WeBWorK::ContentGenerator::Instructor::Index2->new($r, $ce, $db)->go;
			}
		} elsif ($arg eq "instructor") {
			my $instructorArgument = shift @components;
			if (!defined $instructorArgument) {
				$result = WeBWorK::ContentGenerator::Instructor::Index->new($r, $ce, $db)->go;
			} elsif ($instructorArgument eq "scoring") {
				$result = WeBWorK::ContentGenerator::Instructor::Scoring->new($r, $ce, $db)->go; #FIXME!!!!
			} elsif ($instructorArgument eq "add_users") {
				$result = WeBWorK::ContentGenerator::Instructor::AddUsers->new($r, $ce, $db)->go; #FIXME!!!!
			} elsif ($instructorArgument eq "scoringDownload") {
				$result = WeBWorK::ContentGenerator::Instructor::ScoringDownload->new($r, $ce, $db)->go;
			} elsif ($instructorArgument eq "scoring_totals") {
				$result = WeBWorK::ContentGenerator::Instructor::ScoringTotals->new($r, $ce, $db)->go;
			} elsif ($instructorArgument eq "users") {
				$result = WeBWorK::ContentGenerator::Instructor::UserList->new($r, $ce, $db)->go;
			} elsif ($instructorArgument eq "sets") {
				my $setID = shift @components;
				if (defined $setID) {
					my $setArg = shift @components;
					if (!defined $setArg) {
						$result = WeBWorK::ContentGenerator::Instructor::ProblemSetEditor->new($r, $ce, $db)->go($setID);
					} elsif ($setArg eq "problems") {
						$result = WeBWorK::ContentGenerator::Instructor::ProblemList->new($r, $ce, $db)->go($setID);
					} elsif ($setArg eq "users") {
						$result = WeBWorK::ContentGenerator::Instructor::Assigner->new($r, $ce, $db)->go($setID);
					}
				} else {
					$result = WeBWorK::ContentGenerator::Instructor::ProblemSetList->new($r, $ce, $db)->go;
				}
			} elsif ($instructorArgument eq "pgProblemEditor") {
				$result = WeBWorK::ContentGenerator::Instructor::PGProblemEditor->new($r, $ce, $db)->go(@components);
			} elsif ($instructorArgument eq "send_mail") {
				$result = WeBWorK::ContentGenerator::Instructor::SendMail->new($r, $ce, $db)->go(@components);
			} elsif ($instructorArgument eq "show_answers") {
				$result = WeBWorK::ContentGenerator::Instructor::ShowAnswers->new($r, $ce, $db)->go(@components);
			} elsif ($instructorArgument eq "stats") {
				$result = WeBWorK::ContentGenerator::Instructor::Stats->new($r, $ce, $db)->go(@components);
			}
		} elsif ($arg eq "options") {
			$result = WeBWorK::ContentGenerator::Options->new($r, $ce, $db)->go;
		} elsif ($arg eq "feedback") {
			$result = WeBWorK::ContentGenerator::Feedback->new($r, $ce, $db)->go;
		} elsif ($arg eq "logout") {
			$result = WeBWorK::ContentGenerator::Logout->new($r, $ce, $db)->go;
		} elsif ($arg eq "test") {
			$result = WeBWorK::ContentGenerator::Test->new($r, $ce, $db)->go;
		} elsif ($arg eq "quiz_mode" ) {
			# Gateway quiz capability -- very similar to problem set (initially)
			$result = WeBWorK::ContentGenerator::GatewayQuiz->new($r, $ce, $db)->go(@components);
		} else { # We've got the name of a problem set.
			my $problem_set = $arg;
			my $ps_arg = shift @components;

			if (!defined $ps_arg) {
				# list the problems in the problem set
				$WeBWorK::timer0 = WeBWorK::Timing->new("Problem $course:$problem_set");
				$WeBWorK::timer0->start;
				$result = WeBWorK::ContentGenerator::ProblemSet->new($r, $ce, $db)->go($problem_set);
				$WeBWorK::timer0->continue("problem set listing is done");
				$WeBWorK::timer0->stop;
				$WeBWorK::timer0->save;
			} else {
				# We've got the name of a problem
				my $problem = $ps_arg;

				$WeBWorK::timer0 = WeBWorK::Timing->new("Problem $course:$problem_set/$problem");
				$WeBWorK::timer0->start;
#				my $pid = fork();
#				if ($pid) {
#					wait;
#				} else {
					my $result = WeBWorK::ContentGenerator::Problem->new($r, $ce, $db)->go($problem_set, $problem);
#					$WeBWorK::timer0->continue("Exiting child process");
#					#$WeBWorK::timer0->stop;
#				    #$WeBWorK::timer0->save;
#					eval{ APACHE::exit(0);} || warn "Error in leaving child |$@|";
#					#  We REALLY REALLY want this grandchild to exit. But not the child.  How to do this
#					# cleanly???? FIXME
#				}
				$WeBWorK::timer0->continue("Problem done)");
				$WeBWorK::timer0->stop;
				$WeBWorK::timer0->save;
				return $result;


			}
		}
	}
	
	#$dispatchTimer->stop;

=item Return the result of calling the content generator

The return value of the content generator's C<&go> function is returned.

=cut
	
	return $result;
}

=back

=head1 AUTHOR

Written by Dennis Lambe, malsyned at math.rochester.edu.

=cut

1;
