################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Schema::Classlist1Hash;

=head1 NAME

WeBWorK::DB::Schema::Classlist1Hash - support access to the user table with a
WWDBv1 hash-style backend.

=cut

use strict;
use warnings;
use WeBWorK::DB::Utils qw(record2hash hash2record hash2string string2hash);

use constant TABLES => qw(user);
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
	my ($matchUserID) = @keyparts;
	$self->{driver}->connect("ro");
	my @keys = grep { not m/^>>/ } keys %{ $self->{driver}->hash() };
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
	my ($self, $User) = @_;
	$self->{driver}->connect("rw");
	my $hash = $self->{driver}->hash();
	die $User->id, ": user exists" if exists $hash->{$User->id};
	$hash->{$User->id} = hash2string(record2hash($User));
	$self->{driver}->disconnect();
}

sub get($$) {
	my ($self, $userID) = @_;
	$self->{driver}->connect("ro");
	my $string = $self->{driver}->hash()->{$userID};
	$self->{driver}->disconnect();
	return undef unless defined $string;
	my $record = hash2record($self->{record}, string2hash($string));
	$record->id($userID);
	return $record;
}

sub put($$) {
	my ($self, $User) = @_;
	$self->{driver}->connect("rw");
	my $hash = $self->{driver}->hash();
	die $User->id, ": user not found" unless exists $hash->{$User->id};
	$hash->{$User->id} = hash2string(record2hash($User));
	$self->{driver}->disconnect();
}

sub delete($$) {
	my ($self, $userID) = @_;
	$self->{driver}->connect("rw");
	my $hash = $self->{driver}->hash();
	die "$userID: user not found" unless exists $hash->{$userID};
	delete $hash->{$userID};
	$self->{driver}->disconnect();
}

1;
