################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK.pm,v 1.50 2004/03/04 21:00:51 sh002i Exp $
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

BEGIN { $main::VERSION = "2.0"; }


my $timingON = 1;

use strict;
use warnings;
use Apache::Constants qw(:common REDIRECT DONE);
use WeBWorK::Authen;
use WeBWorK::Authz;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
#use WeBWorK::Timing;
use WeBWorK::Upload;
use WeBWorK::Utils qw(runtime_use);
use WeBWorK::Request;
use WeBWorK::URLPath;

use constant AUTHEN_MODULE => "WeBWorK::ContentGenerator::Login";

#sub debug(@) { print STDERR "dispatch_new: ", join("", @_) };
sub debug(@) {  };

sub dispatch($) {
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
	
	my $instance = $displayModule->new($r);
	
	debug("...and call it:\n");
	debug("-------------------- call to ${displayModule}::go\n");
	
	my $result = $instance->go();
	
	debug("-------------------- call to ${displayModule}::go\n");
	
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
