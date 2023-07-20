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

package WeBWorK::Utils::SortRecords;
use parent qw(Exporter);

=head1 NAME

WeBWorK::Utils::SortRecords - utilities for sorting database records.

=head1 SYNOPSIS

    use WeBWorK::Utils::SortRecords qw/getSortsForClass/;

    # Get a list of sorts
    my $sorts = getSortsForClass(ref $users[0], $default_sort);

    use WeBWorK::Utils::SortRecords qw/sortRecords/;

    # Start with a list of records
    my @users = $db->getUsers($db->listUsers);

    # Sort the records using a preset.
    @sortedUsers = sortRecords('lnfn', @users);

    # Sort on a database field for the records.
    @sortedUsers = sortRecords('section', @users);

=head1 DESCRIPTION

This module provides record sorting functions, and a collection of preset sorts
for the standard WeBWorK record classes. Sorts are specified by a list
of field names. Sorts are performed lexicographically.

=cut

use strict;
use warnings;

use Carp;

our @EXPORT_OK = qw(getSortsForClass sortRecords);

use constant PRESET_SORTS => {
	'WeBWorK::DB::Record::User' => [
		[
			'lnfn' => {
				name   => 'last name, first name',
				fields => [qw/last_name first_name/],
			}
		],
	],
};

=head1 FUNCTIONS

=over

=item getSortsForClass($class, $default_sort)

Given the name of a record class, returns the sort methods available for that
class.

The return value is a reference to a list of two element lists. The first
element in each list is a a string description of the sort method and the second
element is the sort name.  The return value is suitable for passing as the
second value argument to the Mojolicious select_field tag helper method.

If the C<$default_sort> is provided then that sort will be marked as the
default selected sort.  Otherwise the first sort will be marked as the
default selected sort.

=cut

sub getSortsForClass {
	my ($class, $default_sort) = @_;

	my @class_presets = exists PRESET_SORTS->{$class} ? @{ PRESET_SORTS->{$class} } : ();

	my @fields  = map { [ "Field: $_" => $_, $_ eq $default_sort ? (selected => undef) : () ] } $class->FIELDS;
	my @presets = map { [ "Preset: $_->[1]{name}" => $_->[0], $_->[0] eq $default_sort ? (selected => undef) : () ] }
		@class_presets;

	return [ @fields, @presets ];
}

=item sortRecords($preset_sort, @records)

Given a preset format or a field from a database record class, and a list of
records, returns a list of the same records in order according to the sort.

The C<$preset_sort> must be provided.  It must either be one of the presets
defined above, or the name of a field in the database record class.

=back

=cut

sub sortRecords {
	my ($preset_sort, @records) = @_;

	return unless @records;

	# Get class info.  It is assumed that the records are all of the same class after the "Version" suffix is removed.
	my $class = (ref $records[0]) =~ s/Version$//r;

	my @fields;

	if ($preset_sort) {
		if (exists PRESET_SORTS->{$class}
			&& (my $preset = (grep { $_->[0] eq $preset_sort } @{ PRESET_SORTS->{$class} })[0]))
		{
			# An explicit preset exists.
			@fields = @{ $preset->[1]{fields} };
		} elsif (grep { $_ eq $preset_sort } $class->FIELDS) {
			# The preset is the name of a field in the current class, in which
			# case treat it as a "fields" sort with a single field.
			@fields = ($preset_sort);
		} else {
			croak qq{preset sort "$preset_sort" not found for class "$class"};
		}
	} else {
		croak 'A preset sort must be provided.';
	}

	my $pack_key = sub {
		join("\0", map { lc $_[0]->$_ } @fields);
	};

	# Use the Orcish Maneuver to pack_key only once per record
	keys my %or_cache = @records;    # Set the number of hash buckets.

	@records = sort { ($or_cache{$a} ||= $pack_key->($a)) cmp($or_cache{$b} ||= $pack_key->($b)) } @records;
	return @records;
}

1;
