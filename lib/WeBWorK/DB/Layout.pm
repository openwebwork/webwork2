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
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

WeBWorK::DB::Layout - the database layout.

=head1 DESCRIPTION

The database layout is a hash reference consisting of items keyed by table
names.  The value of each item is a reference to a hash containing the following
items:

=over

=item record

The name of a perl module to use for representing the data in a record.

=item schema

The name of a perl module to use for access to the table.

=item params

A reference to a hash containing extra information needed by the schema. Some
schemas require parameters, some do not. The only supported parameters are
C<non_native>, C<tableOverride>, and C<merge> at this point.

If C<< non_native => 1 >> is set it means that the table is not a table for the
course. Note that can mean two things.  It can mean that the table is a global
site table, or it can mean that the table is a virtual table.

The C<tableOverride> parameter is the name of the physical table in the
database.  Usually this just prepends C<$courseName>.

If the C<merge> parameter is set it should be a reference to an array of table
names (that are NOT C<non_native>) whose values are merged to give the values in
this table. Note that a C<merge> table is virtual and must have
 C<< non_native => 1 >> set.

=item depend

A reference to an array of other database tables on which this table depends and
whose schemas must be initialized prior to initialization of the schema for this
table.

=back

=head1 METHODS

=head2 databaseLayout

    my $dbLayout = databaseLayout($courseName);

This returns a database layout hash as described above for the course identified
by C<$courseName> which is the only required argument for this method.

=cut

our @EXPORT_OK = qw(databaseLayout);

sub databaseLayout ($courseName) {
	return {
		locations => {
			record => "WeBWorK::DB::Record::Locations",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { non_native => 1 },
		},
		location_addresses => {
			record => "WeBWorK::DB::Record::LocationAddresses",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { non_native => 1 },
		},
		depths => {
			record => "WeBWorK::DB::Record::Depths",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { non_native => 1 },
		},
		lti_launch_data => {
			record => "WeBWorK::DB::Record::LTILaunchData",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { non_native => 1 },
		},
		lti_course_map => {
			record => "WeBWorK::DB::Record::LTICourseMap",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { non_native => 1 },
		},
		password => {
			record => "WeBWorK::DB::Record::Password",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { tableOverride => "${courseName}_password" },
		},
		permission => {
			record => "WeBWorK::DB::Record::PermissionLevel",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { tableOverride => "${courseName}_permission" },
		},
		key => {
			record => "WeBWorK::DB::Record::Key",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { tableOverride => "${courseName}_key" },
		},
		user => {
			record => "WeBWorK::DB::Record::User",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { tableOverride => "${courseName}_user" },
		},
		set => {
			record => "WeBWorK::DB::Record::Set",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { tableOverride => "${courseName}_set" },
		},
		set_user => {
			record => "WeBWorK::DB::Record::UserSet",
			schema => "WeBWorK::DB::Schema::NewSQL::NonVersioned",
			params => { tableOverride => "${courseName}_set_user" },
		},
		set_merged => {
			record => "WeBWorK::DB::Record::UserSet",
			schema => "WeBWorK::DB::Schema::NewSQL::Merge",
			depend => [qw(set_user set)],
			params => { non_native => 1, merge => [qw(set_user set)] },
		},
		set_version => {
			record => "WeBWorK::DB::Record::SetVersion",
			schema => "WeBWorK::DB::Schema::NewSQL::Versioned",
			params => { non_native => 1, tableOverride => "${courseName}_set_user" },
		},
		set_version_merged => {
			record => "WeBWorK::DB::Record::SetVersion",
			schema => "WeBWorK::DB::Schema::NewSQL::Merge",
			depend => [qw(set_version set_user set)],
			params => { non_native => 1, merge => [qw(set_version set_user set)] },
		},
		set_locations => {
			record => "WeBWorK::DB::Record::SetLocations",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { tableOverride => "${courseName}_set_locations" },
		},
		set_locations_user => {
			record => "WeBWorK::DB::Record::UserSetLocations",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { tableOverride => "${courseName}_set_locations_user" },
		},
		problem => {
			record => "WeBWorK::DB::Record::Problem",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { tableOverride => "${courseName}_problem" },
		},
		problem_user => {
			record => "WeBWorK::DB::Record::UserProblem",
			schema => "WeBWorK::DB::Schema::NewSQL::NonVersioned",
			params => { tableOverride => "${courseName}_problem_user" },
		},
		problem_merged => {
			record => "WeBWorK::DB::Record::UserProblem",
			schema => "WeBWorK::DB::Schema::NewSQL::Merge",
			depend => [qw(problem_user problem)],
			params => { non_native => 1, merge => [qw(problem_user problem)] },
		},
		problem_version => {
			record => "WeBWorK::DB::Record::ProblemVersion",
			schema => "WeBWorK::DB::Schema::NewSQL::Versioned",
			params => { non_native => 1, tableOverride => "${courseName}_problem_user" },
		},
		problem_version_merged => {
			record => "WeBWorK::DB::Record::ProblemVersion",
			schema => "WeBWorK::DB::Schema::NewSQL::Merge",
			depend => [qw(problem_version problem_user problem)],
			params => { non_native => 1, merge => [qw(problem_version problem_user problem)] },
		},
		setting => {
			record => "WeBWorK::DB::Record::Setting",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { tableOverride => "${courseName}_setting" },
		},
		achievement => {
			record => "WeBWorK::DB::Record::Achievement",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { tableOverride => "${courseName}_achievement" },
		},
		past_answer => {
			record => "WeBWorK::DB::Record::PastAnswer",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { tableOverride => "${courseName}_past_answer" },
		},

		achievement_user => {
			record => "WeBWorK::DB::Record::UserAchievement",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { tableOverride => "${courseName}_achievement_user" },
		},
		global_user_achievement => {
			record => "WeBWorK::DB::Record::GlobalUserAchievement",
			schema => "WeBWorK::DB::Schema::NewSQL::Std",
			params => { tableOverride => "${courseName}_global_user_achievement" },
		},
	};
}

1;
