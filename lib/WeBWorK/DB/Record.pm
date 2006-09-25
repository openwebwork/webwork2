################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Record.pm,v 1.9 2006/01/25 23:13:54 sh002i Exp $
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

package WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record - common functionality for Record classes.

=cut

use strict;
use warnings;
use Carp;

=head1 CONSTRUCTOR

=over

=item new($Prototype)

Create a new record object, set initial values from the record object
$Prototype, which must be a subclass of WeBWorK::DB::Record.

=item new(%fields)

Create a new record object, set initial values from the hash %fields, which
must contain keys equal to the field names of the record class.

=cut

sub new {
	my ($invocant, @rest) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {};
	
	if (@rest) {
		if ((ref $rest[0]) =~ /^WeBWorK::DB::Record/) {
			my $prototype = $rest[0];
			foreach ($invocant->FIELDS) {
				$self->{$_} = $prototype->{$_}
					if exists $prototype->{$_};
			}
		} elsif (@rest % 2 == 0) {
			my %fields = @rest;
			foreach ($invocant->FIELDS) {
				$self->{$_} = $fields{$_}
					if exists $fields{$_};
			}
		}
	}
	
	bless $self, $class;
	return $self;
}

=back

=head1 BASE METHODS

=over

=item idsToString

Returns a string representation of the object's keyfields.

=cut

sub idsToString {
	my $self = shift;
	return join " ", map { "$_=" . (defined $self->$_ ? "'".$self->$_."'" : "undef") } $self->KEYFIELDS;
}

=item idsToString

Returns a string representation of the object's fields.

=cut

sub toString {
	my $self = shift;
	return join " ", map { "$_=" . (defined $self->$_ ? "'".$self->$_."'" : "undef") } $self->FIELDS;
}

=item toHash

Returns a hash representation of the object's fields. If interpreted as a list,
the fields will be in order.

=cut

sub toHash {
	my $self = shift;
	return map { $_ => $self->$_ } $self->FIELDS;
}

=back

=cut

sub _fields {
	my $invocant = shift;
	my $class = ref $invocant || $invocant;
	my @field_data = @_;
	
	my %field_data = @field_data;
	my @field_order = @field_data[ grep {$_%2==0} 0..$#field_data ];
	my @keyfields = grep { $field_data{$_}{key} } @field_order;
	my @nonkeyfields = grep { not $field_data{$_}{key} } @field_order;
	my @sql_types = map { $field_data{$_}{type} } @field_order;
	
	no strict 'refs';
	
	# class methods that return field info
	*{$class."::FIELD_DATA"} = sub { return %field_data };
	*{$class."::FIELDS"} = sub { return @field_order };
	*{$class."::KEYFIELDS"} = sub { return @keyfields };
	*{$class."::NONKEYFIELDS"} = sub { return @nonkeyfields };
	*{$class."::SQL_TYPES"} = sub { return @sql_types };
	
	# accessor functions
	foreach my $field (@field_order) {
		# always define a "base" accessor
		# custom public accessors can use this to actually do the getting and setting
		*{$class."::_base_$field"} = sub {
			my $self = shift;
			$self->{$field} = shift if @_;
			return $self->{$field};
		};
		# if there isn't a public accessor in the subclass, alias it to the base accessor
		next if exists ${$class."::"}{$field};
		*{$class."::$field"} = *{$class."::_base_$field"};
	}
}

1;
