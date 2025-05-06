package WeBWorK::Utils::FilterRecords;
use parent qw(Exporter);

=head1 NAME

WeBWorK::Utils::FilterRecords - utilities for filtering database records.

=head1 SYNOPSIS

    use WeBWorK::Utils::FilterRecords qw/getFiltersForClass filterRecords/;

    # Start with a list of records
    my @users = $db->getUsers($db->listUsers);

    # Get a list of all filters
    my $filters = getFiltersForClass($c, undef, @users);

    # Alternative, get a list of section or recitation filters.
    my $filters = getFiltersForClass($c, ['section', 'recitation'], @users);

    # Filter the records using a list of provided filters.
    my @filteredUsers = filterRecords($c, 1, [ 'section:1', 'recitation:2' ], @users);

=head1 DESCRIPTION

This module provides functions for filtering user or set records from the database.

=cut

use strict;
use warnings;

use Carp;

use WeBWorK::Utils                                          qw(sortByName);
use WeBWorK::ContentGenerator::Instructor::ProblemSetDetail qw(FIELD_PROPERTIES);

our @EXPORT_OK = qw(
	getFiltersForClass
	filterRecords
);

=head1 FUNCTIONS

=over

=item getFiltersForClass($c, $include, @records)

Given a list of database records, returns the filters available for those records.
C<$include> is an array reference that lists the filters to include. If this is
empty, all possible filters are returned.

For user records (WeBWorK::DB::Record::User), filters can be by section,
recitation, status, or permission level in the permissionLevel table. The
possible C<$include> are: 'section', 'recitation', 'status', or 'permission'.

For set records (WeBWorK::DB::Record::Set), filters can be assignment type,
or visibility. The possible C<$include> are: 'assignment_type', or 'visibility'.

The return value is a reference to a list of two element lists. The first
element in each list is a string description of the filter and the second
element is the filter name.  The return value is suitable for passing as the
second value argument to the Mojolicious select_field tag helper method.

=cut

sub getFiltersForClass {
	my ($c, $include, @records) = @_;
	my $blankName = "\x{27E8}" . $c->maketext('blank') . "\x{27E9}";

	my %includes;
	if (ref $include eq 'ARRAY') {
		for (@$include) {
			$includes{$_} = 1;
		}
	}

	my @filters;
	push @filters,
		[ "\x{27E8}" . $c->maketext('Display all possible records') . "\x{27E9}" => 'all', selected => undef ];

	if (ref $records[0] eq 'WeBWorK::DB::Record::User') {
		my (%sections, %recitations, %permissions, %roles);

		for my $user (@records) {
			++$sections{ $user->section };
			++$recitations{ $user->recitation };
			++$roles{ $user->status };
		}

		if (!%includes || $includes{permission}) {
			my %permissionName = reverse %{ $c->ce->{userRoles} };
			++$permissions{ $permissionName{$_} }
				for map { $_->permission } $c->db->getPermissionLevelsWhere({ user_id => { not_like => 'set_id:%' } });
		}

		if (keys %sections > 1 && (!%includes || $includes{section})) {
			for my $sec (sortByName(undef, keys %sections)) {
				push @filters, [ $c->maketext('Section: [_1]', $sec ne '' ? $sec : $blankName) => "section:$sec" ];
			}
		}

		if (keys %recitations > 1 && (!%includes || $includes{recitation})) {
			for my $rec (sortByName(undef, keys %recitations)) {
				push @filters,
					[ $c->maketext('Recitation: [_1]', $rec ne '' ? $rec : $blankName) => "recitation:$rec" ];
			}
		}

		if (keys %roles > 1 && (!%includes || $includes{status})) {
			for my $role (sortByName(undef, keys %roles)) {
				my @statuses = keys %{ $c->ce->{statuses} };
				for (@statuses) {
					push @filters, [ $c->maketext('Enrollment Status: [_1]', $_) => "status:$role" ]
						if ($c->ce->{statuses}{$_}{abbrevs}[0] eq $role);
				}
			}
		}

		if (keys %permissions > 1 && (!%includes || $includes{permission})) {
			for my $perm (sortByName(undef, keys %permissions)) {
				push @filters, [ $c->maketext('Permission Level: [_1]', $perm) => "permission:$perm" ];
			}
		}
	} elsif (ref $records[0] eq 'WeBWorK::DB::Record::Set') {
		my (%assignment_types, %visibles);

		for my $set (@records) {
			++$assignment_types{ $set->assignment_type };
			++$visibles{ $set->visible }
				unless (defined $visibles{0} && $set->visible eq '' || defined $visibles{''} && $set->visible eq '0');
		}

		if (keys %assignment_types > 1 && (!%includes || $includes{assignment_type})) {
			for my $type (sortByName(undef, keys %assignment_types)) {
				push @filters, [ FIELD_PROPERTIES()->{assignment_type}{labels}{$type} => "assignment_type:$type" ];
			}
		}

		if (keys %visibles > 1 && (!%includes || $includes{visible})) {
			for my $vis (sortByName(undef, keys %visibles)) {
				push @filters, [ ($vis ? $c->maketext('Visible') : $c->maketext('Not Visible')) => "visible:$vis" ];
			}
		}
	}
	return \@filters;
}

=item filterRecords($c, $intersect, $filters, @records)

Given a list of filters and a list of records, returns a list of the records
after the selected filters are applied. If C<$intersect> is true then the
intersection of the records that match the filters is returned.  Otherwise the
union of the records that match the filters is returned.

C<$filters> should be a reference to an array of filters or be undefined.

=back

=cut

sub filterRecords {
	my ($c, $intersect, $filters, @records) = @_;

	return unless @records;

	my @filtersToUse = @{ $filters // ['all'] };

	if (grep { $_ eq 'all' } @filtersToUse) {
		return @records;
	}

	my %permissionName = reverse %{ $c->ce->{userRoles} };

	# Only query the database for permission levels if a permission level filter is in use.
	my %permissionLevels =
		(grep {/^permission:/} @filtersToUse)
		? (map { $_->user_id => $_->permission }
			$c->db->getPermissionLevelsWhere({ user_id => { not_like => 'set_id:%' } }))
		: ();

	my @filteredRecords = $intersect ? @records : ();
	if ($intersect) {
		for my $filter (@filtersToUse) {
			my ($name, $value) = split(/:/, $filter);
			# permission level is handled differently
			if ($name eq 'permission') {
				@filteredRecords =
					grep { $permissionName{ $permissionLevels{ $_->user_id } } eq $value } @filteredRecords;
			} else {
				@filteredRecords = grep { $_->$name eq $value } @filteredRecords;
			}
		}
	} else {
		for my $record (@records) {
			for my $filter (@filtersToUse) {
				my ($name, $value) = split(/:/, $filter);
				# permission level is handled differently
				if ($name eq 'permission' && $permissionName{ $permissionLevels{ $record->user_id } } eq $value) {
					push @filteredRecords, $record;
					last;    # Only add a record once.
				} elsif ($name ne 'permission' && $record->$name eq $value) {
					push @filteredRecords, $record;
					last;    # Only add a record once.
				}
			}
		}
	}
	return @filteredRecords;
}

1;
