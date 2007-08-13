################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Schema/SQL.pm,v 1.32 2006/08/05 02:10:49 sh002i Exp $
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
use WeBWorK::Debug;

use constant TABLES => qw(*);
use constant STYLE  => "dbi";

{
	no warnings 'redefine';
	
	sub debug {
		my ($self, @string) = @_;
		WeBWorK::Debug::debug(@string) if $self->{params}->{debug};
	}
}

=head1 SUPPORTED PARAMS

This schema pays attention to the following items in the C<params> entry.

=over

=item tableOverride

Alternate name for this table, to satisfy SQL naming requirements.

=item fieldOverride

A reference to a hash mapping field names to alternate names, to satisfy SQL
naming requirements.

=back

=cut

################################################################################
# constructor for SQL-specific behavior
################################################################################

sub new {
	my ($proto, $db, $driver, $table, $record, $params) = @_;
	my $self = $proto->SUPER::new($db, $driver, $table, $record, $params);
	
	## override table name if tableOverride param is given
	#$self->{table} = $params->{tableOverride} if $params->{tableOverride};
	
	# add sqlTable field
	$self->{sqlTable} = $params->{tableOverride} || $self->{table};
	
	return $self;
}

################################################################################
# table access functions
################################################################################

sub count {
	my ($self, @keyparts) = @_;
	
	my $table = $self->{table};
	my $sqlTable = $self->{sqlTable};
	my @keynames = $self->sqlKeynames();
	
	croak "too many keyparts for table $table (need at most: @keynames)"
		if @keyparts > @keynames;
	
	my ($where, @where_args) = $self->makeWhereClause(@keyparts);
	
	my $stmt = "SELECT COUNT(*) FROM `$sqlTable` $where";
	$self->debug("SQL-count: $stmt\n");
	
	$self->{driver}->connect("ro");
	
	my $sth = $self->{driver}->dbi()->prepare($stmt);
	$sth->execute(@where_args);
	my ($result) = $sth->fetchrow_array;
	
	$self->{driver}->disconnect();
	
	return $result;
}

sub list($@) {
	my ($self, @keyparts) = @_;
	
	my $table = $self->{table};
	my $sqlTable = $self->{sqlTable};
	my @keynames = $self->sqlKeynames();
	my $keynames = join(", ", @keynames);
	
	croak "too many keyparts for table $table (need at most: @keynames)"
		if @keyparts > @keynames;
	
	my ($where, @where_args) = $self->makeWhereClause(@keyparts);
	
	my $stmt = "SELECT $keynames FROM `$sqlTable` $where";
	$self->debug("SQL-list: $stmt\n");
	
	$self->{driver}->connect("ro");
	
	my $sth = $self->{driver}->dbi()->prepare($stmt);
	$sth->execute(@where_args);
	my $result = $sth->fetchall_arrayref;
	
	$self->{driver}->disconnect();
	
	croak "failed to SELECT: $DBI::errstr" unless defined $result;
	return @$result;
}

sub exists($@) {
	my ($self, @keyparts) = @_;
	
	my $table = $self->{table};
	my $sqlTable = $self->{sqlTable};
	my @keynames = $self->sqlKeynames();
	
	croak "wrong number of keyparts for table $table (needs: @keynames)"
		unless @keyparts == @keynames;
	
	my ($where, @where_args) = $self->makeWhereClause(@keyparts);
	
	my $stmt = "SELECT COUNT(*) FROM `$sqlTable` $where";
	$self->debug("SQL-exists: $stmt\n");
	
	$self->{driver}->connect("ro");
	
	my $sth = $self->{driver}->dbi()->prepare($stmt);
	$sth->execute(@where_args);
	my ($result) = $sth->fetchrow_array;
	
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
	my $sqlTable = $self->{sqlTable};
	my @fieldnames = $self->sqlFieldnames();
	my $fieldnames = join(", ", @fieldnames);
	my $marks = join(", ", map { "?" } @fieldnames);
	
	my @realFieldnames = $self->{record}->FIELDS();
	my @fieldvalues = map { $Record->$_() } @realFieldnames;
	@fieldvalues = map { (defined($_) and $_ eq "") ? undef : $_ } @fieldvalues; # demote "" to undef
	
	my $stmt = "INSERT INTO `$sqlTable` ($fieldnames) VALUES ($marks)";
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
	
	return ($self->gets(\@keyparts))[0];
}

