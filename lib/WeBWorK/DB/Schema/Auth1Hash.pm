################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Schema::Auth1Hash;

=head1 NAME

WeBWorK::DB::Schema::Auth1Hash - support access to the password, permission,
and key tables with a WWDBv1 hash-style backend.

=cut

use strict;
use warnings;

use constant TABLES => qw(password permission key);
use constant STYLE  => "hash";

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

sub new($$$$) {
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
#  Auth1Hash provides access to three tables, so it checks the $self->{table}
#  field to know what data its dealing with.
################################################################################

sub list($@) {
	my ($self, @keyparts) = @_;
	my ($matchUserID) = @keyparts;
	$self->{driver}->connect("ro");
	my @keys = keys %{ $self->{driver}->hash() };
	$self->{driver}->disconnect();
	if (defined $matchUserID) {
		@keys = grep { $_ eq $matchUserID } @keys;
	}
	return map { [$_] } @keys;
}

sub exists($$) {
	my ($self, $userID) = @_;
	$self->{driver}->connect("ro");
	my $exists = exists $self->{driver}->hash()->{$userID};
	$self->{driver}->disconnect();
	return $exists;
}

sub add($$) {
	my ($self, $Record) = @_;
	my $valueName = $self->{table};
	$self->{driver}->connect("rw");
	my $hash = $self->{driver}->hash();
	die $Record->user_id, ": $valueName exists"
		if exists $hash->{$Record->user_id};
	if ($self->{table} eq "key") {
		# key's value contains two fields
		$hash->{$Record->user_id} = $Record->key() . " " . $Record->timestamp();
	} else {
		$hash->{$Record->user_id} = $Record->$valueName();
	}
	$self->{driver}->disconnect();
}

sub get($$) {
	my ($self, $userID) = @_;
	$self->{driver}->connect("ro");
	my $value = $self->{driver}->hash()->{$userID};
	$self->{driver}->disconnect();
	return undef unless defined $value;
	if ($self->{table} eq "key") {
		# key's value contains two fields
		my ($key, $timestamp) = $value =~ m/^(\S+)\s+(.*)$/;
		return $self->{record}->new(
			user_id => $userID,
			key => $key,
			timestamp => $timestamp,
		);
	} else {
		return $self->{record}->new(
			user_id => $userID,
			$self->{table} => $value,
		);
	}
}

sub put($$) {
	my ($self, $Record) = @_;
	my $valueName = $self->{table};
	$self->{driver}->connect("rw");
	my $hash = $self->{driver}->hash();
	die $Record->user_id, ": $valueName not found"
		unless exists $hash->{$Record->user_id};
	if ($self->{table} eq "key") {
		# key's value contains two fields
		$hash->{$Record->user_id} = $Record->key() . " " . $Record->timestamp();
	} else {
		$hash->{$Record->user_id} = $Record->$valueName();
	}
	$self->{driver}->disconnect();
}

sub delete($$) {
	my ($self, $userID) = @_;
	my $valueName = $self->{table};
	$self->{driver}->connect("rw");
	my $hash = $self->{driver}->hash();
	return unless exists $hash->{$userID};
	delete $hash->{$userID};
	$self->{driver}->disconnect();
}

1;
