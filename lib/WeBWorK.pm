################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK;

=head1 NAME

WeBWorK - Dispatch requests to the appropriate ContentGenerator.

=cut

use strict;
use warnings;
use Apache::Constants qw(:common REDIRECT DONE);
use Apache::Request;
use WeBWorK::Authen;
use WeBWorK::Authz;
use WeBWorK::ContentGenerator::Feedback;
use WeBWorK::ContentGenerator::GatewayQuiz;
use WeBWorK::ContentGenerator::Hardcopy;
use WeBWorK::ContentGenerator::Instructor::Assigner;
use WeBWorK::ContentGenerator::Instructor::Index;
use WeBWorK::ContentGenerator::Instructor::PGProblemEditor;
use WeBWorK::ContentGenerator::Instructor::ProblemList;
use WeBWorK::ContentGenerator::Instructor::ProblemSetEditor;
use WeBWorK::ContentGenerator::Instructor::ProblemSetList;
use WeBWorK::ContentGenerator::Instructor::UserList;
use WeBWorK::ContentGenerator::Instructor::SendMail;
use WeBWorK::ContentGenerator::Instructor::ShowAnswers;
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

#sub dispatch($) {
#	print STDERR "Executing &WeBWorK::dispatch\n";
#	return DECLINED;
#}
#1;
#__END__

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
	
	# Try to get the course environment.
	my $ce = eval {WeBWorK::CourseEnvironment->new($webwork_root, $urlRoot, $pg_root, $course);};
	if ($@) { # If there was an error getting the requested course
		die "Failed to read course environment for $course: $@";
	}
	
	# If no course was specified, redirect to the home URL
	unless (defined $course) {
		$r->header_out(Location => $ce->{webworkURLs}->{home});
		return REDIRECT;
	}
	
	# Freak out if the requested course doesn't exist.  For now, this is just a
	# check to see if the course directory exists.
	my $courseDir = $ce->{webworkDirs}->{courses} . "/$course";
	unless (-e $courseDir) {
		die "Course directory for $course ($courseDir) not found. Perhaps the course does not exist?";
	}
	
	# Bring up a connection to the database (for Authen/Authz, and eventually
	# to be passed to content generators, when we clean this file up).
	my $db = WeBWorK::DB->new($ce);
	
	### Begin dispatching ###
	
	#my $dispatchTimer = WeBWorK::Timing->new(__PACKAGE__."::dispatch");
	#$dispatchTimer->start;
	
	my $result;
	# WeBWorK::Authen::verify erases the passwd field and sets the key field
	# if login is successful.
	if (!WeBWorK::Authen->new($r, $ce, $db)->verify) {
		$result = WeBWorK::ContentGenerator::Login->new($r, $ce, $db)->go;
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
		} elsif ($arg eq "instructor") {
			my $instructorArgument = shift @components;
			if (!defined $instructorArgument) {
				$result = WeBWorK::ContentGenerator::Instructor::Index->new($r, $ce, $db)->go;
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
	
	return $result;
}

1;
