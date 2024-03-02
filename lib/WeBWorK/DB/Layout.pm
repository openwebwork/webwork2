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

package WeBWorK::DB::Layout;
use base qw(Exporter);

=head1 NAME

WeBWorK::DB::Layout - returns the database layout given server parameters.

=cut

use strict;
use warnings;

our @EXPORT    = ();
our @EXPORT_OK = qw(layout);

sub layout {
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
