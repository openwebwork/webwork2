################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK.pm,v 1.49 2004/02/21 10:15:58 toenail Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
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


my $timingON = 1;

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

=item If no course was given, load the Home ContentGenerator

If the URI did not include the name of a course, we load the Home
ContentGenerator.

=cut

	# If no course was specified, we 
	unless (defined $course) {
		my $contentGenerator = "WeBWorK::ContentGenerator::Home";
		
		runtime_use($contentGenerator);
		my $cg = $contentGenerator->new($r, $ce, undef);
		my $result = $cg->go();
		return $result;
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
	my $db = WeBWorK::DB->new($ce->{dbLayout});

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
 	quiz_mode (Quiz) - "quiz" containing all problems from a set
 	instructor (Instructor Tools) - main menu for instructor tools
 		add_users (Add Users) - add users to user list
 		assigner (Set Assigner) - assign sets to users
 		scoring (Scoring Tools) - generate scoring files for problem sets
 		scoringDownload - send a scoring file to the client
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
		#elsif ($arg eq "test") {
		#	$contentGenerator = "WeBWorK::ContentGenerator::Test";
		#	@arguments = ();
		#}
		elsif ($arg eq "quiz_mode" ) {
			$contentGenerator = "WeBWorK::ContentGenerator::GatewayQuiz";
			@arguments = @components;
	    }
	    elsif ($arg eq "equation" ) {
	    	$contentGenerator = "WeBWorK::ContentGenerator::EquationDisplay";
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
			elsif ($instructorArgument eq "assigner") {
				$contentGenerator = "WeBWorK::ContentGenerator::Instructor::Assigner";
				@arguments = ();
			}
			elsif ($instructorArgument eq "scoring") {
				$contentGenerator = "WeBWorK::ContentGenerator::Instructor::Scoring";
				@arguments = ();
			}
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
							$contentGenerator = "WeBWorK::ContentGenerator::Instructor::UsersAssignedToSet";
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

			# check that the set is valid
			if (grep /$setID/, $db->listUserSets($effectiveUser)) {
				if (defined $problemID) {
					# check that the problem is valid for this set
					if (grep /$problemID/, $db->listUserProblems($effectiveUser, $setID)) {
						$contentGenerator = "WeBWorK::ContentGenerator::Problem";
						@arguments = ($setID, $problemID);
					}
					else {
						$contentGenerator = "WeBWorK::ContentGenerator::Error";
						$r->param("set", $setID);
						$r->param("problem", $problemID);
						$r->param("error", "Problem $problemID is not a valid problem in set $setID");
						$r->param("msg", "The problem number ($problemID) entered in the URL in your web browser does not seem to be a valid problem for the current set ($setID).  Please check to make sure that the problem number was entered correctly.  If you believe this error was generated mistakenly, please report it to your professor.  You can view a list of sets by clicking on the link \"Problem Sets\" on the left.");
						@arguments = ($setID);
					}
				}
				else {
					$contentGenerator = "WeBWorK::ContentGenerator::ProblemSet";
					@arguments = ($setID);
				}

			} 
			else {
				$contentGenerator = "WeBWorK::ContentGenerator::Error";
				$r->param("set", $setID);
				$r->param("problem", $problemID) if (defined $problemID);
				$r->param("error", "$setID is not a valid set");
				$r->param("msg", "The set ($setID) entered in the URL in your web browser does not seem to be a valid set for the current user.  Please check to make sure that the set was entered correctly.  If you believe this error was generated mistakenly, please report it to your professor.");
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
		@arguments = () unless @arguments;
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

=head1 THE C<&dispatch_new> FUNCTION

=cut

use WeBWorK::Request;
use WeBWorK::URLPath;

use constant AUTHEN_MODULE => "WeBWorK::ContentGenerator::Login";

sub debug(@) { print STDERR "dispatch_new: ", join("", @_) };

sub dispatch_new($) {
	my ($apache) = @_;
	my $r = new WeBWorK::Request $apache;
	
	my $method = $r->method;
	my $location = $r->location;
	my $uri = $r->uri;
	my $path_info = $r->path_info | "";
	my $args = $r->args || "";
	my $webwork_root = $r->dir_config("webwork_root");
	my $pg_root = $r->dir_config("pg_root");
	
	#$r->send_http_header("text/html");
	
	#print CGI::start_pre();
	
	debug("Hi, I'm the new dispatcher!\n");
	debug(("-" x 80) . "\n");
	
	debug("Okay, I got some basic information:\n");
	debug("The apache location is $location\n");
	debug("The request method is $method\n");
	debug("The URI is $uri\n");
	debug("The path-info is $path_info\n");
	debug("The argument string is $args\n");
	debug("The WeBWorK root directory is $webwork_root\n");
	debug("The PG root directory is $pg_root\n");
	debug(("-" x 80) . "\n");
	
	debug("The first thing we need to do is munge the path a little:\n");
	
	my ($path) = $uri =~ m/$location(.*)/;
	$path = "/" if $path eq ""; # no path at all
	
	debug("We can't trust the path-info, so we make our own path.\n");
	debug("path-info claims: $path_info\n");
	debug("but it's really: $path\n");
	debug("(if it's empty, we set it to \"/\".)\n");
	
	$path =~ s|/+|/|g;
	debug("...and here it is without repeated slashes: $path\n");
	
	# lookbehind assertion for "not a slash"
	# matches the boundary after the last char
	$path =~ s|(?<=[^/])$|/|;
	debug("...and here it is with a trailing slash: $path\n");
	
	debug(("-" x 80) . "\n");
	
	debug("Now we need to look at the path a little to figure out where we are\n");
	
	debug("-------------------- call to WeBWorK::URLPath::newFromPath\n");
	my $urlPath = newFromPath WeBWorK::URLPath $path;
	debug("-------------------- call to WeBWorK::URLPath::newFromPath\n");
	
	unless ($urlPath) {
		debug("This path is invalid... see you later!\n");
		return DECLINED;
	}
	
	my $displayModule = $urlPath->module;
	my %displayArgs = $urlPath->args;
	
	debug("The display module for this path is: $displayModule\n");
	debug("...and here are the arguments we'll pass to it:\n");
	foreach my $key (keys %displayArgs) {
		debug("\t$key => $displayArgs{$key}\n");
	}
	
	unless ($displayModule) {
		debug("The display module is empty, so we can DECLINE here.\n");
		return DECLINED;
	}
	
	my $selfPath = $urlPath->path;
	my $parent = $urlPath->parent;
	my $parentPath = $parent ? $parent->path : "<no parent>";
	
	debug("Reconstructing the original path gets us: $selfPath\n");
	debug("And we can generate the path to our parent, too: $parentPath\n");
	debug("(We could also figure out who our children are, but we'd need to supply additional arguments.)\n");
	debug(("-" x 80) . "\n");
	
	debug("Now we want to look at the parameters we got.\n");
	
	debug("The raw params:\n");
	foreach my $key ($r->param) {
		debug("\t$key\n");
		debug("\t\t$_\n") foreach $r->param($key);
	}
	
	mungeParams($r);
	
	debug("The munged params:\n");
	foreach my $key ($r->param) {
		debug("\t$key\n");
		debug("\t\t$_\n") foreach $r->param($key);
	}
	
	debug(("-" x 80) . "\n");
	
	debug("We need to get a course environment (with or without a courseID!)\n");
	my $ce = new WeBWorK::CourseEnvironment($webwork_root, $location, $pg_root, $displayArgs{courseID});
	debug("Here's the course environment: $ce\n");
	
	# FIXME: add upload handling here!
	
	my ($db, $authz);
	
	if ($displayArgs{courseID}) {
		debug("We got a courseID from the URLPath, now we can do some stuff:\n");
		debug("...we can create a database object...\n");
		$db = new WeBWorK::DB($ce->{dbLayout});
		debug("(here's the DB handle: $db)\n");
		
		debug("...and we can authenticate the remote user...\n");
		my $authen = new WeBWorK::Authen $r, $ce, $db;
		my $authenOK = $authen->verify;
		if ($authenOK) {
			debug("Hi, ", $r->param("user"), ", glad you made it.\n");
			
			debug("Authentication succeeded, so it makes sense to create an authz object...\n");
			$authz = new WeBWorK::Authz $r, $ce, $db;
			debug("(here's the authz object: $authz)\n");
			
			debug("Now we deal with the effective user:\n");
			my $userID = $r->param("user");
			my $eUserID = $r->param("effectiveUser") || $userID;
			debug("userID=$userID eUserID=$eUserID\n");
			my $su_authorized = $authz->hasPermissions($userID, "become_student", $eUserID);
			if ($su_authorized) {
				debug("Ok, looks like you're is allowed to become $eUserID. Whoopie!\n");
			} else {
				debug("Uh oh, you're isn't allowed to become $eUserID. Nice try!\n");
				$eUserID = $userID;
			}
			$r->param("effectiveUser" => $eUserID);
		} else {
			debug("Bad news: authentication failed!\n");
			$displayModule = AUTHEN_MODULE;
			debug("set displayModule to $displayModule\n");
		}
	}
	
	debug("Now we add \$ce, \$db, \$authz, and \$urlPath to the WeBWorK::Request object.\n");
	$r->ce($ce);
	$r->db($db);
	$r->authz($authz);
	$r->urlpath($urlPath);
	
	debug(("-" x 80) . "\n");
	debug("Finally, we'll load the display module...\n");
	
	runtime_use($displayModule);
	
	debug("...instantiate it...\n");
	
	# FIXME: change ContentGenerator interface to use WeBWorK::Request
	my $instance = $displayModule->new($r);
	
	debug("...and call it:\n");
	debug("-------------------- call to ${displayModule}::go\n");
	#print CGI::end_pre();
	
	my $result = $instance->go();
	
	#print CGI::start_pre();
	debug("-------------------- call to ${displayModule}::go\n");
	#print CGI::end_pre();
	
	debug("returning result: $result\n");
	
	return $result;
}

sub mungeParams {
	my ($r) = @_;
	
	my @paramQueue;
	
	# remove all the params from the request, and store them in the param queue
	foreach my $key ($r->param) {
		push @paramQueue, [ $key => [ $r->param($key) ] ];
		$r->parms->unset($key)
	}
	
	# exhaust the param queue, decoding encoded params
	while (@paramQueue) {
		my ($key, $values) = @{ shift @paramQueue };
		
		if ($key =~ m/\,/) {
			# we have multiple params encoded in a single param
			# split them up and add them to the end of the queue
			push @paramQueue, map { [ $_, $values ] } split m/\,/, $key;
		} elsif ($key =~ m/\:/) {
			# we have a whole param encoded in a key
			# split it up and add it to the end of the queue
			my ($newKey, $newValue) = split m/\:/, $key;
			push @paramQueue, [ $newKey, [ $newValue ] ];
		} else {
			# this is a "normal" param
			# add it to the param list
			if (defined $r->param($key)) {
				# the param already exists -- append the values we have
				$r->param($key => [ $r->param($key), @$values ]);
			} else {
				# the param doesn't exist -- create it with the values we have
				$r->param($key => $values);
			}
		}
	}
}


=head1 AUTHOR

Written by Dennis Lambe, malsyned at math.rochester.edu. Modified by Sam
Hathaway, sh002i at math.rochester.edu.

=cut

1;
