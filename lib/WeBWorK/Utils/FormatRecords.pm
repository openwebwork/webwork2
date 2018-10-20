################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/FormatRecords.pm,v 1.9 2007/04/09 21:01:50 glarose Exp $
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
use WeBWorK::Utils qw/formatDateTime/;

our @EXPORT    = ();
our @EXPORT_OK = qw(
	getFormatsForClass
	formatRecords
);

use constant PRESET_FORMATS => {
	"WeBWorK::DB::Record::User" => {
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
	"WeBWorK::DB::Record::Set" => {
		"sid" => {
			name => "set_id",
			field_order => [ qw/set_id/ ],
		},
		#"sid_open" => {
		#	name => "set_id (open_date)",
		#	field_order => [ qw/set_id open_date/ ],
		#	format_function => sub { sprintf("%s (%s)", $_[0], formatDateTime($_[1])) }
		#},
		#"sid_due" => {
		#	name => "set_id (due_date)",
		#	field_order => [ qw/set_id due_date/ ],
		#	format_function => sub { sprintf("%s (%s)", $_[0], formatDateTime($_[1])) }
		#},
		#"sid_answer" => {
		#	name => "set_id (answer_date)",
		#	field_order => [ qw/set_id answer_date/ ],
		#	format_function => sub { sprintf("%s (%s)", $_[0], formatDateTime($_[1])) }
		#},
	},
        "WeBWorK::DB::Record::SetVersion" => {
                "sid" => {
                        name => "set_id",
                        field_order => [ qw/set_id/ ],
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

%options can consist of:

 preset => the name of a preset format listed by getFormatsForClass()

or:

 field_order   => a reference to a list of fields in the records' class
 format_string => an sprintf format string corresponding to the fields listed above

or:

 field_order     => a reference to a list of fields in the records' class
 format_function => a coderef to which to pass the contents of the fields in field_order

If C<preset> is given, and its value does not match any known preset but I<is>
the name of a field in the record class, the format is assumed to consist of
that single field.

If C<format_function> is given, the subroutine referenced is passed to contents
of each field listed in C<field_order>. The subroutine should return a formatted
string.

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
		} elsif (exists $class_fields{$preset}) {
			# it's the name of a field in the current class, in which case we treat it as
			# a "fields" sort with a single field
			%options = ( field_order => [ $preset ] );
		} else {
			croak "preset \"$preset\" not found for class \"$class\"";
		}
	}
	
	croak "field_order not found in options list" unless exists $options{field_order};
	croak "field_order is not an arrayref" unless ref $options{field_order} eq "ARRAY";
	my @field_order = @{ $options{field_order} };
	croak "field_order is empty -- no fields to display" unless @field_order;
	
	my $format_function;
	if (exists $options{format_function}) {
		croak "format_function is not a coderef" unless ref $options{format_function} eq "CODE";
		$format_function = $options{format_function};
	}
	
	# default format_string is "%s %s %s ... %s".
	my $format_string = $options{format_string} || "%s " x (@field_order-1) . "%s";
	
	if ($format_function) {
		# if we were passed format_function, call it on each record
		foreach my $value (values %Records) {
			# $value is initially a record, and is then replaced with a formatted string
			$value = $format_function->(map { $value->$_ } @field_order);
		}
	} else {
		# otherwise, use sprintf and format_string
		foreach my $value (values %Records) {
			# $value is initially a record, and is then replaced with a formatted string
			$value = sprintf($format_string, map { $value->$_ } @field_order);
		}
	}
	
	return %Records;
}

=back

=cut

=head1 BUGS

The calling semantics of formatRecords is somewhat inflexible. We shouldn't make
the user pass a hash if a list is sufficient for their use.

=cut

1;
