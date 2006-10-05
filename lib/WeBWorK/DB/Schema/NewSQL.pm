################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Schema/NewSQL.pm,v 1.7 2006/10/02 16:32:51 sh002i Exp $
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

package WeBWorK::DB::Schema::NewSQL;
use base qw(WeBWorK::DB::Schema);

=head1 NAME

WeBWorK::DB::Schema::NewSQL - base class for SQL access.

=cut

use strict;
use warnings;
use Carp qw(croak);
use WeBWorK::Debug;

use constant TABLES => qw(*);
use constant STYLE  => "dbi";

{
	no warnings 'redefine';
	
	sub debug {
		my ($self, @string) = @_;
		WeBWorK::Debug::debug(@string) if $self->{params}{debug};
	}
}

################################################################################
# utility methods
################################################################################

sub table {
	return shift->{table};
}

sub dbh {
	return shift->{driver}->dbi;
}

sub keyfields {
	return shift->{record}->KEYFIELDS;
}

sub nonkeyfields {
	return shift->{record}->NONKEYFIELDS;
}

sub fields {
	return shift->{record}->FIELDS;
}

sub field_data {
	return shift->{record}->FIELD_DATA;
}

sub box {
	my ($self, $values) = @_;
	
	my @names = $self->{record}->FIELDS;
	my %pairs;
	# promoting undef values to empty string. eventually we'd like to stop doing this (FIXME)
	@pairs{@names} = map { defined $_ ? $_ : "" } @$values;
	return $self->{record}->new(%pairs);
}

sub unbox {
	my ($self, $Record) = @_;
	
	my @result;
	foreach my $field ($self->{record}->FIELDS) {
		my $value = $Record->$field;
		# demote empty strings to undef. eventually we'd like to stop doing this (FIXME)
		$value = undef if defined $value and $value eq "";
		push @result, $value;
	}
	return \@result;
}

sub keyparts_to_where {
	my ($self, @keyparts) = @_;
	
	my $table = $self->{table};
	my @keynames = $self->keyfields;
	#croak "too many keyparts for table $table (need at most: @keynames)"
	croak "got ", scalar @keyparts, " keyparts, expected at most ", scalar @keynames, " (@keynames) for table $table"
		if @keyparts > @keynames;
	
	# generate a where clause for the keyparts spec
	my %where;
	
	foreach my $i (0 .. $#keyparts) {
		next if not defined $keyparts[$i]; # undefined keypart == not restrained
		$where{$keynames[$i]} = $keyparts[$i];
	}
	
	return \%where;
}

sub keyparts_list_to_where {
	my ($self, @keyparts_list) = @_;
	
	map { $_ = $self->keyparts_to_where(@$_) } @keyparts_list;
	return \@keyparts_list;
}

sub gen_update_hashes {
	my ($self, $fields) = @_;
	
	# the values for the values hash are the index of each field in the fields list
	my %values;
	@values{@$fields} = (0..@$fields-1);
	
	# the values for the where hash are the index of each keyfield in the fields list
	my @keyfields = $self->keyfields;
	my %where;
	@where{@keyfields} = map { exists $values{$_} ? $values{$_} : die "missing keypart '$_'" } @keyfields;
	
	# don't need to update keyfields, so take them out of the values hash
	delete @values{@keyfields};
	
	return \%values, \%where;
}

1;
