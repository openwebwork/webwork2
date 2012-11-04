################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK.pm,v 1.104 2010/05/15 18:44:26 gage Exp $
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

=cut

BEGIN { $main::VERSION = "2.4.9"; }

use strict;
use warnings;
use Time::HiRes qw/time/;
use WeBWorK::Localize;
# load WeBWorK::Constants before anything else
# this sets package variables in several packages
use WeBWorK::Constants;

use WeBWorK::Authen;
use WeBWorK::Authz;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Debug;
use WeBWorK::Request;
use WeBWorK::Upload;
use WeBWorK::URLPath;
use WeBWorK::CGI;
use WeBWorK::Utils qw(runtime_use writeTimingLogEntry);

use mod_perl;
use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

# Apache2 needs upload class
BEGIN {
	if (MP2) {
		require Apache2::Upload;
		Apache2::Upload->import();
		require Apache2::RequestUtil;
		Apache2::RequestUtil->import();
	}
}

use constant LOGIN_MODULE => "WeBWorK::ContentGenerator::Login";
use constant PROCTOR_LOGIN_MODULE => "WeBWorK::ContentGenerator::LoginProctor";

BEGIN {
	# pre-compile all content generators
	# Login and LoginProctor need to be handled separately, since they don't have paths
	map { eval "require $_"; die $@ if $@ }
		WeBWorK::URLPath->all_modules,
		LOGIN_MODULE,
		PROCTOR_LOGIN_MODULE;
	# other candidates for preloading:
	# - DB Record, Schema, and Driver classes (esp. Driver::SQL as it loads DBI)
	# - CourseManagement subclasses (ditto. sql_single.pm)
	# - WeBWorK::PG::Local, which loads WeBWorK::PG::Translator
	# - Authen subclasses
}

our %SeedCE;

