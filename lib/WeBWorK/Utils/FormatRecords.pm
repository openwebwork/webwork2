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

package WeBWorK::Utils::FormatRecords;
use base qw(Exporter);

=head1 NAME

WeBWorK::Utils::FormatRecords - utilities for formatting database records as
strings.

=head1 SYNOPSIS

 use WeBWorK::Utils::FormatRecords qw/getFormatsForClass/;
 
 # get a list of formats
 my ($formatsRef, $formatLabelsRef) = getFormatsForClass(ref $Users[0]);
 my @formats      = @$formatsRef;      # format names
 my %formatLabels = %$formatLabelsRef; # suitable for CGI's "-labels" parameter

 use WeBWorK::Utils::FormatRecords qw/formatRecords/;
 
 # start with a hash mapping identifiers to records
 my %Records = map { $_->user_id => $_ } $db->getUsers($db->listUsers);
 
 # format the records using a preset
 my %recordLabels = formatRecords({preset=>"lnfn_uid"}, %Records);
 
 # or provide a custom format
 my %options = {
 	field_order   => [ qw/user_id section recitation/ ],
 	format_string => "%s %s/%s", # suitable for sprintf
 };
 my %recordLabels = formatRecords(\%options, %Records);
 
 # %recordLabels is suitable for CGI's "-labels" parameter

=head1 DESCRIPTION

This module provides record formatting functions, and a collection of preset
formats for the standard WeBWorK record classes. Formats are specified by a list
of field names and an sprintf format string.

=cut

use strict;
use warnings;
use Carp;

our @EXPORT    = ();
our @EXPORT_OK = qw(
	getFormatsForClass
	formatRecords
);

use constant PRESET_FORMATS => {
	WeBWorK::DB::Record::User => {
		"uid_lnfn" => {
			name => "user_id - last_name, first_name",
			field_order => [ qw/user_id last_name first_name/ ],
			format_string => "%s - %s, %s",
		},
		"lnfn_uid" => {
			name => "last_name, first_name (user_id)",
			field_order => [ qw/last_name first_name user_id/ ],
			format_string => "%s, %s (%s)",
		},
		"lnfn_section" => {
			name => "last_name, first_name (section)",
			field_order => [ qw/last_name first_name section/ ],
			format_string => "%s, %s (%s)",
		},
		"lnfn_recitation" => {
			name => "last_name, first_name (recitation)",
			field_order => [ qw/last_name first_name recitation/ ],
			format_string => "%s, %s (%s)",
		},
		"lnfn_secrec" => {
			name => "last_name, first_name (section/recitation)",
			field_order => [ qw/last_name first_name section recitation/ ],
			format_string => "%s, %s (%s/%s)",
		},
		"lnfn_email" => {
			name => "last_name, first_name (email_address)",
			field_order => [ qw/last_name first_name email_address/ ],
			format_string => "%s, %s (%s)",
		},
	},
};

=head1 FUNCTIONS

=over

=item getFormatsForClass($class)

Given the name of a record class, returns the preset formats available for that
class.

The return value consists of a two-element list. The first element is a
reference to a list of format names. The second element is a reference to a hash
mapping format names to string descriptions.

Together, these two lists are suitable for passing to the C<-values> and
C<-labels> parameters of several CGI module methods, i.e. popup_menu(),
scrolling_list(), checkbox_group(), and radio_group().

=cut

sub getFormatsForClass {
	my ($class) = @_;
	
	my %class_presets = exists PRESET_FORMATS->{$class} ? %{ PRESET_FORMATS->{$class} } : ();
	
	# i don't think we want formats consisting of a single field, so these are disabled
	#my @field_order = $class->FIELDS;
	my @preset_order = sort { $class_presets{$a}{name} cmp $class_presets{$b}{name} } keys %class_presets;
	
	#my %fields = map { $_ => "Field: $_" } @field_order;
	#my %presets = map { $_ => "Preset: $class_presets{$_}{name}" } @preset_order;
	my %presets = map { $_ => $class_presets{$_}{name} } @preset_order;
	
	#return ( [@field_order, @preset_order], {%fields, %presets} );
	return ( \@preset_order, \%presets );
}

=item formatRecords(\%options, %Records)

Given a format specification (or the name of a preset format) and a hash mapping
record identifiers to records, returns a hash mapping identifiers to formatted
strings.

The keys of the %Records hash are not used by formatRecords() They are a
convenience for you.

%options can consist of either:

 preset => the name of a preset format listed by getFormatsForClass()

or:

 field_order   => a reference to a list of fields in the records' class
 format_string => an sprintf format string corresponding to the fields listed above

The return value is suitable for passing to the C<-labels> parameter of several
CGI module methods, i.e. popup_menu(), scrolling_list(), checkbox_group(), and
radio_group().

=cut

sub formatRecords {
	my ($options, %Records) = @_;
	
	# nothing to do
	return () unless %Records;
	
	# get class info (we assume that the records are all of the same type)
	my ($tempKey, $tempValue) = each %Records;
	my $class = ref $tempValue;
	my %class_fields = map { $_ => 1 } $class->FIELDS;
	
	my %options = %$options;
	
	if (exists $options{"preset"}) {
		my $preset = $options{preset};
		
		if (exists PRESET_FORMATS->{$class} and exists PRESET_FORMATS->{$class}->{$preset}) {
			# an explicit preset exists
			# replace the contents of %options with the values from the preset
			%options = %{ PRESET_FORMATS->{$class}->{$preset} };
		} else {
			croak "preset \"$preset\" not found for class \"$class\"";
		}
	}
	
	croak "field_order not found in options list" unless exists $options{field_order};
	croak "field_order is not an arrayref" unless ref $options{field_order} eq "ARRAY";
	my @field_order = @{ $options{field_order} };
	croak "field_order is empty -- no fields to display" unless @field_order;
	
	# default format_string is "%s %s %s ... %s".
	my $format_string = $options{format_string} || "%s " x (@field_order-1) . "%s";
	
	foreach my $value (values %Records) {
		# $value is initially a record, and is then replaced with a formatted string
		#warn "value=$value\n";
		$value = sprintf($format_string, map { $value->$_ } @field_order);
		#warn "value=$value\n";
	}
	
	#warn join("\n", values %Records), "\n";
	
	return %Records;
}

=head1 BUGS

The calling semantics of formatRecords is somewhat inflexible. We shouldn't make
the user pass a hash if a list is sufficient for their use.

No provision for programmatic formats, which are required for formatting dates.

=back

=cut

1;
