#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
	use Mojo::File qw(curfile);
	use Env        qw(WEBWORK_ROOT);

	$WEBWORK_ROOT = curfile->dirname->dirname;
}

# link to WeBWorK and pg code libraries
use lib "$ENV{WEBWORK_ROOT}/lib";

use WeBWorK::CourseEnvironment;

use WeBWorK::DB qw(check_user_id);
use WeBWorK::File::Classlist;
use WeBWorK::Utils           qw(cryptPassword);
use WeBWorK::File::Classlist qw(parse_classlist);

if ((scalar(@ARGV) != 2)) {
	print "\nSyntax is: importClassList.pl course_id path_to_classlist_file.lst\n\n";
	exit();
}

my $courseID = shift;

my $fileName = shift;
die "Not able to read from file $fileName : does it exist? is it readable?" unless (-r "$fileName");

my $ce = WeBWorK::CourseEnvironment->new({
	webwork_dir => $ENV{WEBWORK_ROOT},
	courseName  => $courseID
});

my $db = WeBWorK::DB->new($ce->{dbLayout});

my $createNew       = 1;         # Always set to true, so add new users
my $replaceExisting = "none";    # Always set to "none" so no existing accounts are changed
my @replaceList     = ();        # Empty list
my (@replaced, @added, @skipped);

# This was copied with MINOR changes from lib/WeBWorK/ContentGenerator/Instructor/UserList.pm.
sub importUsersFromCSV {
	my ($fileName, $createNew, $replaceExisting, @replaceList) = @_;

	my @allUserIDs = $db->listUsers;
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
		my %record  = %$record;
		my $user_id = $record{user_id};

		print "Saw user_id = $user_id\n";

		unless (WeBWorK::DB::check_user_id($user_id)) {    # try to catch lines with bad characters
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

		# Determine what to use for the password (if anything).
		if (!$record{password}) {
			if (defined $record{unencrypted_password} && $record{unencrypted_password} =~ /\S/) {
				$record{password} = cryptPassword($record{unencrypted_password});
			} elsif ($ce->{fallback_password_source}
				&& { user_id => 1, first_name => 1, last_name => 1, student_id => 1 }
				->{ $ce->{fallback_password_source} }
				&& $record{ $ce->{fallback_password_source} }
				&& $record{ $ce->{fallback_password_source} } =~ /\S/)
			{
				$record{password} = cryptPassword($record{ $ce->{fallback_password_source} });
			}
		}

		# set default permission level if permission level is "empty"
		$record{permission} = $default_permission_level
			unless defined $record{permission} and $record{permission} ne "";

		my $User            = $db->newUser(%record);
		my $PermissionLevel = $db->newPermissionLevel(user_id => $user_id, permission => $record{permission});
		my $Password = $record{password} ? $db->newPassword(user_id => $user_id, password => $record{password}) : undef;

		# DBFIXME use REPLACE
		if (exists $allUserIDs{$user_id}) {
			$db->putUser($User);
			$db->putPermissionLevel($PermissionLevel);
			$db->putPassword($Password) if $Password;
			push @replaced, $user_id;
		} else {
			$db->addUser($User);
			$db->addPermissionLevel($PermissionLevel);
			$db->addPassword($Password) if $Password;
			push @added, $user_id;
		}
	}

	print("Added:\n\t",    join("\n\t", @added),    "\n\n");
	print("Skipped:\n\t",  join("\n\t", @skipped),  "\n\n");
	print("Replaced:\n\t", join("\n\t", @replaced), "\n\n");

	return;
}

importUsersFromCSV($fileName, $createNew, $replaceExisting, @replaceList);

