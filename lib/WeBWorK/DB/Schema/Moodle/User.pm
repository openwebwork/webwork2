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

### TODO: Ensure usernames are properly escaped.

package WeBWorK::DB::Schema::Moodle::User;
use base qw(WeBWorK::DB::Schema);

=head1 NAME

WeBWorK::DB::Schema::Moodle::User - Enumerates users from Moodle.

=cut

use strict;
use warnings;
use Carp qw(croak);

use constant TABLES => qw(user);
use constant STYLE  => "dbi";

=head1 SUPPORTED PARAMS

This schema pays attention to the following items in the C<params> entry.

=over

=item tablePrefix

The prefix on all moodle tables.

=back

=cut

################################################################################
# constructor for Moodle::User-specific behavior
################################################################################

sub new {
	my ($proto, $db, $driver, $table, $record, $params) = @_;
	my $self = $proto->SUPER::new($db, $driver, $table, $record, $params);
	return $self;
}

################################################################################
# table access functions
################################################################################

sub count {
	my ($self, @keyparts) = @_;
	my @keynames = $self->{record}->KEYFIELDS();
	
	croak "Too many keyparts for table user. Need at most @keynames"
		if @keyparts > @keynames;
	
	my $table = $self->prefixTable("user");
	# we want to know for a specific user_id
	my $qry = "SELECT COUNT(*) FROM `$table`";
	my @qryArgs = ();
	if( defined $keyparts[0] ) {
		$qry = $qry . " WHERE username=?";
		$qryArgs[0] = $keyparts[0];
	}
	$self->debug("SQL-count: $qry\n");
	
	$self->{driver}->connect("ro");
	my $sth = $self->{driver}->dbi()->prepare($qry);
	$sth->execute(@qryArgs);
	my ($result) = $sth->fetchrow_array;
	
	$self->{driver}->disconnect();
	
	return $result;
}

sub list($@) {
	my ($self, @keyparts) = @_;
	my @keynames = $self->{record}->KEYFIELDS();
	
	croak "Too many keyparts for table user. Need at most @keynames"
		if @keyparts > @keynames;
	
	my $table = $self->prefixTable("user");
	my $qry = "SELECT username FROM `$table`";
	my @qryArgs = ();
	if( defined $keyparts[0] ) {
		$qry = $qry . " WHERE username=?";
		$qryArgs[0] = $keyparts[0];
	}
	$self->debug("SQL-list: $qry\n");
	
	$self->{driver}->connect("ro");
	my $sth = $self->{driver}->dbi()->prepare($qry);
	$sth->execute(@qryArgs);
	my $result = $sth->fetchall_arrayref;
	
	$self->{driver}->disconnect();
	
	croak "failed to SELECT: $DBI::errstr" unless defined $result;
	return @$result;
}

sub exists($@) {
	my ($self, @keyparts) = @_;
	my @keynames = $self->{record}->KEYFIELDS();
	
	croak "Too many keyparts for table user. Need at most @keynames"
		if @keyparts > @keynames;
	
	my $table = $self->prefixTable("user");
	my $qry = "SELECT COUNT(*) FROM `$table`";
	my @qryArgs = ();
	if( defined $keyparts[0] ) {
		$qry = $qry . " WHERE username=?";
		$qryArgs[0] = $keyparts[0];
	}
	$self->debug("SQL-exists: $qry\n");
	
	$self->{driver}->connect("ro");
	my $sth = $self->{driver}->dbi()->prepare($qry);
	$sth->execute(@qryArgs);
	my ($result) = $sth->fetchrow_array;
	$self->{driver}->disconnect();
	
	croak "failed to SELECT : $DBI::errstr" unless defined $result;
	return $result > 0;
}

sub add($$) {
	# password modification is not supported for webwork. Use Moodle.
	croak "Modifications to user information is not supported from WeBWorK. Please use Moodle to make any changes.";
}

sub get($@) {
	my ($self, @keyparts) = @_;
	
	return ($self->gets(\@keyparts))[0];
}

sub gets($@) {
	my ($self, @keypartsRefList) = @_;
	my @keynames = $self->{record}->KEYFIELDS();
	
	my @records;
	$self->{driver}->connect("ro");
	foreach my $keypartsRef(@keypartsRefList) {
		my @keyparts = @$keypartsRef;
	
		if( not defined $keyparts[0] ) {
			croak "wrong number of keyparts for table user";
		}
		
		my $table = $self->prefixTable("user");
		my $qry = "SELECT username, firstname, lastname, email, idnumber, deleted FROM `$table`";
		my @qryArgs = ();
		if( defined $keyparts[0] ) {
			$qry = $qry . " WHERE username=?";
			$qryArgs[0] = $keyparts[0];
		}
		
		my $sth = $self->{driver}->dbi()->prepare($qry);
		$sth->execute(@qryArgs);
		my $result = $sth->fetchrow_arrayref;

		if( defined $result ) {
			my @record = @$result;
			my $Record = $self->{record}->new();
			my @realFieldNames = $self->{record}->FIELDS();
			foreach (@realFieldNames) {
				my $value = shift @record;
				if( "status" eq $_ ) {
					if( $value > 0 ) {
						$value = 'D';
					}
					else {
						$value = 'C';
					}
				}
				$value = "" unless defined $value;
				$Record->$_($value);
			}
			push @records, $Record;
		}
		else {
			push @records, undef;
		}
	}
	$self->{driver}->disconnect();
	return @records;
}

sub put($$) {
	croak "Modifications to user information is not supported from WeBWorK. Please use Moodle to make any changes.";
}

sub delete($@) {
	croak "Modifications to user information is not supported from WeBWorK. Please use Moodle to make any changes.";
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

1;
