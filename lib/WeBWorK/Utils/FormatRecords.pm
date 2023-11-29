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

package WeBWorK::Utils::FormatRecords;
use parent qw(Exporter);

=head1 NAME

WeBWorK::Utils::FormatRecords - utilities for formatting database records as
strings.

=head1 SYNOPSIS

    use WeBWorK::Utils::FormatRecords qw/getFormatsForClass/;

	# Get a list of label => format pairs.  The $default_format will be marked
	# as the format that will be selected by default if provided.  Otherwise the
	# first format will be marked as selected by default.
    my $formats = getFormatsForClass(ref $Users[0], $default_formats);

    use WeBWorK::Utils::FormatRecords qw/formatRecords/;

    # Start with an array of database records
    my @records = $db->getUsers($db->listUsers);

	# Get a list of label => id pairs.  The labels are formatted according to
	# the provided $preset_format.
    my $formattedRecords = formatRecords('lnfn_uid', @records);

=head1 DESCRIPTION

This module provides record formatting functions, and a collection of preset
formats for the standard WeBWorK record classes. Formats are specified by a list
of field names and an sprintf format string.

The return values of these methods are suitable for passing as the second value
argument to the Mojolicious select_field tag helper method.

=cut

use strict;
use warnings;

use Carp;

use WeBWorK::Utils qw/format_set_name_display/;
use WeBWorK::ContentGenerator::Instructor::ProblemSetDetail qw/FIELD_PROPERTIES/;

our @EXPORT_OK = qw(
	getFormatsForClass
	formatRecords
);

use constant PRESET_FORMATS => {
	'WeBWorK::DB::Record::User' => [
		[
			'lnfn_email' => {
				name          => 'last_name, first_name (email_address)',
				field_order   => [qw/last_name first_name email_address/],
				format_string => '%s, %s (%s)',
			}
		],
		[
			'lnfn_recitation' => {
				name          => 'last_name, first_name (recitation)',
				field_order   => [qw/last_name first_name recitation/],
				format_string => '%s, %s (%s)',
			}
		],
		[
			'lnfn_section' => {
				name          => 'last_name, first_name (section)',
				field_order   => [qw/last_name first_name section/],
				format_string => '%s, %s (%s)',
			}
		],
		[
			'lnfn_secrec' => {
				name          => 'last_name, first_name (section/recitation)',
				field_order   => [qw/last_name first_name section recitation/],
				format_string => '%s, %s (%s/%s)',
			}
		],
		[
			'lnfn_uid' => {
				name          => 'last_name, first_name (user_id)',
				field_order   => [qw/last_name first_name user_id/],
				format_string => '%s, %s (%s)',
			}
		],
		[
			'uid_lnfn' => {
				name          => 'user_id - last_name, first_name',
				field_order   => [qw/user_id last_name first_name/],
				format_string => '%s - %s, %s',
			}
		],
	],
	'WeBWorK::DB::Record::Set' => [
		[
			'type_sid_due' => {
				name            => 'assignment_type: set_id, due_date',
				field_order     => [qw/assignment_type set_id due_date/],
				format_function => sub {
					join('',
						FIELD_PROPERTIES()->{assignment_type}{labels}{ $_[1] },
						': ', format_set_name_display($_[2]),
						', ', $_[0]->formatDateTime($_[3]));
				}
			}
		],
		[
			'due_sid' => {
				name            => 'due_date: set_id',
				field_order     => [qw/due_date set_id/],
				format_function => sub {
					join('', $_[0]->formatDateTime($_[1]), ': ', format_set_name_display($_[2]));
				}
			}
		],
		[
			'sid' => {
				name            => 'set_id',
				field_order     => [qw/set_id/],
				format_function => sub {
					return format_set_name_display($_[1]);
				}
			}
		],
	],
};

=head1 FUNCTIONS

=over

=item getFormatsForClass($class, $default_format)

Given the name of a record class, returns the preset formats available for that
class.

The return value is a reference to a list of two element lists. The first
element in each list is a a string description of a format name and the second
element is the format name.  The return value is suitable for passing as the
second value argument to the Mojolicious select_field tag helper method.

If the C<$default_format> is provided then that format will be marked as the
default selected format.  Otherwise the first format will be marked as the
default selected format.

=cut

sub getFormatsForClass {
	my ($class, $default_format) = @_;

	my @class_presets = exists PRESET_FORMATS->{$class} ? @{ PRESET_FORMATS->{$class} } : ();

	$default_format ||= $class_presets[0][0];

	my @presets =
		map { [ $_->[1]{name} => $_->[0], $_->[0] eq $default_format ? (selected => undef) : () ] } @class_presets;

	return \@presets;
}

=item formatRecords($c, $preset_format, @records)

Given the name of a preset format and an array of database records, returns a
reference to a list of two element lists. The first element in each list is a
formatted string representing the record, and the second element is a string
that is obtained by joining the key fields of the database record with
exclamation marks.

The arguments C<$c> and C<$preset_format> must be provided. C<$c> must be a
C<WeBWorK::Controller> object, and C<$preset_format> must either be one of the
presets defined above, or the name of a field in the database record class.

=back

=cut

sub formatRecords {
	my ($c, $preset_format, @records) = @_;

	return unless @records;

	# Get class info.  It is assumed that the records are all of the same class after the "Version" suffix is removed.
	my $class = (ref $records[0]) =~ s/Version$//r;

	my %options;

	if ($preset_format) {
		if (exists PRESET_FORMATS->{$class}
			&& (my $preset = (grep { $_->[0] eq $preset_format } @{ PRESET_FORMATS->{$class} })[0]))
		{
			# An explicit preset exists.
			%options = %{ $preset->[1] };
		} elsif (grep { $_ eq $preset_format } $class->FIELDS) {
			# The preset is the name of a field in the current class, in which
			# case treat it as a "fields" sort with a single field.
			%options = (field_order => [$preset_format]);
		} else {
			croak qq{preset format "$preset_format" not found for class "$class"};
		}
	} else {
		croak 'A preset format must be provided.';
	}

	croak 'field_order not found in options list' unless exists $options{field_order};
	croak 'field_order is not an arrayref'        unless ref $options{field_order} eq 'ARRAY';
	my @field_order = @{ $options{field_order} };
	croak 'field_order is empty -- no fields to display' unless @field_order;

	my $format_function;
	if (exists $options{format_function}) {
		croak 'format_function is not a coderef' unless ref $options{format_function} eq 'CODE';
		$format_function = $options{format_function};
	}

	my @keyfields = $class->KEYFIELDS;

	my @formattedRecords;

	if ($format_function) {
		# If a format_function was passed, then call it on each record.
		for my $value (@records) {
			push(
				@formattedRecords,
				[
					$format_function->($c, map { $value->$_ } @field_order),
					join('!', map { $value->$_ } @keyfields)
				]
			);
		}
	} else {
		# Otherwise, use sprintf and format_string.
		for my $value (@records) {
			push(
				@formattedRecords,
				[
					sprintf(
						$options{format_string} || '%s ' x (@field_order - 1) . '%s',
						map { $value->$_ } @field_order
					),
					join('!', map { $value->$_ } @keyfields)
				]
			);
		}
	}

	return \@formattedRecords;
}

1;
