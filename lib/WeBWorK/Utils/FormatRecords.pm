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

WeBWorK::Utils::FormatRecords - utilities for formatting database records as strings.

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

1;







