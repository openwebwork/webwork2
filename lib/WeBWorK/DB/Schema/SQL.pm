################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Schema::SQL;

=head1 NAME

WeBWorK::DB::Schema::SQL - support SQL access to all tables.

=cut

use strict;
use warnings;

use constant TABLES => qw(password permission key user set set_user problem problem_user);
use constant STYLE  => "sql";

################################################################################
# static functions
################################################################################

sub tables() {
	return TABLES;
}

sub style() {
	return STYLE;
}

################################################################################
# constructor
################################################################################

sub new($$$) {
	my ($proto, $driver, $table, $record, $params) = @_;
	my $class = ref($proto) || $proto;
	die "$table: unsupported table"
		unless grep { $_ eq $table } $proto->tables();
	die $driver->style(), ": style mismatch"
		unless $driver->style() eq $proto->style();
	my $self = {
		driver => $driver,
		table  => $table,
		record => $record,
		params => $params,
	};
	$self->{table} = $params->{tableOverride} if $params->{tableOverride};
	bless $self, $class;
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
	
	die "too many keyparts for table $table (need at most: @keynames)"
		if @keyparts > @keynames;
	
	my $stmt = "SELECT $keynames FROM $table ";
	$stmt .= $self->makeWhereClause(@keyparts);
	warn "SQL-list: $stmt\n";
	
	$self->{driver}->connect("ro");
	my $result = $self->{driver}->handle()->selectall_arrayref($stmt);
	$self->{driver}->disconnect();
	die "failed to SELECT: $DBI::errstr" unless defined $result;
	return @$result;
}

sub exists($@) {
	my ($self, @keyparts) = @_;
	
	my $table = $self->{table};
	my @keynames = $self->sqlKeynames();
	
	die "wrong number of keyparts for table $table (needs: @keynames)"
		unless @keyparts == @keynames;
	
	my $stmt = "SELECT COUNT(*) FROM $table ";
	$stmt .= $self->makeWhereClause(@keyparts);
	warn "SQL-exists: $stmt\n";
	
	$self->{driver}->connect("ro");
	my ($result) = $self->{driver}->handle()->selectrow_array($stmt);
	$self->{driver}->disconnect();
	die "failed to SELECT: $DBI::errstr" unless defined $result;
	return $result > 0;
}

sub add($$) {
	my ($self, $Record) = @_;
	
	my @realKeynames = $self->{record}->KEYFIELDS();
	my @keyparts = map { $Record->$_() } @realKeynames;
	die "(" . join(", ", @keyparts) . "): exists (use put)"
		if $self->exists(@keyparts);
	
	my $table = $self->{table};
	my @fieldnames = $self->sqlFieldnames();
	my $fieldnames = join(", ", @fieldnames);
	my $marks = join(", ", map { "?" } @fieldnames);
	
	my @realFieldnames = $self->{record}->FIELDS();
	my @fieldvalues = map { $Record->$_() } @realFieldnames;
	
	my $stmt = "INSERT INTO $table ($fieldnames) VALUES ($marks)";
	warn "SQL-add: $stmt\n";
	
	$self->{driver}->connect("rw");
	my $sth = $self->{driver}->handle()->prepare($stmt);
	my $result = $sth->execute(@fieldvalues);
	$self->{driver}->disconnect();
	
	unless (defined $result) {
		my @realKeynames = $self->{record}->KEYFIELDS();
		my @keyvalues = map { $Record->$_() } @realKeynames;
		die "(" . join(", ", @keyvalues) . "): failed to INSERT: $DBI::errstr";
	}
	
	return 1;
}

sub get($@) {
	my ($self, @keyparts) = @_;
	
	my $table = $self->{table};
	my @keynames = $self->sqlKeynames();
	
	die "wrong number of keyparts for table $table (needs: @keynames)"
		unless @keyparts == @keynames;
	
	my $stmt = "SELECT * FROM $table ";
	$stmt .= $self->makeWhereClause(@keyparts);
	warn "SQL-get: $stmt\n";
	
	$self->{driver}->connect("ro");
	my $result = $self->{driver}->handle()->selectrow_arrayref($stmt);
	$self->{driver}->disconnect();
	# $result comes back undefined if there are no matches. hmm...
	#die "failed to SELECT: $DBI::errstr" unless defined $result;
	return undef unless defined $result;
	
	my @record = @$result;
	my $Record = $self->{record}->new();
	my @realFieldnames = $self->{record}->FIELDS();
	foreach (@realFieldnames) {
		$Record->$_(shift @record);
	}
	
	return $Record;
}

sub put($$) {
	my ($self, $Record) = @_;
	
	my @realKeynames = $self->{record}->KEYFIELDS();
	my @keyparts = map { $Record->$_() } @realKeynames;
	die "(" . join(", ", @keyparts) . "): not found (use add)"
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
	warn "SQL-put: $stmt\n";
	
	$self->{driver}->connect("rw");
	my $sth = $self->{driver}->handle()->prepare($stmt);
	my $result = $sth->execute(@fieldvalues);
	$self->{driver}->disconnect();
	
	unless (defined $result) {
		#my @realKeynames = $self->{record}->KEYFIELDS();
		#my @keyvalues = map { $Record->$_() } @realKeynames;
		die "(" . join(", ", @keyparts) . "): failed to UPDATE: $DBI::errstr";
	}
	
	return 1;
}

sub delete($@) {
	my ($self, @keyparts) = @_;
	
	die "(" . join(", ", @keyparts) . "): not found"
		unless $self->exists(@keyparts);
	
	my $table = $self->{table};
	my @keynames = $self->sqlKeynames();
	
	die "wrong number of keyparts for table $table (needs: @keynames)"
		unless @keyparts == @keynames;
	
	my $stmt = "DELETE FROM $table ";
	$stmt .= $self->makeWhereClause(@keyparts);
	warn "SQL-delete: $stmt\n";
	
	$self->{driver}->connect("rw");
	my $result = $self->{driver}->handle()->do($stmt);
	$self->{driver}->disconnect();
	die "failed to DELETE: $DBI::errstr" unless defined $result;
	
	if ($result > 1) {
		warn "danger! deleted more than one record!";
	}
	
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

1;
