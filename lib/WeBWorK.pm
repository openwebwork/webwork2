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

my $timingON = 0;

use strict;
use warnings;
use Apache::Constants qw(:common REDIRECT DONE);
use Apache::Request;
use WeBWorK::Authen;
use WeBWorK::Authz;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Timing;
use WeBWorK::Upload;
use WeBWorK::Utils qw(runtime_use);

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

=item Capture any uploads

Before checking authentication, we store any uploads sent by the client
and replace them with parameters referencing the stored uploads.

=cut

	my @uploads = $r->upload;
	foreach my $u (@uploads) {
		# make sure it's a "real" upload
		next unless $u->filename;
		
		# store the upload
		my $upload = WeBWorK::Upload->store($u,
			dir => $ce->{webworkDirs}->{uploadCache}
		);
		
		# store the upload ID and hash in the file upload field
		my $id = $upload->id;
		my $hash = $upload->hash;
		$r->param($u->name => "$id $hash");
	}

=item Check authentication

Use C<WeBWorK::Authen> to verify that the remote user has authenticated.

See also L<WeBWorK::Authen>.

=cut

	### Begin dispatching ###
	
	my $contentGenerator = "";
	my @arguments = ();
		
	# WeBWorK::Authen::verify erases the passwd field and sets the key field
	# if login is successful.
	if (!WeBWorK::Authen->new($r, $ce, $db)->verify) {
		$contentGenerator = "WeBWorK::ContentGenerator::Login";
		@arguments = ();
	}
	else {

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
		my $authz = WeBWorK::Authz->new($r, $ce, $db);
		my $su_authorized = $authz->hasPermissions($user, "become_student", $effectiveUser);
		$effectiveUser = $user unless $su_authorized;
		$r->param("effectiveUser", $effectiveUser);

=item Determine the appropriate subclass of C<WeBWorK::ContentGenerator> to call based on the URI.

The dispatcher implements a virtual heirarchy that looks like this:

 $courseID ($courseID) - list of sets
 	hardcopy (Hardcopy Generator) - generate hardcopy for user/set pairs
 	options (User Options) - change email address and password
 	feedback (Feedback) - send feedback to professor via email
 	logout (Logout) - expire session and erase authentication tokens
 	test (Test) - display request information
 	quiz_mode (Quiz) - "quiz" containing all problems from a set
 	instructor (Instructor Tools) - main menu for instructor tools
 		add_users (Add Users) - to be removed
 		scoring (Scoring Tools) - generate scoring files for problem sets
 		scoringDownload - send a scoring file to the client
  		scoring_totals - ???
		users (Users) - view/edit users
 			$userID ($userID) - user detail for given user
 				sets (Assigned Sets) - view/edit sets assigned to given user
 		sets (Sets) - list of sets, add new sets, delete existing sets
 			$setID - view/edit the given set
 				problems (Problems) - view/edit problems in the given set
 					$problemID - this is where the pg problem editor SHOULD be
 				users (Users Assigned) - view/edit users to whom the given set is assigned
 		pgProblemEditor (Problem Source) - edit the source of a problem
 		send_mail (Mail Merge) - send mail to users in course
 		show_answers (Answers Submitted) - show submitted answers
 		stats (Statistics) - show statistics
 		files (File Transfer) - transfer files to/from the client
 	$setID ($setID) - list of problems in the given set
 		$problemID ($problemID) - interactive display of problem

=cut

		my $arg = shift @components;
		if (not defined $arg) { # We want the list of problem sets
			$contentGenerator = "WeBWorK::ContentGenerator::ProblemSets";
			@arguments = ();
		}
		elsif ($arg eq "hardcopy") {
			my $setID = shift @components;
			$contentGenerator = "WeBWorK::ContentGenerator::Hardcopy";
			@arguments = ($setID);
		}
		elsif ($arg eq "options") {
			$contentGenerator = "WeBWorK::ContentGenerator::Options";
			@arguments = ();
		}
		elsif ($arg eq "feedback") {
			$contentGenerator = "WeBWorK::ContentGenerator::Feedback";
			@arguments = ();
		}
		elsif ($arg eq "logout") {
			$contentGenerator = "WeBWorK::ContentGenerator::Logout";
			@arguments = ();
		}
		elsif ($arg eq "test") {
			$contentGenerator = "WeBWorK::ContentGenerator::Test";
			@arguments = ();
		}
		elsif ($arg eq "quiz_mode" ) {
			$contentGenerator = "WeBWorK::ContentGenerator::GatewayQuiz";
			@arguments = @components;
		}
		elsif ($arg eq "instructor") {
			my $instructorArgument = shift @components;
			
			if (not defined $instructorArgument) {
				$contentGenerator = "WeBWorK::ContentGenerator::Instructor::Index";
				@arguments = ();
			}
			elsif ($instructorArgument eq "add_users") {
				$contentGenerator = "WeBWorK::ContentGenerator::Instructor::AddUsers";
				@arguments = ();
			}
			elsif ($instructorArgument eq "scoring") {
				$contentGenerator = "WeBWorK::ContentGenerator::Instructor::Scoring";
				@arguments = ();
			}
# 			elsif ($instructorArgument eq "scoring_totals") {
# 				$contentGenerator = "WeBWorK::ContentGenerator::Instructor::ScoringTotals";
# 				@arguments = ();
# 			}
			elsif ($instructorArgument eq "scoringDownload") {
				$contentGenerator = "WeBWorK::ContentGenerator::Instructor::ScoringDownload";
				@arguments = ();
			}
			elsif ($instructorArgument eq "users") {
				my $userID = shift @components;
				
				if (defined $userID) {
					my $userArg = shift @components;
					if (defined $userArg) {
						if ($userArg eq "sets") {
							$contentGenerator = "WeBWorK::ContentGenerator::Instructor::SetsAssignedToUser";
							@arguments = ($userID);
						}
					}
					else {
						$contentGenerator = "WeBWorK::ContentGenerator::Instructor::UserDetail";
						@arguments = ($userID);
					}
				}
				else {
					$contentGenerator = "WeBWorK::ContentGenerator::Instructor::UserList";
					@arguments = ();
				}
			}
			elsif ($instructorArgument eq "sets") {
				my $setID = shift @components;
				
				if (defined $setID) {
					my $setArg = shift @components;
					
					if (defined $setArg) {
						if ($setArg eq "problems") {
							$contentGenerator = "WeBWorK::ContentGenerator::Instructor::ProblemList";
							@arguments = ($setID);
						}
						elsif ($setArg eq "users") {
							$contentGenerator = "WeBWorK::ContentGenerator::Instructor::Assigner";
							@arguments = ($setID);
						}
					}
					else {
						$contentGenerator = "WeBWorK::ContentGenerator::Instructor::ProblemSetEditor";
						@arguments = ($setID);
					}
				}
				else {
					$contentGenerator = "WeBWorK::ContentGenerator::Instructor::ProblemSetList";
					@arguments = ();

				}
			}
			elsif ($instructorArgument eq "pgProblemEditor") {
				$contentGenerator = "WeBWorK::ContentGenerator::Instructor::PGProblemEditor";
				@arguments = @components;
			}
			elsif ($instructorArgument eq "send_mail") {
				$contentGenerator = "WeBWorK::ContentGenerator::Instructor::SendMail";
				@arguments = @components;
			}
			elsif ($instructorArgument eq "show_answers") {
				$contentGenerator = "WeBWorK::ContentGenerator::Instructor::ShowAnswers";
				@arguments = @components;
			}
			elsif ($instructorArgument eq "stats") {
				$contentGenerator = "WeBWorK::ContentGenerator::Instructor::Stats";
				@arguments = @components;
			}
			elsif ($instructorArgument eq "files") {
				$contentGenerator = "WeBWorK::ContentGenerator::Instructor::FileXfer";
				@arguments = @components;
			}
		}
		else {
			# $arg is a set ID
			my $setID = $arg;
			my $problemID = shift @components;
			
			if (defined $problemID) {
				$contentGenerator = "WeBWorK::ContentGenerator::Problem";
				@arguments = ($setID, $problemID);
			}
			else {
				$contentGenerator = "WeBWorK::ContentGenerator::ProblemSet";
				@arguments = ($setID);
			}
		}
	}

=item Call the selected content generator

Instantiate the selected subclass of content generator and call its C<&go> method. Store the result.

=cut

	my $result;
	if ($contentGenerator) {
		runtime_use($contentGenerator);
		my $cg = $contentGenerator->new($r, $ce, $db);
		
		$WeBWorK::timer = WeBWorK::Timing->new("${contentGenerator}::go(@arguments)") if $timingON == 1;
		$WeBWorK::timer->start if $timingON == 1;
		
		$result = $cg->go(@arguments);
		
		$WeBWorK::timer->stop if $timingON == 1;
		$WeBWorK::timer->save if $timingON == 1;
	} else {
		$result = NOT_FOUND;
	}

=item Return the result of calling the content generator

The return value of the content generator's C<&go> function is returned.

=cut

	return $result;
}

=back

=head1 AUTHOR

Written by Dennis Lambe, malsyned at math.rochester.edu. Modified by Sam
Hathaway, sh002i at math.rochester.edu.

=cut

1;
