################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Record.pm,v 1.7 2004/04/27 02:10:33 sh002i Exp $
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

=back

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

sub can {
	my ($self, $function) = @_;
	return grep { $_ eq $function } $self->FIELDS;
}

sub AUTOLOAD {
	my ($self, @args) = @_;
	our $AUTOLOAD;
	my ($package, $function) = $AUTOLOAD =~ m/^(.*)::(.*)$/;
	return if $function eq "DESTROY";
	if (grep { $_ eq $function } $self->FIELDS) {
		$self->{$function} = $args[0] if @args;
		return $self->{$function};
	} else {
		croak "Undefined subroutine $package\::$function called";
	}
}

sub idsToString {
	my $self = shift;
	return join " ", map { "$_=" . (defined $self->$_() ? $self->$_() : "") } $self->KEYFIELDS;
}

sub toString {
	my $self = shift;
	my $result;
	foreach ($self->FIELDS) {
		$result .= "$_ => ";
		$result .= defined $self->$_() ? $self->$_() : "";
		$result .= "\n";
	}
	return $result;
}

sub toHash {
	my ($self) = @_;
	return %$self;
}

1;
