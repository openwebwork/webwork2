################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Schema::Auth1Hash;
use base qw(WeBWorK::DB::Schema);

=head1 NAME

WeBWorK::DB::Schema::Auth1Hash - support access to the password, permission,
and key tables with a WWDBv1 hash-style backend.

=cut

use strict;
use warnings;

use constant TABLES => qw(password permission key);
use constant STYLE  => "hash";

################################################################################
# table access functions
#  Auth1Hash provides access to three tables, so it checks the $self->{table}
#  field to know what data its dealing with.
################################################################################

sub list {
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

sub get {
	my ($self, $userID) = @_;
#	$self->{driver}->connect("ro");
#	my $value = $self->{driver}->hash()->{$userID};
#	$self->{driver}->disconnect();
#	return undef unless defined $value;
#	if ($self->{table} eq "key") {
#		# key's value contains two fields
#		my ($key, $timestamp) = $value =~ m/^(\S+)\s+(.*)$/;
#		return $self->{record}->new(
#			user_id => $userID,
#			key => $key,
#			timestamp => $timestamp,
#		);
#	} else {
#		return $self->{record}->new(
#			user_id => $userID,
#			$self->{table} => $value,
#		);
#	}
	my @results = 
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
			if ($self->{table} eq "key") {
				# key's value contains two fields
				my ($key, $timestamp) = $string =~ m/^(\S+)\s+(.*)$/;
				push @records, $self->{record}->new(
					user_id => $userID,
					key => $key,
					timestamp => $timestamp,
				);
			} else {
				push @records, $self->{record}->new(
					user_id => $userID,
					$self->{table} => $string,
				);
			}
		} else {
			push @records, undef;
		}
	}
	$self->{driver}->disconnect();
	return @records;
}

sub put {
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

sub delete {
	my ($self, $userID) = @_;
	my $valueName = $self->{table};
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
