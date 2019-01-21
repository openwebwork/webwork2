#!/Volumes/WW_test/opt/local/bin/perl -w

################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
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


=head1 NAME


=head1 SYNOPSIS
	
 

=head1 DESCRIPTION

Include this in other programs that need to know the location of the WeBWorK root directory 
and basic WeBWorK environment variables.

=cut

use strict;
use warnings;
use Carp;
$Carp::Verbose = 1;

#######################################################
# Find the webwork2 root directory
#######################################################
BEGIN {
        die "WEBWORK_ROOT not found in environment. \n
             WEBWORK_ROOT can be defined in your .cshrc or .bashrc file\n
             It should be set to the webwork2 directory (e.g. /opt/webwork/webwork2)"
                unless exists $ENV{WEBWORK_ROOT};
	# Unused variable, but define it twice to avoid an error message.
	$WeBWorK::Constants::WEBWORK_DIRECTORY = $ENV{WEBWORK_ROOT};
	
	# Define MP2 -- this would normally be done in webwork.apache2.4-config
	$ENV{MOD_PERL_API_VERSION}=2;
	print "Webwork root directory is $WeBWorK::Constants::WEBWORK_DIRECTORY\n\n";
}


BEGIN {
	my $hostname = 'http://localhost';
	my $courseName = 'daemon_course';

	#Define the OpaqueServer static variables
	my $topDir = $WeBWorK::Constants::WEBWORK_DIRECTORY;
	$topDir =~ s|webwork2?$||;   # remove webwork2 link
	my $root_dir = "$topDir/ww_opaque_server";
	my $root_pg_dir = "$topDir/pg";
	my $root_webwork2_dir = "$topDir/webwork2";

	my $rpc_url = '/opaqueserver_rpc';
	my $files_url = '/opaqueserver_files';
	my $wsdl_url = '/opaqueserver_wsdl';

	
	# Find the library directories for 
	# ww_opaque_server, pg and webwork2
	# and place them in the search path for modules

	eval "use lib '$root_dir/lib'"; die $@ if $@;
	eval "use lib '$root_pg_dir/lib'"; die $@ if $@;
	eval "use lib '$root_webwork2_dir/lib'"; die $@ if $@;

	############################################
	# Define base urls and the paths to base directories, 
	############################################
	$WebworkBase::TopDir = $topDir;   #/opt/webwork/
	$WebworkBase::Host = $hostname;
	$WebworkBase::RootDir = $root_dir;
	$WebworkBase::RootPGDir = $root_pg_dir;
	$WebworkBase::RootWebwork2Dir = $root_webwork2_dir;
	$WebworkBase::RPCURL = $rpc_url;
	$WebworkBase::WSDLURL = $wsdl_url;

	$WebworkBase::FilesURL = $files_url;
	$WebworkBase::courseName = $courseName;

	# suppress warning messages
	my $foo = $WebworkBase::TopDir; 
	$foo = $WebworkBase::RootDir;
	$foo = $WebworkBase::Host;
	$foo = $WebworkBase::WSDLURL;
	$foo = $WebworkBase::FilesURL;
	$foo ='';
} # END BEGIN




use WeBWorK::CourseEnvironment;
use WeBWorK::DB;


##############################
# Create the course environment $ce and the database object $db
##############################
$WebworkBase::ce = create_course_environment();
my $dbLayout = $WebworkBase::ce->{dbLayout};	
$WebworkBase::db = WeBWorK::DB->new($dbLayout);
my $foo = $WebworkBase::db;
$foo = '';
####################################################################################
# Create_course_environment -- utility function
# requires webwork_dir
# requires courseName to keep warning messages from being reported
# Remaining inputs are required for most use cases of $ce but not for all of them.
####################################################################################



sub create_course_environment {
	my $ce = WeBWorK::CourseEnvironment->new( 
				{webwork_dir		=>		$WebworkBase::RootWebwork2Dir, 
				 courseName         =>      $WebworkBase::courseName,
				 webworkURL         =>      $WebworkBase::RPCURL,
				 pg_dir             =>      $WebworkBase::RootPGDir,
				 });
	warn "Unable to find environment for course: |$WebworkBase::courseName|" unless ref($ce);
	return ($ce);
}


1;
