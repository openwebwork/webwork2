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
	bless $self, $class;
	return $self;
}

################################################################################
# table access functions
################################################################################

sub list($) {
	my ($self, @keyparts) = @_;
	
	my $table = $self->{table};
	my @keynames = $self->{record}->KEYFIELDS();
	my $keynames = join(", ", @keynames);
	my $stmt = "SELECT $keynames FROM $table";
	$stmt .= " WHERE" if @keyparts;
	while (@keyparts) {
		$stmt .= " " . shift @keynames . "=" . shift @keyparts;
		$stmt .= " AND" if @keyparts;
	}
	
	$self->{driver}->connect("ro");
	my $keys = $self->{driver}->handle()->selectall_arrayref($stmt);
	$self->{driver}->disconnect();
	
	unless (defined $keys) {
		die "failed to SELECT: $DB::errstr";
	}
	
	return $keys;
}

sub exists($$) {
	my ($self, @keyparts) = @_;
	
	my $table = $self->{table};
	my @keynames = $self->{record}->KEYFIELDS();
	
	die "wrong number of keyparts for table $table (needs: @keynames)"
		unless (@keyparts == @keynames);
	
	my $stmt = "SELECT COUNT(*) FROM $table WHERE";
	while (@keyparts) {
		$stmt .= " " . shift @keynames . "=" . shift @keyparts;
		$stmt .= " AND" if @keyparts;
	}
	
	$self->{driver}->connect("ro");
	my $exists = $self->{driver}->handle()->do($stmt);
	$self->{driver}->disconnect();
	
	unless (defined $exists) {
		die "failed to SELECT: $DB::errstr";
	}
	
	return $exists;
}

sub add($$) {
	my ($self, $Record) = @_;
	
	my $table = $self->{table};
	my @fieldnames = $self->{record}->FIELDS();
	my $fieldnames = join(", ", @fieldnames);
	my @fieldvalues = map { $Record->$_() } @fieldnames;
	my $marks = join(", ", map { "?" } @fieldnames);
	my $stmt = "INSERT INTO $table ($fieldnames) VALUES ($marks)";
	
	$self->{driver}->connect("rw");
	my $sth = $self->{driver}->handle()->prepare($stmt);
	my $result = $sth->execute(@fieldvalues);
	$self->{driver}->disconnect();
	
	unless (defined $result) {
		my @keynames = $self->{record}->KEYFIELDS();
		my @keyvalues = map $Record->$_() } @keynames;
		die "(@keyvalues): failed to INSERT: $DB::errstr";
	}
	
	return 1;
}

sub get($$) {
	my ($self, @keyfields) = @_;
	
	my $table = $self->{table};
	my @keynames = $self->{record}->KEYFIELDS();
	
	die "wrong number of keyparts for table $table (needs: @keynames)"
		unless (@keyparts == @keynames);
	
	my $stmt = "SELECT * FROM $table WHERE";
	while (@keyparts) {
		$stmt .= " " . shift @keynames . "=" . shift @keyparts;
		$stmt .= " AND" if @keyparts;
	}
	
	$self->{driver}->connect("ro");
	my @record = $self->{driver}->handle()->selectrow_array($stmt);
	$self->{driver}->disconnect();
	
	unless (defined @record) {
		die "failed to SELECT: $DB::errstr";
	}
	
	my $Record = $self->{record}->new();
	my @fieldnames = $self->{record}->FIELDS();
	foreach (@fieldnames) {
		$Record->$_(shift @record);
	}
	
	return $Record;
}

sub put($$) {
	my ($self, $Record) = @_;
	
	my $table = $self->{table};
	my @fieldnames = $self->{record}->FIELDS();
	my $fieldnames = join(", ", @fieldnames);
	my @fieldvalues = map { $Record->$_() } @fieldnames;
	my $marks = join(", ", map { "?" } @fieldnames);
	my $stmt = "UPDATE $table SET";
	while (@fieldnames) {
		$stmt .= " " . shift @fieldnames . "=?";
		$stmt .= "," if @fieldnames;
	}
	
	$self->{driver}->connect("rw");
	my $sth = $self->{driver}->handle()->prepare($stmt);
	my $result = $sth->execute(@fieldvalues);
	$self->{driver}->disconnect();
	
	unless (defined $result) {
		my @keynames = $self->{record}->KEYFIELDS();
		my @keyvalues = map $Record->$_() } @keynames;
		die "(@keyvalues): failed to UPDATE: $DB::errstr";
	}
	
	return 1;
}

sub delete($$) {
	my ($self, @keyparts) = @_;
	
	my $table = $self->{table};
	my @keynames = $self->{record}->KEYFIELDS();
	
	die "wrong number of keyparts for table $table (needs: @keynames)"
		unless (@keyparts == @keynames);
	
	my $stmt = "DELETE FROM $table WHERE";
	while (@keyparts) {
		$stmt .= " " . shift @keynames . "=" . shift @keyparts;
		$stmt .= " AND" if @keyparts;
	}
	
	$self->{driver}->connect("ro");
	my $num = $self->{driver}->handle()->do($stmt);
	$self->{driver}->disconnect();
	
	unless (defined $num) {
		die "failed to SELECT: $DB::errstr";
	}
	
	unless ($num > 1) {
		warn "danger! deleted more than one record!";
	}
	
	return $num;
}

1;
