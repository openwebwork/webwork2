################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Utils.pm,v 1.37 2003/12/09 01:12:30 sh002i Exp $
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
	WeBWorK::DB::Record::User => {
		"lnfn" => {
			name => "last name, first name",
			fields => [ qw/last_name first_name/ ],
		},
	},
};

sub getSortsForClass {
	my ($class) = @_;
	
	my %class_presets = exists PRESET_SORTS->{$class} ? %{ PRESET_SORTS->{$class} } : ();
	
	my @field_order = $class->FIELDS;
	my @preset_order = sort { $class_presets{$a}{name} cmp $class_presets{$b}{name} } keys %class_presets;
	
	my %fields = map { $_ => "Field: $_" } @field_order;
	my %presets = map { $_ => "Preset: $class_presets{$_}{name}" } @preset_order;
	
	return ( [@field_order, @preset_order], {%fields, %presets} );
}

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
		my $pack_key = sub { join "\0", map { $_[0]->$_ } @fields };
		
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

1;
