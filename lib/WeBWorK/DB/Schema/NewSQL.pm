################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Schema/NewSQL.pm,v 1.10 2006/10/10 18:15:22 sh002i Exp $
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
use WeBWorK::Utils qw/undefstr/;
use WeBWorK::DB::Utils qw/make_vsetID/;

use constant TABLES => qw(*);
use constant STYLE  => "dbi";

################################################################################
# where clauses (not sure if this is where these belong...)
################################################################################

sub where_set_id_eq {shift; {set_id=>shift} }
sub where_set_id_eq_problem_id_eq {shift; {set_id=>shift,problem_id=>shift} }
sub where_user_id_eq_set_id_eq {shift; {user_id=>shift,set_id=>shift} }

#sub where_section {shift; {section=>shift} }
#sub where_recitation {shift; {recitation=>shift} }

# VERSIONING
sub where_nonversionedset_user_id_eq
	{shift; {user_id=>shift,set_id=>{NOT_LIKE=>make_vsetID("%","%")}} }
sub where_versionedset_user_id_eq
	{shift; {user_id=>shift,set_id=>{LIKE=>make_vsetID("%","%")}} }
sub where_versionedset_user_id_eq_set_id_eq
	{shift; {user_id=>shift,setID=>{LIKE=>make_vsetID(shift,"%")}} }

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

sub conv_where {
	my ($self, $where) = @_;
	if (ref $where eq "ARRAY") {
		my ($clause, @args) = @$where;
		my $func = "where_$clause";
		croak "Unrecognized where clause '$clause'" unless $self->can($func);
		return $self->$func(@args);
	} else {
		return $where;
	}
}

sub keyparts_to_where {
	my ($self, @keyparts) = @_;
	
	my $table = $self->{table};
	my @keynames = $self->keyfields;
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

our $__PACKAGE__ = __PACKAGE__;
sub debug_stmt {
	my ($self, $sth, @bind_vals) = @_;
	return unless $self->{params}{debug};
	my ($subroutine) = (caller(1))[3];
	$subroutine =~ s/^${__PACKAGE__}:://;
	my $stmt = $sth->{Statement};
	@bind_vals = undefstr("#UNDEF#", @bind_vals);
	print STDERR "$subroutine: |$stmt| => |@bind_vals|\n";
}

################################################################################
# null implementations (to provide slightly nicer error messages)
################################################################################

our %API;
@API{qw/
	create_table
	rename_table
	delete_table
	count_where
	exists_where
	get_fields_where
	get_fields_where_i
	list_where
	list_where_i
	get_records_where
	get_records_where_i
	insert_fields
	insert_fields_i
	insert_records
	insert_records_i
	update_where
	update_fields
	update_fields_i
	update_records
	update_records_i
	delete_where
	delete_fields
	delete_fields_i
	delete_records
	delete_records_i
	count
	list
	exists
	get
	gets
	add
	put
	delete
/} = ();

sub AUTOLOAD {
	our $AUTOLOAD =~ /(.*)::(.*)/;
	if (exists $API{$2}) {
		croak sprintf("%s does not implement &%s", $1, $2);
	} else {
		croak sprintf("Undefined subroutine &%s called", $AUTOLOAD);
	}
}

1;
