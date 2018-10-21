################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/SortRecords.pm,v 1.7 2006/09/25 22:14:54 sh002i Exp $
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
use base qw(Exporter);

=head1 NAME

WeBWorK::Utils::SortRecords - utilities for sorting database records.

=head1 SYNOPSIS

 use WeBWorK::Utils::SortRecords qw/getSortsForClass/;
 
 # get a list of sorts
 my ($sortsRef, $sortLabelsRef) = getSortsForClass(ref $Users[0]);
 my @sorts      = @$sortsRef;      # sort names
 my %sortLabels = %$sortLabelsRef; # suitable for CGI's "-labels" parameter

 use WeBWorK::Utils::SortRecords qw/sortRecords/;
 
 # start with a list of records
 my @Users = $db->getUsers($db->listUsers);
 
 # sort the records using a preset
 @SortedUsers = sortRecords({preset=>"lnfn"}, @Users);
 
 # or provide a custom sort
 @SortedUsers = sortRecords({fields=>[qw/section student_id/]}, @Users);

=head1 DESCRIPTION

This module provides record sorting functions, and a collection of preset sorts
for the standard WeBWorK record classes. Sorts are specified by a list
of field names. Sorts are performed lexicographically.

=cut

use strict;
use warnings;
use Carp;

our @EXPORT    = ();
our @EXPORT_OK = qw(
	getSortsForClass
	sortRecords
);

use constant PRESET_SORTS => {
	"WeBWorK::DB::Record::User" => {
		"lnfn" => {
			name => "last name, first name",
			fields => [ qw/last_name first_name/ ],
		},
	},
};

=head1 FUNCTIONS

=over

=item getSortsForClass($class)

Given the name of a record class, returns the preset sorts available for that
class.

The return value consists of a two-element list. The first element is a
reference to a list of sort names. The second element is a reference to a hash
mapping sort names to string descriptions.

Together, these two lists are suitable for passing to the C<-values> and
C<-labels> parameters of several CGI module methods, i.e. popup_menu(),
scrolling_list(), checkbox_group(), and radio_group().

=cut

sub getSortsForClass {
	my ($class) = @_;
	
	my %class_presets = exists PRESET_SORTS->{$class} ? %{ PRESET_SORTS->{$class} } : ();
	
	my @field_order = $class->FIELDS;
	my @preset_order = sort { $class_presets{$a}{name} cmp $class_presets{$b}{name} } keys %class_presets;
	
	my %fields = map { $_ => "Field: $_" } @field_order;
	my %presets = map { $_ => "Preset: $class_presets{$_}{name}" } @preset_order;
	
	return ( [@field_order, @preset_order], {%fields, %presets} );
}

=item sortRecords(\%options, @Records)

Given a sort specification (or the name of a preset format) and a list of
records, returns a list of the same records in order according to the sort.

%options can consist of either:

 preset => the name of a preset format listed by getFormatsForClass()

or:

 fields => a reference to a list of fields in the records' class

If C<preset> is given, and its value does not match any known preset but I<is>
the name of a field in the record class, the records will be sorted by that
field.

If C<fields> is given, the records are sorted according to the specified fields.
If multiple fields are specified, the second field is is consulted if two
records are found to have identical first fields, and so on.

=cut

# DBFIXME sorting should happen in database (ORDER BY clause)
# DBFIXME (but what about programmatic sorting, like intelligent setID sorting à la sortByName?)
sub sortRecords {
	my ($options, @Records) = @_;
	
	# nothing to do
	return () unless @Records;
	
	# get class info (we assume that the records are all of the same type)
	my $class = ref $Records[0];
	my %class_fields = map { $_ => 1 } $class->FIELDS;
	
	my %options = %$options;
	
	if (exists $options{"preset"}) {
		my $preset = $options{preset};
		
		if (exists PRESET_SORTS->{$class} and exists PRESET_SORTS->{$class}->{$preset}) {
			# an explicit preset exists
			# replace the contents of %options with the values from the preset
			%options = %{ PRESET_SORTS->{$class}->{$preset} };
		} elsif (exists $class_fields{$preset}) {
			# it's the name of a field in the current class, in which case we treat it as
			# a "fields" sort with a single field
			%options = ( fields => [ $preset ] );
		} else {
			croak "preset \"$preset\" not found for class \"$class\"";
		}
	}
	
	if (exists $options{fields}) {
		my @fields = @{ $options{fields} };
		
		# test for existence of fields in class
		foreach my $field (@fields) {
			croak "field \"$field\" is not a field in class \"$class\"" unless exists $class_fields{$field};
		}
		my $pack_key = sub { join "\0", map { lc $_[0]->$_ } @fields };
		
		# use the Orcish Maneuver to pack_key only once per record
		keys my %or_cache = @Records; # set number of hash buckets
		
		return sort {
			($or_cache{$a} ||= &$pack_key($a))
				cmp
			($or_cache{$b} ||= &$pack_key($b))
		} @Records;
	} else {
		croak "sort type missing from options. specify one of: preset, fields";
	}
}

=back

=head1 BUGS

No provision for case-insensitive, descending, or numeric sorting.

No provision for programmatic sorts. While a one-time programmatic sort can be
done easily without using this module, programmatic preset sorts would be
useful, i.e. for intelligent sorting of set IDs.

The fields being compared cannot contain nulls, because of the way packed keys
are being generated.

=cut

1;
