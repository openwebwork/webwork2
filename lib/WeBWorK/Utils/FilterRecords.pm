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

package WeBWorK::Utils::FilterRecords;
use parent qw(Exporter);

=head1 NAME

WeBWorK::Utils::FilterRecords - utilities for filtering database records.

=head1 SYNOPSIS

    use WeBWorK::Utils::FilterRecords qw/getFiltersForClass/;

    # Get a list of filters
    my $filters = getFiltersForClass(@users);

    use WeBWorK::Utils::FilterRecords qw/filterRecords/;

    # Start with a list of records
    my @users = $db->getUsers($db->listUsers);

    # Filter the records using a list of provided filters.
    @filteredUsers = filterRecords([ 'section:1', 'recitation:2' ], @nsers);

	# Get all records (This isn't useful and just returns the passed in
	# array of records.  So don't actually do this.)
    @filteredUsers = filterRecords(undef, @users);

=head1 DESCRIPTION

This module provides functions for filtering records from the database.

=cut

use strict;
use warnings;

use Carp;

use WeBWorK::Utils qw(sortByName);
use WeBWorK::ContentGenerator::Instructor::ProblemSetDetail qw/FIELD_PROPERTIES/;

our @EXPORT_OK = qw(
	getFiltersForClass
	filterRecords
);

=head1 FUNCTIONS

=over

=item getFiltersForClass($class)

Given a list of database records, returns the filters available for those
records.  For all database records from the WeBWorK::DB::Record::User class
the filters are by section or recitation or no filter at all.  For all other
classes the only filter is no filter at all.

The return value is a reference to a list of two element lists. The first
element in each list is a a string description of the filter and the second
element is the filter name.  The return value is suitable for passing as the
second value argument to the Mojolicious select_field tag helper method.

=cut

sub getFiltersForClass {
	my (@records) = @_;

	my @filters;
	push @filters, [ "\x{27E8}Display all possible records\x{27E9}" => 'all', selected => undef ];

	if (ref $records[0] eq 'WeBWorK::DB::Record::User') {
		my (%sections, %recitations);

		for my $user (@records) {
			++$sections{ $user->section };
			++$recitations{ $user->recitation };
		}

		if (keys %sections > 1) {
			for my $sec (sortByName(undef, keys %sections)) {
				push @filters, [ ($sec ne '' ? "Section: $sec" : 'No Section') => "section:$sec" ];
			}
		}

		if (keys %recitations > 1) {
			for my $rec (sortByName(undef, keys %recitations)) {
				push @filters, [ ($rec ne '' ? "Recitation: $rec" : 'No Recitation') => "recitation:$rec" ];
			}
		}
	} elsif (ref $records[0] eq 'WeBWorK::DB::Record::Set') {
		my (%assignment_types, %visibles);

		for my $set (@records) {
			++$assignment_types{ $set->assignment_type };
			++$visibles{ $set->visible }
				unless (defined $visibles{0} && $set->visible eq '' || defined $visibles{''} && $set->visible eq '0');
		}

		if (keys %assignment_types > 1) {
			for my $type (sortByName(undef, keys %assignment_types)) {
				push @filters, [ FIELD_PROPERTIES()->{assignment_type}{labels}{$type} => "assignment_type:$type" ];
			}
		}

		if (keys %visibles > 1) {
			for my $vis (sortByName(undef, keys %visibles)) {
				push @filters, [ ($vis ? 'Visible' : "Not Visible") => "visible:$vis" ];
			}
		}
	}
	return \@filters;
}

=item filterRecords($filters, @records)

Given a list of filters and a list of records, returns a list of the records
after the selected filters are applied.

C<$filters> should be a reference to an array of filters or be undefined.

=back

=cut

sub filterRecords {
	my ($filters, @records) = @_;

	return unless @records;

	my @filtersToUse = @{ $filters // ['all'] };

	if (grep { $_ eq 'all' } @filtersToUse) {
		return @records;
	}

	my @filteredRecords;
	for my $record (@records) {
		for my $filter (@filtersToUse) {
			my ($name, $value) = split(/:/, $filter);
			if ($record->$name eq $value) {
				push @filteredRecords, $record;
				last;    # Only add a record once.
			}
		}
	}
	return @filteredRecords;
}

1;
