################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Schema::Classlist1Hash;
use base qw(WeBWorK::DB::Schema);

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
	my $result;
	if (defined $userID) {
		$result = exists $self->{driver}->hash()->{$userID};
	} else {
		$result = keys %{$self->{driver}->hash()} ? 1 : 0;
	}
	$self->{driver}->disconnect();
	return $result;
}

sub add($$) {
	my ($self, $User) = @_;
	$self->{driver}->connect("rw");
	my $hash = $self->{driver}->hash();
	die $User->user_id, ": user exists" if exists $hash->{$User->user_id};
	$hash->{$User->user_id} = hash2string(record2hash($User));
	$self->{driver}->disconnect();
}

sub get($$) {
	my ($self, $userID) = @_;
	$self->{driver}->connect("ro");
	my $string = $self->{driver}->hash()->{$userID};
	$self->{driver}->disconnect();
	return undef unless defined $string;
	my $record = hash2record($self->{record}, string2hash($string));
	$record->user_id($userID);
	return $record;
}

sub put($$) {
	my ($self, $User) = @_;
	$self->{driver}->connect("rw");
	my $hash = $self->{driver}->hash();
	die $User->user_id, ": user not found" unless exists $hash->{$User->user_id};
	$hash->{$User->user_id} = hash2string(record2hash($User));
	$self->{driver}->disconnect();
}

sub delete($$) {
	my ($self, $userID) = @_;
	return 0 unless $self->{driver}->connect("rw");
	my $hash = $self->{driver}->hash();
	if (defined $userID) {
		delete $hash->{$userID};
	} else {
		# delete all elements
		delete @$hash{keys %$hash};
	}
	$self->{driver}->disconnect();
	return 1;
}

1;