sub dispatch($) {
	my ($apache) = @_;
	my $r = WeBWorK::Request->new($apache);
	
	my $method = $r->method;
	my $location = $r->location;
	my $uri = $r->uri;
	my $path_info = $r->path_info | "";
	my $args = $r->args || "";
	my $dir_config = $r->dir_config;
	my %conf_vars = map { $_ => $dir_config->{$_} } grep { /^webwork_/ } keys %$dir_config;
	@SeedCE{keys %conf_vars} = values %conf_vars;
	
	debug("\n\n===> Begin " . __PACKAGE__ . "::dispatch() <===\n\n");
	debug("Hi, I'm the new dispatcher!\n");
	debug(("-" x 80) . "\n");
	
	debug("Okay, I got some basic information:\n");
	debug("The apache location is $location\n");
	debug("The request method is $method\n");
	debug("The URI is $uri\n");
	debug("The path-info is $path_info\n");
	debug("The argument string is $args\n");
	#debug("The WeBWorK root directory is $webwork_root\n");
	#debug("The PG root directory is $pg_root\n");
	debug(("-" x 80) . "\n");
	
	debug("The first thing we need to do is munge the path a little:\n");
	
	######################################################################
	# Create a URLPath  object
	######################################################################
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
	my $urlPath = WeBWorK::URLPath->newFromPath($path, $r);
	                            # pointer to parent request for access to the $ce and language translation ability
	                            # need to add this pointer whenever a new URLPath is created.
	debug("-------------------- call to WeBWorK::URLPath::newFromPath\n");
	
	unless ($urlPath) {
		debug("This path is invalid... see you later!\n");
		die "The path '$path' is not valid.\n";
	}
	
	my $displayModule = $urlPath->module;
	my %displayArgs = $urlPath->args;
	
	unless ($displayModule) {
		debug("The display module is empty, so we can DECLINE here.\n");
		die "No display module found for path '$path'.";
	}
	
	debug("The display module for this path is: $displayModule\n");
	debug("...and here are the arguments we'll pass to it:\n");
	foreach my $key (keys %displayArgs) {
		debug("\t$key => $displayArgs{$key}\n");
	}
	
	my $selfPath = $urlPath->path;
	my $parent = $urlPath->parent;
	my $parentPath = $parent ? $parent->path : "<no parent>";
	
	debug("Reconstructing the original path gets us: $selfPath\n");
	debug("And we can generate the path to our parent, too: $parentPath\n");
	debug("(We could also figure out who our children are, but we'd need to supply additional arguments.)\n");
	debug(("-" x 80) . "\n");
	
	debug("The URLPath looks good, we'll add it to the request.\n");
	$r->urlpath($urlPath);
	
	debug("Now we want to look at the parameters we got.\n");
	
	debug("The raw params:\n");
	foreach my $key ($r->param) {
		my @vals = $r->param($key);
		my $vals = join(", ", map { "'$_'" } @vals);
		debug("\t$key => $vals\n");
	}
	
	#mungeParams($r);
	#
	#debug("The munged params:\n");
	#foreach my $key ($r->param) {
	#	debug("\t$key\n");
	#	debug("\t\t$_\n") foreach $r->param($key);
	#}
	
	debug(("-" x 80) . "\n");
	
	my $apache_hostname = $r->hostname;
	my $apache_port     = $r->get_server_port;
	my $apache_is_ssl   = ($r->subprocess_env('https') ? 1 : "");
	my $apache_root_url;
	if ($apache_is_ssl) {
		$apache_root_url = "https://$apache_hostname";
		$apache_root_url .= ":$apache_port" if $apache_port != 443;
	} else {
		$apache_root_url = "http://$apache_hostname";
		$apache_root_url .= ":$apache_port" if $apache_port != 80;
	}
	
	
	####################################################################
	# Create Course Environment    $ce
	####################################################################
	debug("We need to get a course environment (with or without a courseID!)\n");
	my $ce = eval { new WeBWorK::CourseEnvironment({
		%SeedCE,
		courseName => $displayArgs{courseID},
		# this is kind of a hack, but it's really the only sane way to get this
		# server information into the PG box
		apache_hostname => $apache_hostname,
		apache_port => $apache_port,
		apache_is_ssl => $apache_is_ssl,
		apache_root_url => $apache_root_url,
	}) };
	$@ and die "Failed to initialize course environment: $@\n";
	debug("Here's the course environment: $ce\n");
	$r->ce($ce);
	
	
	######################
	# Localizing language
	######################
	my $language= $ce->{language} || "en";
	# $r->language_handle( WeBWorK::Localize->get_handle($language) );
	$r->language_handle( WeBWorK::Localize::getLoc($language) );

	my @uploads;
	if (MP2) {
		my $upload_table = $r->upload;
		@uploads = values %$upload_table if defined $upload_table;
	} else {
		@uploads = $r->upload;
	}
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
	
	# create these out here. they should fail if they don't have the right information
	# this lets us not be so careful about whether these objects are defined when we use them.
	# instead, we just create the behavior that if they don't have a valid $db they fail.
	my $authz = new WeBWorK::Authz($r);
	$r->authz($authz);
	
	# figure out which authentication modules to use
	#my $user_authen_module;
	#my $proctor_authen_module;
	#if (ref $ce->{authen}{user_module} eq "HASH") {
	#	if (exists $ce->{authen}{user_module}{$ce->{dbLayoutName}}) {
	#		$user_authen_module = $ce->{authen}{user_module}{$ce->{dbLayoutName}};
	#	} else {
	#		$user_authen_module = $ce->{authen}{user_module}{"*"};
	#	}
	#} else {
	#	$user_authen_module = $ce->{authen}{user_module};
	#}
	#if (ref $ce->{authen}{proctor_module} eq "HASH") {
	#	if (exists $ce->{authen}{proctor_module}{$ce->{dbLayoutName}}) {
	#		$proctor_authen_module = $ce->{authen}{proctor_module}{$ce->{dbLayoutName}};
	#	} else {
	#		$proctor_authen_module = $ce->{authen}{proctor_module}{"*"};
	#	}
	#} else {
	#	$proctor_authen_module = $ce->{authen}{proctor_module};
	#}
	
	my $user_authen_module = WeBWorK::Authen::class($ce, "user_module");
	
	runtime_use $user_authen_module;
	my $authen = $user_authen_module->new($r);
	debug("Using user_authen_module $user_authen_module: $authen\n");
	$r->authen($authen);
	
	my $db;
	
	if ($displayArgs{courseID}) {
		debug("We got a courseID from the URLPath, now we can do some stuff:\n");
		
		unless (-e $ce->{courseDirs}->{root}) {
			die "Course '$displayArgs{courseID}' not found: $!";
		}
		
		debug("...we can create a database object...\n");
		$db = new WeBWorK::DB($ce->{dbLayout});
		debug("(here's the DB handle: $db)\n");
		$r->db($db);
		
		my $authenOK = $authen->verify;
		if ($authenOK) {
			my $userID = $r->param("user");
			debug("Hi, $userID, glad you made it.\n");
			
			# tell authorizer to cache this user's permission level
			$authz->setCachedUser($userID);
			
			debug("Now we deal with the effective user:\n");
			my $eUserID = $r->param("effectiveUser") || $userID;
			debug("userID=$userID eUserID=$eUserID\n");
			if ($userID ne $eUserID) {
				debug("userID and eUserID differ... seeing if userID has 'become_student' permission.\n");
				my $su_authorized = $authz->hasPermissions($userID, "become_student");
				if ($su_authorized) {
					debug("Ok, looks like you're allowed to become $eUserID. Whoopie!\n");
				} else {
					debug("Uh oh, you're not allowed to become $eUserID. Nice try!\n");
					die "You are not allowed to act as another user.\n";
				}
			}
			
			# set effectiveUser in case it was changed or not set to begin with
			$r->param("effectiveUser" => $eUserID);
			
			# if we're doing a proctored test, after the user has been authenticated
			# we need to also check on the proctor.  note that in the gateway quiz
			# module we double check this, to be sure that someone isn't taking a
			# proctored quiz but calling the unproctored ContentGenerator
			my $urlProducedPath = $urlPath->path();
			if ( $urlProducedPath =~ /proctored_quiz_mode/i ) {
				my $proctor_authen_module = WeBWorK::Authen::class($ce, "proctor_module");
				runtime_use $proctor_authen_module;
				my $authenProctor = $proctor_authen_module->new($r);
				debug("Using proctor_authen_module $proctor_authen_module: $authenProctor\n");
			    my $procAuthOK = $authenProctor->verify();
				
				if (not $procAuthOK) {
					$displayModule = PROCTOR_LOGIN_MODULE;
				}
			}
		} else {
			debug("Bad news: authentication failed!\n");
			$displayModule = LOGIN_MODULE;
			debug("set displayModule to $displayModule\n");
		}
	}
	
	# store the time before we invoke the content generator
	my $cg_start = time; # this is Time::HiRes's time, which gives floating point values
	
	debug(("-" x 80) . "\n");
	debug("Finally, we'll load the display module...\n");
	
	runtime_use($displayModule);
	
	debug("...instantiate it...\n");
	
	my $instance = $displayModule->new($r);
	
	debug("...and call it:\n");
	debug("-------------------- call to ${displayModule}::go\n");
	
	my $result = $instance->go();
	
	debug("-------------------- call to ${displayModule}::go\n");
	
	my $cg_end = time;
	my $cg_duration = $cg_end - $cg_start;
	writeTimingLogEntry($ce, "[".$r->uri."]", sprintf("runTime = %.3f sec", $cg_duration)." ".$ce->{dbLayoutName}, "");
	
	debug("returning result: " . (defined $result ? $result : "UNDEF") . "\n");
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


# labeled_input subroutine
#
# Creates a form input element with a label added to the correct place.
# Takes in up to six parameters:
#
# -type (type of input element), -name (name of input element), -id (id of the input element), -value (value of the input element), -label_text (the text on the label), -label_id (the id of the label)
#
# If any of the parameters are not specified, they default to "none". 
#
# UPDATE: updated lable tags so that their "for" property will point to the id of the element that they are labeling. This means that entering an id for the input element becomes essentially mandatory if you want the tag to work correctly.

# DEPRECATED - see below

# sub labeled_input
# {
	# my %param = (-type=>"none", -name=>"none", -value=>"none", -id=>"none", -label_text=>"none", -label_id=>"none", @_);
	
	# if($param{-type} eq "text" or $param{-type} eq "password" or $param{-type} eq "file"){
		# return CGI::label({-id=>$param{-label_id}, -for=>$param{-id}},$param{-label_text}).CGI::input({-type=>$param{-type}, -name=>$param{-name}, -value=>$param{-value}, -id=>$param{-id}}).CGI::br();
	# }
	# elsif($param{-type} eq "checkbox" or $param{-type} eq "radio"){
		# return CGI::input({-type=>$param{-type}, -name=>$param{-name}, -value=>$param{-value}, -id=>$param{-id}}).CGI::label({-id=>$param{-label_id}, -for=>$param{-id}},$param{-label_text}).CGI::br();
	# }
	# elsif($param{-type} eq "submit" or $param{-type} eq "button" or $param{-type} eq "reset"){
		# return CGI::input({-type=>$param{-type}, -name=>$param{-name}, -value=>$param{-value}, -id=>$param{-id}}).CGI::br();
	# }
	# else{
		# return "Not a valid input type";
	# }
# }


# CGI_labeled_input subroutine

# A replacement to the labeled_input subroutine above, created when it was determined that the old subroutine was limited in that it did not allow for attributes other than the ones that it specified.

# This subroutine rectifies that problem by taking in attributes for the input elements and label elements as hashes and simply entering them into the CGI routines, which already support attributes as hash parameters.

# The way it attaches label tags is similar to the labeled_input subroutine.

# This subroutine has also been expanded to be able to handle select elements.

# Five parameters are taken in as a hash: -type (specifying the type of the input element), -id (specifying the id of the input element), -label_text (specifying the text to go in the label), -input_attr (a hash specifying any additional attributes for the input element, if any), and -label_attr (a hash specifying additional attributes for the label element, if any).

# As before, all parameters are optional, with the scalar parameters defaulting to "none" and the hash parameters defaulting to empty. 


sub CGI_labeled_input
{
	my %param = (-type=>"none", -id=>"none", -label_text=>"none", -input_attr=>{}, -label_attr=>{}, @_);
	
	$param{-input_attr}{-type} = $param{-type};
	$param{-input_attr}{-id} = $param{-id};
	$param{-label_attr}{-for} = $param{-id};
	
	if($param{-type} eq "text" or $param{-type} eq "password" or $param{-type} eq "file"){
		return CGI::label($param{-label_attr},$param{-label_text}).CGI::input($param{-input_attr});
	}
	elsif($param{-type} eq "checkbox" or $param{-type} eq "radio"){
		return CGI::input($param{-input_attr}).CGI::label($param{-label_attr},$param{-label_text});
	}
	elsif($param{-type} eq "submit" or $param{-type} eq "button" or $param{-type} eq "reset"){
		return CGI::input($param{-input_attr});
	}
	elsif($param{-type} eq "select"){
		return CGI::label($param{-label_attr},$param{-label_text}).CGI::popup_menu($param{-input_attr});
	}
	elsif($param{-type} eq "textarea"){
		return CGI::label($param{-label_attr},$param{-label_text}).CGI::br().CGI::br().CGI::textarea($param{-input_attr});
	}
	else{
		"Not a valid input type";
	}
}

# split_cap subroutine - ghe3

# A sort of wrapper for the built-in split function which uses capital letters as a delimiter, and returns a string containing the separated substrings separated by a whitespace.  Used to make actionID's more readable.

sub split_cap
{
	my $str = shift;
	
	my @str_arr = split(//,$str);
	my $count = scalar(@str_arr);
	
	my $i = 0;
	my $prev = 0;
	my @result = ();
	my $hasCapital = 0;
	foreach(@str_arr){
		if($_ =~ /[A-Z]/){
			$hasCapital = 1;
			push(@result, join("", @str_arr[$prev..$i-1]));
			$prev = $i;
		}
		$i++;
	}
	
	unless($hasCapital){
		return $str;
	}
	else{
		push(@result, join("", @str_arr[$prev..$count-1]));	
		return join(" ",@result);
	}
}

# underscore_to_whitespace subroutine

# a simple subroutine for converting underscores in a given string to whitespace

sub underscore_to_whitespace{
	my $str = shift;
	
	my @strArr = split("",$str);
	foreach(@strArr){
		if($_ eq "_"){
			$_ = " "
		}
	}
	
	my $result = join("",@strArr);
	
	return $result;
}

sub remove_duplicates{
	my @arr = @_;
	
	my %unique;
	my @result;
	
	foreach(@arr){
		if(defined $unique{$_}){
			next;
		}
		else{
			push(@result, $_);
			$unique{$_} = "seen";
		}
	}
	
	return @result;
	
}

=head1 AUTHOR

Written by Dennis Lambe, malsyned at math.rochester.edu. Modified by Sam
Hathaway, sh002i at math.rochester.edu.

=cut

1;
