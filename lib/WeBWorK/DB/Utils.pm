################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::DB::Utils;
use base qw(Exporter);

=head1 NAME

WeBWorK::DB::Utils - useful utilities for the database modules.

=cut

use strict;
use warnings;

our @EXPORT    = ();
our @EXPORT_OK = qw(
	global2user
	user2global
	initializeUserProblem
	fake_set
	fake_set_version
	fake_problem
	make_vsetID
	make_vsetID_sql
	grok_vsetID
	grok_setID_from_vsetID_sql
	grok_versionID_from_vsetID_sql
	databaseParams
);

use constant fakeSetName => 'Undefined_Set';

sub global2user($$) {
	my ($userRecordClass, $GlobalRecord) = @_;
	my $UserRecord = $userRecordClass->new();
	foreach my $field ($GlobalRecord->FIELDS()) {
		$UserRecord->$field($GlobalRecord->$field());
	}
	return $UserRecord;
}

sub user2global($$) {
	my ($globalRecordClass, $UserRecord) = @_;
	my $GlobalRecord = $globalRecordClass->new();
	foreach my $field ($GlobalRecord->FIELDS()) {
		$GlobalRecord->$field($UserRecord->$field());
	}
	return $GlobalRecord;
}

# Populate a user record with sane defaults and a random seed
# This function edits the record in place, so you can discard
# the return value.
sub initializeUserProblem {
	my ($userProblem, $seed) = @_;
	$seed = int rand 5000 unless defined $seed;
	$userProblem->status(0.0);
	$userProblem->attempted(0);
	$userProblem->num_correct(0);
	$userProblem->num_incorrect(0);
	$userProblem->problem_seed($seed);
	$userProblem->sub_status(0.0);

	return $userProblem;
}

# Methods to create initialized database set and problem objects.
# They are poorly named methods.  The database objects are not "fake".
# The are valid database objects with initialized values.

sub fake_set {
	my $db = shift;

	my $set = $db->newGlobalSet();
	$set = global2user($db->{set_user}{record}, $set);
	$set->psvn(123);
	$set->set_id(fakeSetName);
	$set->open_date(time);
	$set->due_date(time);
	$set->answer_date(time);
	$set->visible(0);
	$set->enable_reduced_scoring(0);
	$set->hardcopy_header('defaultHeader');

	return ($set);
}

sub fake_set_version {
	my $db = shift;

	my $set = $db->newSetVersion();
	$set->psvn(123);
	$set->set_id(fakeSetName);
	$set->open_date(time);
	$set->due_date(time);
	$set->answer_date(time);
	$set->visible(0);
	$set->enable_reduced_scoring();
	$set->hardcopy_header('defaultHeader');
	$set->version_id(1);
	$set->attempts_per_version(0);
	$set->problem_randorder(0);
	$set->problems_per_page(0);
	$set->hide_score('N');
	$set->hide_score_by_problem('N');
	$set->hide_work('N');
	$set->restrict_ip('No');

	return ($set);
}