sub gets($@) {
	my ($self, @keypartsRefList) = @_;
	
	my $table = $self->{table};
	my $sqlTable = $self->{sqlTable};
	my @keynames = $self->sqlKeynames();
	
	my @records;
	$self->{driver}->connect("ro");
	foreach my $keypartsRef (@keypartsRefList) {
		my @keyparts = @$keypartsRef;
		
		croak "wrong number of keyparts for table $table (needs: @keynames)"
			unless @keyparts == @keynames;
		
		my ($where, @where_args) = $self->makeWhereClause(@keyparts);
		
		my $fieldnames = join(", ", $self->sqlFieldnames);
		my $stmt = "SELECT $fieldnames FROM `$sqlTable` $where";
		$self->debug("SQL-gets: $stmt\n");
		
		my $sth = $self->{driver}->dbi()->prepare($stmt);
		$sth->execute(@where_args);
		my $result = $sth->fetchrow_arrayref;
		
		if (defined $result) {
			my @record = @$result;
			my $Record = $self->{record}->new();
			my @realFieldnames = $self->{record}->FIELDS();
			foreach (@realFieldnames) {
				my $value = shift @record;
				$value = "" unless defined $value; # promote undef to ""
				$Record->$_($value);
			}
			push @records, $Record;
		} else {
			push @records, undef;
		}
	}
	$self->{driver}->disconnect();
	
	return @records;
}

# getAll($userID, $setID)
# 
# Returns all problems in a given set. Only supported for the problem and
# problem_user tables.

sub getAll {
	my ($self, @keyparts) = @_;
	my $table = $self->{table};
	my $sqlTable = $self->{sqlTable};
	
	croak "getAll: only supported for the problem_user table"
		unless $table eq "problem" or $table eq "problem_user";
	
	my @keynames = $self->sqlKeynames();
	pop @keynames; # get rid of problem_id
	
	my ($where, @where_args) = $self->makeWhereClause(@keyparts);
	
	my $fieldnames = join(", ", $self->sqlFieldnames);
	my $stmt = "SELECT $fieldnames FROM `$sqlTable` $where";
	$self->debug("SQL-getAll: $stmt\n");
	
	my @records;
	
	$self->{driver}->connect("ro");
	
	my $sth = $self->{driver}->dbi()->prepare($stmt);
	$sth->execute(@where_args);
	my $results = $sth->fetchall_arrayref;
	
	foreach my $result (@$results) {
		if (defined $result) {
			my @record = @$result;
			my $Record = $self->{record}->new();
			my @realFieldnames = $self->{record}->FIELDS();
			foreach (@realFieldnames) {
				my $value = shift @record;
				$value = "" unless defined $value; # promote undef to ""
				$Record->$_($value);
			}
			push @records, $Record;
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
	my $sqlTable = $self->{sqlTable};
	my @fieldnames = $self->sqlFieldnames();
	my $fieldnames = join(", ", @fieldnames);
	my $marks = join(", ", map { "?" } @fieldnames);
	
	my @realFieldnames = $self->{record}->FIELDS();
	my @fieldvalues = map { $Record->$_() } @realFieldnames;
	@fieldvalues = map { (defined($_) and $_ eq "") ? undef : $_ } @fieldvalues; # demote "" to undef
	
	my ($where, @where_args) = $self->makeWhereClause(map { $Record->$_() } @realKeynames);
	
	my $stmt = "UPDATE `$sqlTable` SET";
	while (@fieldnames) {
		$stmt .= " " . (shift @fieldnames) . "=?";
		$stmt .= "," if @fieldnames;
	}
	$stmt .= " $where";
	$self->debug("SQL-put: $stmt\n");
	
	$self->{driver}->connect("rw");
	my $sth = $self->{driver}->dbi()->prepare($stmt);
	my $result = $sth->execute(@fieldvalues, @where_args);
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
	my $sqlTable = $self->{sqlTable};
	my @keynames = $self->sqlKeynames();
	
	croak "wrong number of keyparts for table $table (needs: @keynames)"
		unless @keyparts == @keynames;
	
	my ($where, @where_args) = $self->makeWhereClause(@keyparts);
	
	my $stmt = "DELETE FROM `$sqlTable` $where";
	$self->debug("SQL-delete: $stmt\n");
	
	$self->{driver}->connect("rw");
	
	my $sth = $self->{driver}->dbi()->prepare($stmt);
	my $result = $sth->execute(@where_args);
	
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
	
	my $where = "";
	my @used_keyparts;
	
	my $first = 1;
	while (@keyparts) {
		my $name = shift @keynames;
		my $part = shift @keyparts;
		
		next unless defined $part;
		
		$where .= " AND" unless $first;
#		$where .= " BINARY $name=?";
		$where .= " $name=?";   ## Make lookups case insensitive.  Otherwise
								## indices seem not to be used which slows things
								## down drastically.  See  
								## openwebwork-devel@lists.sourceforge.net discussion
		push @used_keyparts, $part;
		
		$first = 0;
	}
	
	my $clause = $where ? "WHERE$where" : "";
	
	return ($clause, @used_keyparts);
}

sub sqlKeynames($) {
	my ($self) = @_;
	my @keynames = $self->{record}->KEYFIELDS();
	return map { "`$_`" } map { $self->{params}->{fieldOverride}->{$_} || $_ } @keynames;
}

sub sqlFieldnames($) {
	my ($self) = @_;
	my @keynames = $self->{record}->FIELDS();
	return map { "`$_`" } map { $self->{params}->{fieldOverride}->{$_} || $_ } @keynames;
}

1;
