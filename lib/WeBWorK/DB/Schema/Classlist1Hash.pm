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

sub list {
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

sub exists {
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

sub add {
	my ($self, $User) = @_;
	$self->{driver}->connect("rw");
	my $hash = $self->{driver}->hash();
	die $User->user_id, ": user exists" if exists $hash->{$User->user_id};
	$hash->{$User->user_id} = hash2string(record2hash($User));
	$self->{driver}->disconnect();
}

sub get {
	my ($self, $userID) = @_;
#	$self->{driver}->connect("ro");
#	my $string = $self->{driver}->hash()->{$userID};
#	$self->{driver}->disconnect();
#	return undef unless defined $string;
#	my $record = hash2record($self->{record}, string2hash($string));
#	$record->user_id($userID);
#	return $record;
	return ($self->gets([$userID]))[0];
}

sub gets {
	my ($self, @keypartsRefList) = @_;
	$self->{driver}->connect("ro");
	my @records;
	foreach my $keypartsRef (@keypartsRefList) {
		my $userID = $keypartsRef->[0];
		my $string = $self->{driver}->hash()->{$userID};
		if (defined $string) {
			my $record = hash2record($self->{record}, string2hash($string));
			$record->user_id($userID);
			push @records, $record;
		} else {
			push @records, undef;
		}
	}
	$self->{driver}->disconnect();
	return @records;
}

sub put {
	my ($self, $User) = @_;
	$self->{driver}->connect("rw");
	my $hash = $self->{driver}->hash();
	die $User->user_id, ": user not found" unless exists $hash->{$User->user_id};
	$hash->{$User->user_id} = hash2string(record2hash($User));
	$self->{driver}->disconnect();
}

sub delete {
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
