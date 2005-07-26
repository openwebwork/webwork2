################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB.pm,v 1.64 2005/07/14 13:15:24 glarose Exp $
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

package WeBWorK::DB::SQL;

=head1 NAME

WeBWorK::DB::SQL - SQL-specific implementation of the WeBWorK::DB API.

=cut

use strict;
use warnings;
use Carp;
use DBI;
use WeBWorK::Utils qw(runtime_use);

use constant ALLOWED_SCHEMA => "WeBWorK::DB::Schema::SQL";
use constant ALLOWED_DRIVER => "WeBWorK::DB::Driver::SQL";

################################################################################
# constructor
################################################################################

sub new($$) {
	my ($invocant, $dbLayout) = @_;
	my $class = ref($invocant) || $invocant;
	
	# data that is not table-specific
	my $global_source;
	my $global_usernameRO;
	my $global_passwordRO;
	my $global_usernameRW;
	my $global_passwordRW;
	my $global_debug;
	
	# data that is table-specific
	my %table_data;
	
	# load the modules required to handle each table, and create driver
	my %dbLayout = %$dbLayout;
	foreach my $table (keys %dbLayout) {
		my $layout = $dbLayout{$table};
		my $record = $layout->{record};
		my $schema = $layout->{schema};
		my $driver = $layout->{driver};
		my $source = $layout->{source};
		my $params = $layout->{params};
		
		my $usernameRO = $params->{usernameRO};
		my $passwordRO = $params->{passwordRO};
		my $usernameRW = $params->{usernameRW};
		my $passwordRW = $params->{passwordRW};
		my $debug = $params->{debug};
		
		# make sure the schema is the one we can deal with
		croak "Table '$table' wants schema module '$schema', but ".__PACKAGE__." will only work if the requested schema module is '".ALLOWED_SCHEMA."'. Can't continue."
			unless $schema eq ALLOWED_SCHEMA;
		
		# make sure the driver is the one we can deal with
		croak "Table '$table' wants driver module '$driver', but ".__PACKAGE__." will only work if the requested driver module is '".ALLOWED_DRIVER."'. Can't continue."
			unless $driver eq ALLOWED_DRIVER;
		
		# get DBI data source
		layout_error($table, "source", $global_source, $source)
			if defined $global_source and $global_source ne $source;
		$global_source = $source;
		
		# get usernames and passwords
		layout_error($table, "usernameRO", $global_usernameRO, $usernameRO)
			if defined $global_usernameRO and $global_usernameRO ne $usernameRO;
		layout_error($table, "passwordRO", $global_passwordRO, $passwordRO)
			if defined $global_passwordRO and $global_passwordRO ne $passwordRO;
		layout_error($table, "usernameRW", $global_usernameRW, $usernameRW)
			if defined $global_usernameRW and $global_usernameRW ne $usernameRW;
		layout_error($table, "passwordRW", $global_passwordRW, $passwordRW)
			if defined $global_passwordRW and $global_passwordRW ne $passwordRW;
		$global_usernameRO = $usernameRO;
		$global_passwordRO = $passwordRO;
		$global_usernameRW = $usernameRW;
		$global_passwordRW = $passwordRW;
		
		# debug flag
		layout_error($table, "debug", $global_debug, $debug)
			if defined $global_debug and $global_debug ne $debug;
		$global_debug = $debug;
		
		# we still want to allow a choice of record classes, since it doesn't cost us anything.
		runtime_use($record);
		
		# this is a temporary data structure that describes how the user described the tables
		# in the database layout, with some munging
		$table_data{$table} = {
			record => $record,
			tableOverride => $params->{tableOverride},
			fieldOverride => $params->{fieldOverride},
		};
	}
	
	my $dbhRO = DBI->connect_cached(
		$global_source,
		$global_usernameRO,
		$global_passwordRO,
		{ RaiseError => 1 },
	) or die $DBI::errstr;
	
	my $dbhRW = DBI->connect_cached(
		$global_source,
		$global_usernameRW,
		$global_passwordRW,
		{ RaiseError => 1 },
	) or die $DBI::errstr;
	
	my $self = {
		#source => $global_source,
		#usernameRO => $global_usernameRO,
		#passwordRO => $global_passwordRO,
		#usernameRW => $global_usernameRW,
		#passwordRW => $global_passwordRW,
		dbhRO => $dbhRO,
		dbhRW => $dbhRW,
		debug => $global_debug,
		tables => \%table_data,
	};
	
	bless $self, $class;
	return $self;
}

################################################################################
# general functions
################################################################################

sub hashDatabaseOK {
	return 1;
}

################################################################################
# password functions
################################################################################

sub newPassword {
	my ($self, @prototype) = @_;
	
	return $self->record("password")->new(@prototype);
}

sub listPasswords {
	my ($self) = @_;
	
	croak "listPasswords: requires 0 arguments"
		unless @_ == 1;
	
	my $table = $self->sql_table("password");
	my $field = $self->sql_field("user_id");
	my $stmt = "SELECT `$field` from `$table`";
	
	my $dbh = $self->{dbhRO};
	my $sth = $dbh->preprare_cached($stmt);
	$sth->execute;
	return map { $_->[0] } $sth->fetchall_arrayref;
}

sub addPassword {
	my ($self, $Password) = @_;
	
	croak "addPassword: requires 1 argument"
		unless @_ == 2;
	croak "addPassword: argument 1 must be of type ", $self->record("password")
		unless ref $Password eq $self->{password}->{record};
	
	checkKeyfields($Password);
	
	my $table = $self->sql_table("password");
	my @key_fields = $self->sql_fields("password", $self->record("password")->KEYFIELDS);
	my @fields = $self->sql_fields("password", $self->record("password")->FIELDS);
	
	
	
	croak "addPassword: password exists (perhaps you meant to use putPassword?)"
		if $self->{password}->exists($Password->user_id);
	croak "addPassword: user ", $Password->user_id, " not found"
		unless $self->{user}->exists($Password->user_id);
	
	return $self->{password}->add($Password);
}

################################################################################
# utilities
################################################################################

sub layout_error {
	my ($table, $param, $oldval, $newval) = @_;
	
	croak "Table '$table' sets $param to '$newval', but some other table already set it to '$oldval'. ",
		__PACKAGE__, " can only be used if all tables set $param to the same value.";
}

sub record {
	my ($self, $table) = @_;
	
	return $self->{tables}{$table}{record};
}

sub sql_table {
	my ($self, $table) = @_;
	
	return $self->{tables}{$table}{tableOverride} || $table;
}

sub sql_field {
	my ($self, $table, $field) = @_;
	
	return $self->{tables}{$table}{fieldOverride}{$field} || $field;
}

sub sql_fields {
	my ($self, $table, @fields) = @_;
	
	return map { $self->sql_field($table, $_) } @fields;
}

sub box {
	
}

sub unbox {
	
}

1;
