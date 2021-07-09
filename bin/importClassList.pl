#!/usr/bin/env perl
################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2019 The WeBWorK Project, http://openwebwork.sf.net/
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

BEGIN {
	die "WEBWORK_ROOT not found in environment.\n"
	  unless exists $ENV{WEBWORK_ROOT};
	my $webwork_dir = $ENV{WEBWORK_ROOT};
	print "importClassList.pl:  WeBWorK root directory set to $webwork_dir\n";

	# link to WeBWorK code libraries
	eval "use lib '$webwork_dir/lib'"; die $@ if $@;
	eval "use WeBWorK::CourseEnvironment"; die $@ if $@;
}

use WeBWorK::DB qw(check_user_id);
use WeBWorK::File::Classlist;

#use WeBWorK::Utils qw(readFile readDirectory cryptPassword x);
use WeBWorK::Utils qw(cryptPassword);

use strict;
use warnings;

if((scalar(@ARGV) != 2)) {
  print "\nSyntax is: importClassList.pl course_id path_to_classlist_file.lst\n\n";
  exit();
}

my $courseID = shift;

my $fileName = shift;
die "Not able to read from file $fileName : does it exist? is it readable?" unless ( -r "$fileName" );

my $ce = WeBWorK::CourseEnvironment->new({
	webwork_dir => $ENV{WEBWORK_ROOT},
	courseName => $courseID
});

my $db = new WeBWorK::DB($ce->{dbLayout});

my $createNew = 1;            # Always set to true, so add new users
my $replaceExisting = "none"; # Always set to "none" so no existing accounts are changed
my @replaceList =();          # Empty list
my (@replaced, @added, @skipped);

# This was copied with MINOR changes from lib/WeBWorK/ContentGenerator/Instructor/UserList2.pm 
# FIXME REFACTOR this belongs in a utility class so that addcourse can use it!
# (we need a whole suite of higher-level import/export functions somewhere)
sub importUsersFromCSV {
	my ($fileName, $createNew, $replaceExisting, @replaceList) = @_;

	my @allUserIDs = grep {$_ !~ /^set_id:/} $db->listUsers;
	my %allUserIDs = map { $_ => 1 } @allUserIDs;

	my %replaceOK;
	if ($replaceExisting eq "none") {
		%replaceOK = ();
	} elsif ($replaceExisting eq "listed") {
		%replaceOK = map { $_ => 1 } @replaceList;
	} elsif ($replaceExisting eq "any") {
		%replaceOK = %allUserIDs;
	}
	
	my $default_permission_level = $ce->{default_permission_level};
	
	my (@replaced, @added, @skipped);
	
	# get list of hashrefs representing lines in classlist file
	my @classlist = parse_classlist("$fileName");
	
	# Default status is enrolled -- fetch abbreviation for enrolled
	my $default_status_abbrev = $ce->{statuses}->{Enrolled}->{abbrevs}->[0];
	
	foreach my $record (@classlist) {
		my %record = %$record;
		my $user_id = $record{user_id};
		
		print "Saw user_id = $user_id\n";

		unless (WeBWorK::DB::check_user_id($user_id) ) {  # try to catch lines with bad characters
			push @skipped, $user_id;
			next;
		}
		
		if (exists $allUserIDs{$user_id} and not exists $replaceOK{$user_id}) {
			push @skipped, $user_id;
			next;
		}
		
		if (not exists $allUserIDs{$user_id} and not $createNew) {
			push @skipped, $user_id;
			next;
		}
		
		# set default status is status field is "empty"
		$record{status} = $default_status_abbrev
			unless defined $record{status} and $record{status} ne "";
		
		# set password from student ID if password field is "empty"
		if (not defined $record{password} or $record{password} eq "") {
			if (defined $record{student_id} and $record{student_id} =~ /\S/) {
				# crypt the student ID and use that
				$record{password} = cryptPassword($record{student_id});
			} else {
				# an empty password field in the database disables password login
				$record{password} = "";
			}
		}
		
		# set default permission level if permission level is "empty"
		$record{permission} = $default_permission_level
			unless defined $record{permission} and $record{permission} ne "";
		
		my $User = $db->newUser(%record);
		my $PermissionLevel = $db->newPermissionLevel(user_id => $user_id, permission => $record{permission});
		my $Password = $db->newPassword(user_id => $user_id, password => $record{password});
		
		# DBFIXME use REPLACE
		if (exists $allUserIDs{$user_id}) {
			$db->putUser($User);
			$db->putPermissionLevel($PermissionLevel);
			$db->putPassword($Password);
			push @replaced, $user_id;
		} else {
			$db->addUser($User);
			$db->addPermissionLevel($PermissionLevel);
			$db->addPassword($Password);
			push @added, $user_id;
		}
	}


	print( "Added:\n\t",    join("\n\t", @added),    "\n\n" );
	print( "Skipped:\n\t",  join("\n\t", @skipped),  "\n\n" );
	print( "Replaced:\n\t", join("\n\t", @replaced), "\n\n" );

}

importUsersFromCSV($fileName, $createNew, $replaceExisting, @replaceList);

