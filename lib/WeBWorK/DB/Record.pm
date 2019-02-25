################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Record.pm,v 1.13 2007/07/22 05:25:14 sh002i Exp $
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
	my $invocant = shift;
	my $self = bless {}, ref($invocant) || $invocant;
	
	if (@_) {
		if (UNIVERSAL::isa($_[0], __PACKAGE__)) {
			$self->init_from_object($_[0]);
		} elsif (ref $_[0] eq "HASH") {
			$self->init_from_hashref($_[0]);
		} elsif (ref $_[0] eq "ARRAY") {
			$self->init_from_arrayref($_[0]);
		} else {
			$self->init_from_hashref({@_});
		}
	}
	
	return $self;
}

# this will have to be changed if we actually implement any custom accessors/mutators
sub init_from_object { shift->init_from_hashref(shift) }

sub init_from_hashref {
	my ($self, $prototype) = @_;
	@$self{$self->FIELDS} = @$prototype{$self->FIELDS};
}

sub init_from_arrayref {
	my ($self, $prototype) = @_;
	@$self{$self->FIELDS} = @$prototype;
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

=item toArray

Returns an array representation of the object's fields.

=cut

sub toArray {
	my $self = shift;
	return map { $self->$_ } $self->FIELDS;
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
	*{$class."::FIELD_DATA"} = sub { return \%field_data };
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

sub _initial_records {
	my $invocant = shift;
	my $class = ref $invocant || $invocant;
	my @initializers = @_;
	
	no strict 'refs';
	*{$class."::INITIAL_RECORDS"} = sub { return @initializers };
}

1;

