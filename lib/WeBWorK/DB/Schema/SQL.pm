################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader$
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

package WeBWorK::DB::Schema::SQL;
use base qw(WeBWorK::DB::Schema);

=head1 NAME

WeBWorK::DB::Schema::SQL - support SQL access to all tables.

=cut

use strict;
use warnings;
use Carp qw(croak);

use constant TABLES => qw(*);
use constant STYLE  => "dbi";

################################################################################
# constructor for SQL-specific behavior
################################################################################

sub new {
	my ($proto, $db, $driver, $table, $record, $params) = @_;
	my $self = $proto->SUPER::new($db, $driver, $table, $record, $params);
	
	# override table name if tableOverride param is given
	$self->{table} = $params->{tableOverride} if $params->{tableOverride};
	
	return $self;
}

################################################################################
# table access functions
################################################################################

sub list($@) {
	my ($self, @keyparts) = @_;
	
	my $table = $self->{table};
	my @keynames = $self->sqlKeynames();
	my $keynames = join(", ", @keynames);
	
	croak "too many keyparts for table $table (need at most: @keynames)"
		if @keyparts > @keynames;
	
	my $stmt = "SELECT $keynames FROM $table ";
	$stmt .= $self->makeWhereClause(@keyparts);
	$self->debug("SQL-list: $stmt\n");
	
	$self->{driver}->connect("ro");
	my $result = $self->{driver}->dbi()->selectall_arrayref($stmt);
	$self->{driver}->disconnect();
	croak "failed to SELECT: $DBI::errstr" unless defined $result;
	return @$result;
}

sub exists($@) {
	my ($self, @keyparts) = @_;
	
	my $table = $self->{table};
	my @keynames = $self->sqlKeynames();
	
	croak "wrong number of keyparts for table $table (needs: @keynames)"
		unless @keyparts == @keynames;
	
	my $stmt = "SELECT COUNT(*) FROM $table ";
	$stmt .= $self->makeWhereClause(@keyparts);
	$self->debug("SQL-exists: $stmt\n");
	
	$self->{driver}->connect("ro");
	my ($result) = $self->{driver}->dbi()->selectrow_array($stmt);
	$self->{driver}->disconnect();
	croak "failed to SELECT: $DBI::errstr" unless defined $result;
	return $result > 0;
}

sub add($$) {
	my ($self, $Record) = @_;
	
	my @realKeynames = $self->{record}->KEYFIELDS();
	my @keyparts = map { $Record->$_() } @realKeynames;
	croak "(" . join(", ", @keyparts) . "): exists (use put)"
		if $self->exists(@keyparts);
	
	my $table = $self->{table};
	my @fieldnames = $self->sqlFieldnames();
	my $fieldnames = join(", ", @fieldnames);
	my $marks = join(", ", map { "?" } @fieldnames);
	
	my @realFieldnames = $self->{record}->FIELDS();
	my @fieldvalues = map { $Record->$_() } @realFieldnames;
	
	my $stmt = "INSERT INTO $table ($fieldnames) VALUES ($marks)";
	$self->debug("SQL-add: $stmt\n");
	
	$self->{driver}->connect("rw");
	my $sth = $self->{driver}->dbi()->prepare($stmt);
	my $result = $sth->execute(@fieldvalues);
	$self->{driver}->disconnect();
	
	unless (defined $result) {
		my @realKeynames = $self->{record}->KEYFIELDS();
		my @keyvalues = map { $Record->$_() } @realKeynames;
		croak "(" . join(", ", @keyvalues) . "): failed to INSERT: $DBI::errstr";
	}
	
	return 1;
}

sub get($@) {
	my ($self, @keyparts) = @_;
#	
#	my $table = $self->{table};
#	my @keynames = $self->sqlKeynames();
#	
#	croak "wrong number of keyparts for table $table (needs: @keynames)"
#		unless @keyparts == @keynames;
#	
#	my $stmt = "SELECT * FROM $table ";
#	$stmt .= $self->makeWhereClause(@keyparts);
#	$self->debug("SQL-get: $stmt\n");
#	
#	$self->{driver}->connect("ro");
#	my $result = $self->{driver}->dbi()->selectrow_arrayref($stmt);
#	$self->{driver}->disconnect();
#	# $result comes back undefined if there are no matches. hmm...
#	return undef unless defined $result;
#	
#	my @record = @$result;
#	my $Record = $self->{record}->new();
#	my @realFieldnames = $self->{record}->FIELDS();
#	foreach (@realFieldnames) {
#		$Record->$_(shift @record);
#	}
#	
#	return $Record;
	return ($self->gets(\@keyparts))[0];
}

