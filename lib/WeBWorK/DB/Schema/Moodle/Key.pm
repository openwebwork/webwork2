################################################################################
# WeBWorK Online Homework Delivery System - Moodle Integration
# Copyright (c) 2005 Peter Snoblin <pas@truman.edu>
# $Id$
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

package WeBWorK::DB::Schema::Moodle::Key;
use base qw(WeBWorK::DB::Schema);

=head1 NAME

WeBWorK::DB::Schema::Moodle::Key - support access to Moodle's session store.

=cut

use strict;
use warnings;
use Carp qw(croak);
use PHP::Serialization qw(serialize unserialize);

use constant TABLES => qw(moodlekey);
use constant STYLE  => "dbi";

=head1 SUPPORTED PARAMS

This schema pays attention to the following items in the C<params> entry.

=over

=item tablePrefix

The prefix on all moodle tables.

=back

=cut

################################################################################
# constructor for Moodle::Key-specific behavior
################################################################################

sub new {
	my ($proto, $db, $driver, $table, $record, $params) = @_;
	my $self = $proto->SUPER::new($db, $driver, $table, $record, $params);
	return $self;
}

################################################################################
# table access functions
################################################################################

sub get($$) {
	# get the username, expiration time from the db.
	my ($self, $key) = @_;
	return undef, undef
		unless $key;
	
	my $table = $self->prefixTable("sessions");
	
	my $qry = "SELECT expiry, data FROM `$table` WHERE sesskey=?";
	my @qryArgs = ($key);
	$self->debug("SQL-get: $qry\n");
	
	$self->{driver}->connect("ro");
	my $sth = $self->{driver}->dbi()->prepare($qry);
	$sth->execute(@qryArgs);
	my $result = $sth->fetchrow_arrayref;
	$self->{driver}->disconnect();
	if( not defined $result ) {
		return undef, undef;
	}
	my @record = @$result;
	my $expires = shift @record;
	my $sessionData = shift @record;
	my $data = $self->unserializeSession($sessionData);
	my $username = ( exists $data->{"USER"} and exists $data->{"USER"}{"username"} ) ? $data->{"USER"}{"username"} : undef;
	return $username, $expires;
}

sub extend($$) {
	# extends the expiration time of the session
	my ($self, $key) = @_;
	return 0 unless $key;
	
	my $table = $self->prefixTable("sessions");
	
	my $expires = time + $self->sessionTimeout();
	
	my $qry = "UPDATE `$table` SET expiry=$expires WHERE sesskey=?";
	my @qryArgs = ($key);
	$self->debug("SQL-extend: $qry\n");
	
	$self->{driver}->connect("rw");
	my $sth = $self->{driver}->dbi()->prepare($qry);
	my $result = $sth->execute(@qryArgs);
	$self->{driver}->disconnect();
	
	unless( defined $result ) {
		return 0;
	}
	return 1;
}

################################################################################
# utility functions
################################################################################

sub debug($@) {
	my ($self, @string) = @_;
	
	if ($self->{params}->{debug}) {
		warn @string;
	}
}

sub prefixTable($$) {
	my ($self, $table) = @_;
	my $prefix = $self->{params}->{tablePrefix};
	return $prefix.$table;
}

sub unserializeSession($$) {
	my ($self, $serialData) = @_;
	# first, url decode:
	$serialData =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
	# then, split it up by |, it's some ADODB sillyness
	my @serialArray = split(/(\w+)\|/, $serialData);
	my %variables;
	# finally, actually deserialize it:
	for( my $i = 1; $i < $#serialArray; $i += 2 ) {
		$variables{$serialArray[$i]} = unserialize($serialArray[$i+1]);
	}
	return \%variables;
}

sub sessionTimeout($) {
	# gets the session timeout length for moodle cookies:
	my ($self) = @_;
	
	my $table = $self->prefixTable("config");
	
	my $qry = "SELECT value FROM `$table` WHERE name='sessiontimeout'";
	$self->debug("SQL-sessionTimeout: $qry\n");
	
	$self->{driver}->connect("ro");
	
	my $sth = $self->{driver}->dbi()->prepare($qry);
	$sth->execute();
	my $result = $sth->fetchrow_arrayref;
	$self->{driver}->disconnect();
	if( not defined $result ) {
		return 7200;
	}
	my @record = @$result;
	return shift @record;
}

1;