sub fake_problem {
	my ($db, %options) = @_;

	my $problem = $db->newGlobalProblem();
	$problem = global2user($db->{problem_user}{record}, $problem);
	$problem->set_id(fakeSetName);
	$problem->value('');
	$problem->max_attempts(-1);
	$problem->showMeAnother(-1);
	$problem->showMeAnotherCount(0);
	$problem->showHintsAfter(2);
	$problem->problem_seed($options{problem_seed} // 0);
	$problem->status(0);
	$problem->sub_status(0);
	$problem->attempted(2000);    # Large so hints won't be blocked
	$problem->last_answer('');
	$problem->num_correct(1000);
	$problem->num_incorrect(1000);
	$problem->prCount(-10);       # Negative to detect fake problems and disable problem randomization.

	return ($problem);
}

################################################################################
# versioning utilities
################################################################################

sub make_vsetID($$) {
	my ($setID, $versionID) = @_;
	return "$setID,v$versionID";
}

# does not quote $setID and $versionID, because they could be strings, qualified
# or unqualified field names, or complex expression
sub make_vsetID_sql {
	my ($setID, $versionID) = @_;
	return "CONCAT($setID,',v',$versionID)";
}

sub grok_vsetID($) {
	my ($vsetID) = @_;
	my ($setID, $versionID) = $vsetID =~ /([^,]+)(?:,v(.*))?/;
	return $setID, $versionID;
}

# does not quote $field, because it could be a string, a qualified or
# unqualified field name, or a complex expression
sub grok_setID_from_vsetID_sql($) {
	my ($field) = @_;
	return "SUBSTRING($field,1,INSTR($field,',v')-1)";
}

# does not quote $field, because it could be a string, a qualified or
# unqualified field name, or a complex expression
sub grok_versionID_from_vsetID_sql($) {
	my ($field) = @_;
	# the "+0" casts the resulting value as a number
	return "(SUBSTRING($field,INSTR($field,',v')+2)+0)";
}

# This function fills database fields of the CourseEnvironment

sub databaseParams {
	my ($courseName, $db_params, $externalPrograms) = @_;

	my %sqlParams = (
		username => $db_params->{username},
		password => $db_params->{password},
		debug    => $db_params->{database_debug} // 0,
		# kinda hacky, but needed for table dumping
		mysql_path     => $externalPrograms->{mysql},
		mysqldump_path => $externalPrograms->{mysqldump},
	);

	if ($db_params->{driver} =~ /^mysql$/i) {
		# The extra UTF8 connection setting is ONLY needed for older DBD:mysql driver
		# and forbidden by the newer DBD::MariaDB driver
		if ($db_params->{ENABLE_UTF8MB4}) {
			$sqlParams{mysql_enable_utf8mb4} = 1;    # Full 4-bit UTF-8
		} else {
			$sqlParams{mysql_enable_utf8} = 1;       # Only the partial 3-bit mySQL UTF-8
		}
	}
	return {
		locations => {
			record        => "WeBWorK::DB::Record::Locations",
			schema        => "WeBWorK::DB::Schema::NewSQL::Std",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, non_native => 1 },
		},
		location_addresses => {
			record        => "WeBWorK::DB::Record::LocationAddresses",
			schema        => "WeBWorK::DB::Schema::NewSQL::Std",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, non_native => 1 },
		},
		depths => {
			record => "WeBWorK::DB::Record::Depths",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			driver => "WeBWorK::DB::Driver::SQL",
			source => $db_params->{dsn},
			engine => $db_params->{storage_engine},
			params => { %sqlParams, non_native => 1 },
		},
		password => {
			record        => "WeBWorK::DB::Record::Password",
			schema        => "WeBWorK::DB::Schema::NewSQL::Std",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, tableOverride => "${courseName}_password" },
		},
		permission => {
			record        => "WeBWorK::DB::Record::PermissionLevel",
			schema        => "WeBWorK::DB::Schema::NewSQL::Std",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, tableOverride => "${courseName}_permission" },
		},
		key => {
			record        => "WeBWorK::DB::Record::Key",
			schema        => "WeBWorK::DB::Schema::NewSQL::Std",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, tableOverride => "${courseName}_key" },
		},
		user => {
			record        => "WeBWorK::DB::Record::User",
			schema        => "WeBWorK::DB::Schema::NewSQL::Std",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, tableOverride => "${courseName}_user" },
		},
		set => {
			record        => "WeBWorK::DB::Record::Set",
			schema        => "WeBWorK::DB::Schema::NewSQL::Std",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, tableOverride => "${courseName}_set" },
		},
		set_user => {
			record        => "WeBWorK::DB::Record::UserSet",
			schema        => "WeBWorK::DB::Schema::NewSQL::NonVersioned",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, tableOverride => "${courseName}_set_user" },
		},
		set_merged => {
			record        => "WeBWorK::DB::Record::UserSet",
			schema        => "WeBWorK::DB::Schema::NewSQL::Merge",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			depend        => [qw/set_user set/],
			params        => {
				%sqlParams,
				non_native => 1,
				merge      => [qw/set_user set/],
			},
		},
		set_version => {
			record => "WeBWorK::DB::Record::SetVersion",
			schema => "WeBWorK::DB::Schema::NewSQL::Versioned",
			driver => "WeBWorK::DB::Driver::SQL",
			source => $db_params->{dsn},
			engine => $db_params->{storage_engine},
			params => {
				%sqlParams,
				non_native    => 1,
				tableOverride => "${courseName}_set_user",

			},
		},
		set_version_merged => {
			record        => "WeBWorK::DB::Record::SetVersion",
			schema        => "WeBWorK::DB::Schema::NewSQL::Merge",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			depend        => [qw/set_version set_user set/],
			params        => {
				%sqlParams,
				non_native => 1,
				merge      => [qw/set_version set_user set/],
			},
		},
		set_locations => {
			record        => "WeBWorK::DB::Record::SetLocations",
			schema        => "WeBWorK::DB::Schema::NewSQL::Std",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, tableOverride => "${courseName}_set_locations" },
		},
		set_locations_user => {
			record        => "WeBWorK::DB::Record::UserSetLocations",
			schema        => "WeBWorK::DB::Schema::NewSQL::Std",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, tableOverride => "${courseName}_set_locations_user" },
		},
		problem => {
			record        => "WeBWorK::DB::Record::Problem",
			schema        => "WeBWorK::DB::Schema::NewSQL::Std",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, tableOverride => "${courseName}_problem" },
		},
		problem_user => {
			record        => "WeBWorK::DB::Record::UserProblem",
			schema        => "WeBWorK::DB::Schema::NewSQL::NonVersioned",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, tableOverride => "${courseName}_problem_user" },
		},
		problem_merged => {
			record        => "WeBWorK::DB::Record::UserProblem",
			schema        => "WeBWorK::DB::Schema::NewSQL::Merge",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			depend        => [qw/problem_user problem/],
			params        => {
				%sqlParams,
				non_native => 1,
				merge      => [qw/problem_user problem/],
			},
		},
		problem_version => {
			record        => "WeBWorK::DB::Record::ProblemVersion",
			schema        => "WeBWorK::DB::Schema::NewSQL::Versioned",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => {
				%sqlParams,
				non_native    => 1,
				tableOverride => "${courseName}_problem_user",
			},
		},
		problem_version_merged => {
			record        => "WeBWorK::DB::Record::ProblemVersion",
			schema        => "WeBWorK::DB::Schema::NewSQL::Merge",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			depend        => [qw/problem_version problem_user problem/],
			params        => {
				%sqlParams,
				non_native => 1,
				merge      => [qw/problem_version problem_user problem/],
			},
		},
		setting => {
			record        => "WeBWorK::DB::Record::Setting",
			schema        => "WeBWorK::DB::Schema::NewSQL::Std",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, tableOverride => "${courseName}_setting" },
		},
		achievement => {
			record        => "WeBWorK::DB::Record::Achievement",
			schema        => "WeBWorK::DB::Schema::NewSQL::Std",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, tableOverride => "${courseName}_achievement" },
		},
		past_answer => {
			record        => "WeBWorK::DB::Record::PastAnswer",
			schema        => "WeBWorK::DB::Schema::NewSQL::Std",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, tableOverride => "${courseName}_past_answer" },
		},

		achievement_user => {
			record        => "WeBWorK::DB::Record::UserAchievement",
			schema        => "WeBWorK::DB::Schema::NewSQL::Std",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, tableOverride => "${courseName}_achievement_user" },
		},
		global_user_achievement => {
			record        => "WeBWorK::DB::Record::GlobalUserAchievement",
			schema        => "WeBWorK::DB::Schema::NewSQL::Std",
			driver        => "WeBWorK::DB::Driver::SQL",
			source        => $db_params->{dsn},
			engine        => $db_params->{storage_engine},
			character_set => $db_params->{character_set},
			params        => { %sqlParams, tableOverride => "${courseName}_global_user_achievement" },
		},
	};
}

1;