sub gets($@) {
	my ($self, @keypartsRefList) = @_;
	
	my $table = $self->{table};
	my @keynames = $self->sqlKeynames();
	
	my @records;
	$self->{driver}->connect("ro");
	foreach my $keypartsRef (@keypartsRefList) {
		my @keyparts = @$keypartsRef;
		
		croak "wrong number of keyparts for table $table (needs: @keynames)"
			unless @keyparts == @keynames;
		
		my $stmt = "SELECT * FROM $table ";
		$stmt .= $self->makeWhereClause(@keyparts);
		$self->debug("SQL-get: $stmt\n");
		my $result = $self->{driver}->dbi()->selectrow_arrayref($stmt);
		
		if (defined $result) {
			my @record = @$result;
			my $Record = $self->{record}->new();
			my @realFieldnames = $self->{record}->FIELDS();
			foreach (@realFieldnames) {
				$Record->$_(shift @record);
			}
			push @records, $Record;
		} else {
			push @records, undef;
		}
	}
	$self->{driver}->disconnect();
	
	return @records;
}

sub put($$) {
	my ($self, $Record) = @_;
	
	my @realKeynames = $self->{record}->KEYFIELDS();
	my @keyparts = map { $Record->$_() } @realKeynames;
	croak "(" . join(", ", @keyparts) . "): not found (use add)"
		unless $self->exists(@keyparts);
	
	my $table = $self->{table};
	my @fieldnames = $self->sqlFieldnames();
	my $fieldnames = join(", ", @fieldnames);
	my $marks = join(", ", map { "?" } @fieldnames);
	
	my @realFieldnames = $self->{record}->FIELDS();
	my @fieldvalues = map { $Record->$_() } @realFieldnames;
	
	my $stmt = "UPDATE $table SET";
	while (@fieldnames) {
		$stmt .= " " . (shift @fieldnames) . "=?";
		$stmt .= "," if @fieldnames;
	}
	$stmt .= " ";
	$stmt .= $self->makeWhereClause(map { $Record->$_() } @realKeynames);
	$self->debug("SQL-put: $stmt\n");
	
	$self->{driver}->connect("rw");
	my $sth = $self->{driver}->dbi()->prepare($stmt);
	my $result = $sth->execute(@fieldvalues);
	$self->{driver}->disconnect();
	
	unless (defined $result) {
		croak "(" . join(", ", @keyparts) . "): failed to UPDATE: $DBI::errstr";
	}
	
	return 1;
}

sub delete($@) {
	my ($self, @keyparts) = @_;
	
	return 0 unless $self->exists(@keyparts);
	
	my $table = $self->{table};
	my @keynames = $self->sqlKeynames();
	
	croak "wrong number of keyparts for table $table (needs: @keynames)"
		unless @keyparts == @keynames;
	
	my $stmt = "DELETE FROM $table ";
	$stmt .= $self->makeWhereClause(@keyparts);
	$self->debug("SQL-delete: $stmt\n");
	
	$self->{driver}->connect("rw");
	my $result = $self->{driver}->dbi()->do($stmt);
	$self->{driver}->disconnect();
	croak "failed to DELETE: $DBI::errstr" unless defined $result;
	
	return $result;
}

################################################################################
# utility functions
################################################################################

sub makeWhereClause($@) {
	my ($self, @keyparts) = @_;
	
	my @keynames = $self->sqlKeynames();
	my $where;
	my $first = 1;
	while (@keyparts) {
		unless (defined $keyparts[0]) {
			shift @keynames;
			shift @keyparts;
			next;
		}
		$where .= " AND" unless $first;
		$where .= " " . (shift @keynames);
		$where .= "='" . (shift @keyparts) . "'";
		$first = 0;
	}
	
	return $where ? "WHERE$where" : "";
}

sub sqlKeynames($) {
	my ($self) = @_;
	my @keynames = $self->{record}->KEYFIELDS();
	return map { $self->{params}->{fieldOverride}->{$_} || $_ }
		@keynames;
}

sub sqlFieldnames($) {
	my ($self) = @_;
	my @keynames = $self->{record}->FIELDS();
	return map { $self->{params}->{fieldOverride}->{$_} || $_ }
		@keynames;
}

sub debug($@) {
	my ($self, @string) = @_;
	
	if ($self->{params}->{debug}) {
		warn @string;
	}
}

1;
