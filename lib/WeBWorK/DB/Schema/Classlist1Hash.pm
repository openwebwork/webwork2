################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Schema::Classlist1Hash;

=head1 NAME

WeBWorK::DB::Schema::Classlist1Hash - support access to the user table with a
1.x-structured hash-style backend.

=cut

use strict;
use warnings;
use WeBWorK::DB::Record::User;
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
	my ($proto, $driver, $table) = @_;
	my $class = ref($proto) || $proto;
	die "$table: unsupported table"
		unless grep { $_ eq $table } $proto->tables();
	die $driver->style(), ": style mismatch"
		unless $driver->style() eq $proto->style();
	my $self = {
		driver => $driver,
		table  => $table,
	};
	bless $self, $class;
	return $self;
}

################################################################################
# table access functions
################################################################################

sub list($) {
	my ($self) = @_;
	$self->{driver}->connect("ro");
	my @keys = grep !/^>>/, keys %{ $self->{driver}->hash() };
	$self->{driver}->disconnect();
	return @keys;
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
	return undef unless $string;
	my $record = hash2record("WeBWorK::DB::Record::User", string2hash($string));
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
