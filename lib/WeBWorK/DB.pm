################################################################################
# WeBWorK Online Homework Delivery System>
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB.pm,v 1.112 2012/06/08 22:40:00 wheeler Exp $
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

package WeBWorK::DB;

=head1 NAME

WeBWorK::DB - interface with the WeBWorK databases.

=head1 SYNOPSIS

 my $db = WeBWorK::DB->new($dbLayout);
 
 my @userIDs = $db->listUsers();
 my $Sam = $db->{user}->{record}->new();
 
 $Sam->user_id("sammy");
 $Sam->first_name("Sam");
 $Sam->last_name("Hathaway");
 # etc.
 
 $db->addUser($User);
 my $Dennis = $db->getUser("dennis");
 $Dennis->status("C");
 $db->putUser->($Dennis);
 
 $db->deleteUser("sammy");

=head1 DESCRIPTION

WeBWorK::DB provides a consistent interface to a number of database backends.
Access and modification functions are provided for each logical table used by
the webwork system. The particular backend ("schema" and "driver"), record
class, data source, and additional parameters are specified by the hash
referenced by C<$dbLayout>, usually taken from the course environment.

=head1 ARCHITECTURE

The new database system uses a three-tier architecture to insulate each layer
from the adjacent layers.

=head2 Top Layer: DB

The top layer of the architecture is the DB module. It provides the methods
listed below, and uses schema modules (via tables) to implement those methods.

         / new* list* exists* add* get* get*s put* delete* \          <- api
 +------------------------------------------------------------------+
 |                                DB                                |
 +------------------------------------------------------------------+
  \ password permission key user set set_user problem problem_user /  <- tables

=head2 Middle Layer: Schemas

The middle layer of the architecture is provided by one or more schema modules.
They are called "schema" modules because they control the structure of the data
for a table.

The schema modules provide an API that matches the requirements of the DB
layer, on a per-table basis. Each schema module has a style that determines
which drivers it can interface with. For example, SQL is an "dbi" style
schema.

=head2 Bottom Layer: Drivers

Driver modules implement a style for a schema. They provide physical access to
a data source containing the data for a table. The style of a driver determines
what methods it provides. All drivers provide C<connect(MODE)> and
C<disconnect()> methods. A dbi style driver provides a C<handle()> method which
returns the DBI handle.

=head2 Record Types

In C<%dblayout>, each table is assigned a record class, used for passing
complete records to and from the database. The default record classes are
subclasses of the WeBWorK::DB::Record class, and are named as follows: User,
Password, PermissionLevel, Key, Set, UserSet, Problem, UserProblem. In the
following documentation, a reference the the record class for a table means the
record class currently defined for that table in C<%dbLayout>.

=cut

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Scalar::Util qw/blessed/;
use WeBWorK::DB::Schema;
use WeBWorK::DB::Utils qw/make_vsetID grok_vsetID grok_setID_from_vsetID_sql
	grok_versionID_from_vsetID_sql/;
use WeBWorK::Debug;
use WeBWorK::Utils qw(runtime_use);

=for comment

These exceptions will replace the ones in WeBWorK::DB::Schema and will be
allowed to propagate out to calling code. The following callers will have to be
changed to catch these exceptions instead of doing string matching:

lib/WebworkSOAP.pm:     if ($@ =~ m/user set exists/) {
lib/WeBWorK/ContentGenerator/Instructor.pm:             if ($@ =~ m/user set exists/) {
lib/WeBWorK/ContentGenerator/Instructor.pm:     if ( $@ =~ m/user set exists/ ) {
lib/WeBWorK/ContentGenerator/Instructor.pm:             if ($@ =~ m/user problem exists/) {
lib/WeBWorK/ContentGenerator/Instructor.pm:             if ($@ =~ m/user problem exists/) {
lib/WeBWorK/ContentGenerator/Instructor.pm:                     next if $@ =~ m/user set exists/;
lib/WeBWorK/Utils/DBImportExport.pm:                            if ($@ =~ m/exists/) {
lib/WeBWorK/DB.pm:                              if ($@ and $@ !~ m/password exists/) {
lib/WeBWorK/DB.pm:                              if ($@ and $@ !~ m/permission level exists/) {

How these exceptions should be used:

* RecordExists is thrown by the DBI error handler (handle_error in
Schema::NewSQL::Std) when in INSERT fails because a record exists. Thus it can
be thrown via addUser, addPassword, etc.

* RecordNotFound should be thrown when we try to UPDATE and zero rows were
affected. Problem: Frank Wolfs (UofR PAS) may have a MySQL server that returns 0
when updating even when a record was modified. What's up with that? There's some
question as to where we should throw this: in this file's put* methods? In
Std.pm's put method? Or in update_fields and update_fields_i?

* DependencyNotFound should be throws when we check for a record that is needed
to insert another record (e.g. password depends on user). These checks are done
in this file, so we'll throw this exception from there.

=cut

use Exception::Class (
	'WeBWorK::DB::Ex' => {
		description => 'unknown database error',
	},
	'WeBWorK::DB::Ex::RecordExists' => {
		isa => 'WeBWorK::DB::Ex',
		fields => ['type', 'key'],
		description =>"record exists"
	},
	'WeBWorK::DB::Ex::RecordNotFound' => {
		isa => 'WeBWorK::DB::Ex',
		fields => ['type', 'key'],
		description =>"record not found"
	},
	'WeBWorK::DB::Ex::DependencyNotFound' => {
		isa => 'WeBWorK::DB::Ex::RecordNotFound',
	},
	'WeBWorK::DB::Ex::TableMissing' => {
    	isa => 'WeBWorK::DB::Ex',
    	description =>"missing table",
	},
);

################################################################################
# constructor
################################################################################

=head1 CONSTRUCTOR

=over

=item new($dbLayout)

The C<new> method creates a DB object and brings up the underlying schema/driver
structure according to the hash referenced by C<$dbLayout>.

=back

=head2 C<$dbLayout> Format

C<$dbLayout> is a hash reference consisting of items keyed by table names. The
value of each item is a reference to a hash containing the following items:

=over

=item record

The name of a perl module to use for representing the data in a record.

=item schema

The name of a perl module to use for access to the table.

=item driver

The name of a perl module to use for access to the data source.

=item source

The location of the data source that should be used by the driver module.
Depending on the driver, this may be a path, a url, or a DBI spec.

=item params

A reference to a hash containing extra information needed by the schema. Some
schemas require parameters, some do not. Consult the documentation for the
schema in question.

=back

For each table defined in C<$dbLayout>, C<new> loads the record, schema, and
driver modules. It the schema module's C<tables> method lists the current table
(or contains the string "*") and the output of the schema and driver modules'
C<style> methods match, the table is installed. Otherwise, an exception is
thrown.

=cut

sub new {
	my ($invocant, $dbLayout) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {};
	bless $self, $class; # bless this here so we can pass it to the schema
	
	# load the modules required to handle each table, and create driver
	foreach my $table (keys %$dbLayout) {
		$self->init_table($dbLayout, $table);
	}
	
	return $self;
}

sub init_table {
	my ($self, $dbLayout, $table) = @_;
	
	if (exists $self->{$table}) {
		if (defined $self->{$table}) {
			return;
		} else {
			die "loop in dbLayout table dependencies involving table '$table'\n";
		}
	}
	
	my $layout = $dbLayout->{$table};
	my $record = $layout->{record};
	my $schema = $layout->{schema};
	my $driver = $layout->{driver};
	my $source = $layout->{source};
	my $depend = $layout->{depend};
	my $params = $layout->{params};
	
	# add a key for this table to the self hash, but don't define it yet
	# this for loop detection
	$self->{$table} = undef;
	
	if ($depend) {
		foreach my $dep (@$depend) {
			$self->init_table($dbLayout, $dep);
		}
	}
	
	runtime_use($record);
	
	runtime_use($driver);
	my $driverObject = eval { $driver->new($source, $params) };
	croak "error instantiating DB driver $driver for table $table: $@"
		if $@;
	
	runtime_use($schema);
	my $schemaObject = eval { $schema->new(
		$self, $driverObject, $table, $record, $params) };
	croak "error instantiating DB schema $schema for table $table: $@"
		if $@;
	
	$self->{$table} = $schemaObject;
}

################################################################################
# methods that can be autogenerated
################################################################################

sub gen_schema_accessor {
	my $schema = shift;
	return sub { shift->{$schema} };
}

sub gen_new {
	my $table = shift;
	return sub { shift->{$table}{record}->new(@_) };
}

sub gen_count_where {
	my $table = shift;
	return sub {
		my ($self, $where) = @_;
		return $self->{$table}->count_where($where);
	};
}

sub gen_exists_where {
	my $table = shift;
	return sub {
		my ($self, $where) = @_;
		return $self->{$table}->exists_where($where);
	};
}

sub gen_list_where {
	my $table = shift;
	return sub {
		my ($self, $where, $order) = @_;
		if (wantarray) {
			return $self->{$table}->list_where($where, $order);
		} else {
			return $self->{$table}->list_where_i($where, $order);
		}
	};
}

sub gen_get_records_where {
	my $table = shift;
	return sub {
		my ($self, $where, $order) = @_;
		if (wantarray) {
			return $self->{$table}->get_records_where($where, $order);
		} else {
			return $self->{$table}->get_records_where_i($where, $order);
		}
	};
}

sub gen_insert_records {
	my $table = shift;
	return sub {
		my ($self, @records) = @_;
		if (@records == 1 and blessed $records[0] and $records[0]->isa("Iterator")) {
			return $self->{$table}->insert_records_i($records[0]);
		} else {
			return $self->{$table}->insert_records(@records);
		}
	};
}

sub gen_update_records {
	my $table = shift;
	return sub {
		my ($self, @records) = @_;
		if (@records == 1 and blessed $records[0] and $records[0]->isa("Iterator")) {
			return $self->{$table}->update_records_i($records[0]);
		} else {
			return $self->{$table}->update_records(@records);
		}
	};
}

sub gen_delete_where {
	my $table = shift;
	return sub {
		my ($self, $where) = @_;
		return $self->{$table}->delete_where($where);
	};
}

################################################################################
# create/rename/delete/dump/restore tables
################################################################################

sub create_tables {
	my ($self) = @_;
	
	foreach my $table (keys %$self) {
		next if $table =~ /^_/; # skip non-table self fields (none yet)
		next if $self->{$table}{params}{non_native}; # skip non-native tables
		my $schema_obj = $self->{$table};
		if ($schema_obj->can("create_table")) {
			$schema_obj->create_table;
		} else {
			warn "skipping creation of '$table' table: no create_table method\n";
		}
	}
	
	return 1;
}

sub rename_tables {
	my ($self, $new_dblayout) = @_;
	
	foreach my $table (keys %$self) {
		next if $table =~ /^_/; # skip non-table self fields (none yet)
		next if $self->{$table}{params}{non_native}; # skip non-native tables
		my $schema_obj = $self->{$table};
		if (exists $new_dblayout->{$table}) {
			if ($schema_obj->can("rename_table")) {
				# we look into the new dblayout to determine the new table names
				my $new_sql_table_name = defined $new_dblayout->{$table}{params}{tableOverride}
					? $new_dblayout->{$table}{params}{tableOverride}
					: $table;
				$schema_obj->rename_table($new_sql_table_name);
			} else {
				warn "skipping renaming of '$table' table: no rename_table method\n";
			}
		} else {
			warn "skipping renaming of '$table' table: table doesn't exist in new dbLayout\n";
		}
	}
	
	return 1;
}

sub delete_tables {
	my ($self) = @_;
	
	foreach my $table (keys %$self) {
		next if $table =~ /^_/; # skip non-table self fields (none yet)
		next if $self->{$table}{params}{non_native}; # skip non-native tables
		my $schema_obj = $self->{$table};
		if ($schema_obj->can("delete_table")) {
			$schema_obj->delete_table;
		} else {
			warn "skipping deletion of '$table' table: no delete_table method\n";
		}
	}
	
	return 1;
}

sub dump_tables {
	my ($self, $dump_dir) = @_;
	
	foreach my $table (keys %$self) {
		next if $table =~ /^_/; # skip non-table self fields (none yet)
		next if $self->{$table}{params}{non_native}; # skip non-native tables
		my $schema_obj = $self->{$table};
		if ($schema_obj->can("dump_table")) {
			my $dump_file = "$dump_dir/$table.sql";
			$schema_obj->dump_table($dump_file);
		} else {
			warn "skipping dump of '$table' table: no dump_table method\n";
		}
	}
	
	return 1;
}

sub restore_tables {
	my ($self, $dump_dir) = @_;
	
	foreach my $table (keys %$self) {
		next if $table =~ /^_/; # skip non-table self fields (none yet)
		next if $self->{$table}{params}{non_native}; # skip non-native tables
		my $schema_obj = $self->{$table};
		if ($schema_obj->can("restore_table")) {
			my $dump_file = "$dump_dir/$table.sql";
			$schema_obj->restore_table($dump_file);
		} else {
			warn "skipping restore of '$table' table: no restore_table method\n";
		}
	}
	
	return 1;
}

################################################################################
# user functions
################################################################################

BEGIN {
	*User = gen_schema_accessor("user");
	*newUser = gen_new("user");
	*countUsersWhere = gen_count_where("user");
	*existsUserWhere = gen_exists_where("user");
	*listUsersWhere = gen_list_where("user");
	*getUsersWhere = gen_get_records_where("user");
}

sub countUsers { return scalar shift->listUsers(@_) }

sub listUsers {
	my ($self) = shift->checkArgs(\@_);
	if (wantarray) {
		return map { @$_ } $self->{user}->get_fields_where(["user_id"]);
	} else {
		return $self->{user}->count_where;
	}
}

sub existsUser {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	return $self->{user}->exists($userID);
}

sub getUser {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	return ( $self->getUsers($userID) )[0];
}

sub getUsers {
	my ($self, @userIDs) = shift->checkArgs(\@_, qw/user_id*/);
	return $self->{user}->gets(map { [$_] } @userIDs);
}

sub addUser {
	my ($self, $User) = shift->checkArgs(\@_, qw/REC:user/);
	eval {
		return $self->{user}->add($User);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addUser: user exists (perhaps you meant to use putUser?)";
	} elsif ($@) {
		die $@;
	}
	# FIXME about these exceptions: eventually the exceptions should be part of
	# WeBWorK::DB rather than WeBWorK::DB::Schema, and we should just let them
	# through to the calling code. however, right now we have code that checks
	# for the string "... exists" in the error message, so we need to convert
	# here.
	# 
	# WeBWorK::DB::Ex::RecordExists
	# WeBWorK::DB::Ex::DependencyNotFound - i.e. inserting a password for a nonexistent user
	# ?
}

sub putUser {
	my ($self, $User) = shift->checkArgs(\@_, qw/REC:user/);
	my $rows = $self->{user}->put($User); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		croak "putUser: user not found (perhaps you meant to use addUser?)";
	} else {
		return $rows;
	}
}

sub deleteUser {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	$self->deleteUserSet($userID, undef);
	$self->deletePassword($userID);
	$self->deleteGlobalUserAchievement($userID);
	$self->deletePermissionLevel($userID);
	$self->deleteKey($userID);
	return $self->{user}->delete($userID);
}

################################################################################
# password functions
################################################################################

BEGIN {
	*Password = gen_schema_accessor("password");
	*newPassword = gen_new("password");
	*countPasswordsWhere = gen_count_where("password");
	*existsPasswordWhere = gen_exists_where("password");
	*listPasswordsWhere = gen_list_where("password");
	*getPasswordsWhere = gen_get_records_where("password");
}

sub countPasswords { return scalar shift->countPasswords(@_) }

sub listPasswords {
	my ($self) = shift->checkArgs(\@_);
	if (wantarray) {
		return map { @$_ } $self->{password}->get_fields_where(["user_id"]);
	} else {
		return $self->{password}->count_where;
	}
}

sub existsPassword {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	# FIXME should we claim that a password exists if the user exists, since
	# password records are auto-created?
	return $self->{password}->exists($userID);
}

sub getPassword {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	return ( $self->getPasswords($userID) )[0];
}

sub getPasswords {
	my ($self, @userIDs) = shift->checkArgs(\@_, qw/user_id*/);
	
	my @Passwords = $self->{password}->gets(map { [$_] } @userIDs);
	
	# AUTO-CREATE missing password records
	# (this code is duplicated in getPermissionLevels, below)
	for (my $i = 0; $i < @Passwords; $i++) {
		my $Password = $Passwords[$i];
		my $userID = $userIDs[$i];
		if (not defined $Password) {
			if ($self->{user}->exists($userID)) {
				$Password = $self->newPassword(user_id => $userID);
				eval { $self->addPassword($Password) };
				if ($@ and $@ !~ m/password exists/) {
					die "error while auto-creating password record for user $userID: $@";
				}
				$Passwords[$i] = $Password;
			}
		}
	}
	
	return @Passwords;
}

sub addPassword {
	my ($self, $Password) = shift->checkArgs(\@_, qw/REC:password/);
	
	croak "addPassword: user ", $Password->user_id, " not found"
		unless $self->{user}->exists($Password->user_id);
	
	eval {
		return $self->{password}->add($Password);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addPassword: password exists (perhaps you meant to use putPassword?)";
	} elsif ($@) {
		die $@;
	}
}

sub putPassword {
	my ($self, $Password) = shift->checkArgs(\@_, qw/REC:password/);
	my $rows = $self->{password}->put($Password); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		# AUTO-CREATE permission level records
		return $self->addPassword($Password);
	} else {
		return $rows;
	}
}

sub deletePassword {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	return $self->{password}->delete($userID);
}

################################################################################
# permission functions
################################################################################

BEGIN {
	*PermissionLevel = gen_schema_accessor("permission");
	*newPermissionLevel = gen_new("permission");
	*countPermissionLevelsWhere = gen_count_where("permission");
	*existsPermissionLevelWhere = gen_exists_where("permission");
	*listPermissionLevelsWhere = gen_list_where("permission");
	*getPermissionLevelsWhere = gen_get_records_where("permission");
}

sub countPermissionLevels { return scalar shift->listPermissionLevels(@_) }

sub listPermissionLevels {
	my ($self) = shift->checkArgs(\@_);
	if (wantarray) {
		return map { @$_ } $self->{permission}->get_fields_where(["user_id"]);
	} else {
		return $self->{permission}->count_where;
	}
}

sub existsPermissionLevel {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	# FIXME should we claim that a permission level exists if the user exists,
	# since password records are auto-created?
	return $self->{permission}->exists($userID);
}

sub getPermissionLevel {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	return ( $self->getPermissionLevels($userID) )[0];
}

sub getPermissionLevels {
	my ($self, @userIDs) = shift->checkArgs(\@_, qw/user_id*/);
	
	my @PermissionLevels = $self->{permission}->gets(map { [$_] } @userIDs);
	
	# AUTO-CREATE missing permission level records
	# (this code is duplicated in getPasswords, above)
	for (my $i = 0; $i < @PermissionLevels; $i++) {
		my $PermissionLevel = $PermissionLevels[$i];
		my $userID = $userIDs[$i];
		if (not defined $PermissionLevel) {
			if ($self->{user}->exists($userID)) {
				$PermissionLevel = $self->newPermissionLevel(user_id => $userID);
				eval { $self->addPermissionLevel($PermissionLevel) };
				if ($@ and $@ !~ m/permission level exists/) {
					die "error while auto-creating permission level record for user $userID: $@";
				}
				$PermissionLevels[$i] = $PermissionLevel;
			}
		}
	}
	
	return @PermissionLevels;
}

sub addPermissionLevel {
	my ($self, $PermissionLevel) = shift->checkArgs(\@_, qw/REC:permission/);
	
	croak "addPermissionLevel: user ", $PermissionLevel->user_id, " not found"
		unless $self->{user}->exists($PermissionLevel->user_id);
	
	eval {
		return $self->{permission}->add($PermissionLevel);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addPermissionLevel: permission level exists (perhaps you meant to use putPermissionLevel?)";
	} elsif ($@) {
		die $@;
	}
}

sub putPermissionLevel {
	my ($self, $PermissionLevel) = shift->checkArgs(\@_, qw/REC:permission/);
	my $rows = $self->{permission}->put($PermissionLevel); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		# AUTO-CREATE permission level records
		return $self->addPermissionLevel($PermissionLevel);
	} else {
		return $rows;
	}
}

sub deletePermissionLevel {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	return $self->{permission}->delete($userID);
}

################################################################################
# key functions
################################################################################

BEGIN {
	*Key = gen_schema_accessor("key");
	*newKey = gen_new("key");
	*countKeysWhere = gen_count_where("key");
	*existsKeyWhere = gen_exists_where("key");
	*listKeysWhere = gen_list_where("key");
	*getKeysWhere = gen_get_records_where("key");
}

sub countKeys { return scalar shift->listKeys(@_) }

sub listKeys {
	my ($self) = shift->checkArgs(\@_);
	if (wantarray) {
		return map { @$_ } $self->{key}->get_fields_where(["user_id"]);
	} else {
		return $self->{key}->count_where;
	}
}

sub existsKey {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	return $self->{key}->exists($userID);
}

sub getKey {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	return ( $self->getKeys($userID) )[0];
}

sub getKeys {
	my ($self, @userIDs) = shift->checkArgs(\@_, qw/user_id*/);
	return $self->{key}->gets(map { [$_] } @userIDs);
}

sub addKey {
	# PROCTORING - allow comma in keyfields
	my ($self, $Key) = shift->checkArgs(\@_, qw/VREC:key/);
	
	# PROCTORING -  check for both user and proctor
	# we allow for two entries for proctor keys, one of the form 
	#    userid,proctorid (which authorizes login), and the other 
	#    of the form userid,proctorid,g (which authorizes grading)
	# (having two of these means that a proctored test will require 
	#    authorization for both login and grading).
	if ($Key->user_id =~ /([^,]+)(?:,([^,]*))?(,g)?/) {
		my ($userID, $proctorID) = ($1, $2);
		croak "addKey: user $userID not found"
#			unless $self->{user}->exists($userID);
			unless $Key -> key eq "nonce" or $self->{user}->exists($userID);
		croak "addKey: proctor $proctorID not found"
#			unless $self->{user}->exists($proctorID);
			unless $Key -> key eq "nonce" or $self->{user}->exists($proctorID);
	} else {
		croak "addKey: user ", $Key->user_id, " not found"
#			unless $self->{user}->exists($Key->user_id);
			unless $Key -> key eq "nonce" or $self->{user}->exists($Key->user_id);
	}
	
	eval {
		return $self->{key}->add($Key);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addKey: key exists (perhaps you meant to use putKey?)";
	} elsif ($@) {
		die $@;
	}
}

sub putKey {
	# PROCTORING - allow comma in keyfields
	my ($self, $Key) = shift->checkArgs(\@_, qw/VREC:key/);
	my $rows = $self->{key}->put($Key); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		croak "putKey: key not found (perhaps you meant to use addKey?)";
	} else {
		return $rows;
	}
}

sub deleteKey {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	return $self->{key}->delete($userID);
}

sub deleteAllProctorKeys {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	my $where = [user_id_like => "$userID,%"];

	return $self->{key}->delete_where($where);
}

################################################################################
# setting functions
################################################################################

BEGIN {
	*Setting = gen_schema_accessor("setting");
	*newSetting = gen_new("setting");
	*countSettingsWhere = gen_count_where("setting");
	*existsSettingWhere = gen_exists_where("setting");
	*listSettingsWhere = gen_list_where("setting");
	*getSettingsWhere = gen_get_records_where("setting");
	*addSettings = gen_insert_records("setting");
	*putSettings = gen_update_records("setting");
	*deleteSettingsWhere = gen_delete_where("setting");
}

# minimal set of routines for basic setting operation
# we don't need a full set, since the usage of settings is somewhat limited
# we also don't want to bother with records, since a setting is just a pair

sub settingExists {
	my ($self, $name) = @_;
	return $self->{setting}->exists_where([name_eq=>$name]);
}

sub getSettingValue {
	my ($self, $name) = @_;
	return map { @$_ } $self->{setting}->get_fields_where(['value'], [name_eq=>$name]);
}

# we totally don't care if a setting already exists (and in fact i find that
# whole distinction somewhat annoying lately) so we hide the fact that we're
# either calling insert or update. at some point we could stand to add a
# method to Std.pm that used REPLACE INTO and then we'd be able to not care
# at all whether a setting was already there
sub setSettingValue {
	my ($self, $name, $value) = @_;
	if ($self->settingExists($name)) {
		return $self->{setting}->update_where({value=>$value}, [name_eq=>$name]);
	} else {
		return $self->{setting}->insert_fields(['name','value'], [[$name,$value]]);
	}
}

sub deleteSetting {
	my ($self, $name) = shift->checkArgs(\@_, qw/name/);
	return $self->{setting}->delete_where([name_eq=>$name]);
}

################################################################################
# locations functions
################################################################################
# this database table is for ip restrictions by assignment
# the locations table defines names of locations consisting of 
#    lists of ip masks (found in the location_addresses table)
#    to which assignments can be restricted to or denied from.

BEGIN { 
	*Location = gen_schema_accessor("locations");
	*newLocation = gen_new("locations");
	*countLocationsWhere = gen_count_where("locations");
	*existsLocationWhere = gen_exists_where("locations");
	*listLocationsWhere = gen_list_where("locations");
	*getLocationsWhere = gen_get_records_where("locations");
}

sub countLocations { return scalar shift->listLocations(@_) }

sub listLocations {
	my ( $self ) = shift->checkArgs(\@_);
	if ( wantarray ) {
	    return map {@$_} $self->{locations}->get_fields_where(["location_id"]);
	} else {
		return $self->{locations}->count_where;
	}
}

sub existsLocation { 
	my ( $self, $locationID ) = shift->checkArgs(\@_, qw/location_id/);
	return $self->{locations}->exists($locationID);
}

sub getLocation { 
	my ( $self, $locationID ) = shift->checkArgs(\@_, qw/location_id/);
	return ( $self->getLocations($locationID) )[0];
}

sub getLocations {
	my ( $self, @locationIDs ) = shift->checkArgs(\@_, qw/location_id*/);
	return $self->{locations}->gets(map {[$_]} @locationIDs);
}

sub getAllLocations { 
	my ( $self ) = shift->checkArgs(\@_);
	return $self->{locations}->get_records_where();
}

sub addLocation { 
	my ( $self, $Location ) = shift->checkArgs(\@_, qw/REC:locations/);

	eval {
		return $self->{locations}->add($Location);
	};
	if ( my $ex = caught WeBWorK::DB::Ex::RecordExists ) {
		croak "addLocation: location exists (perhaps you meant to use putLocation?)";
	} elsif ($@) {
		die $@;
	}
}

sub putLocation { 
	my ($self, $Location) = shift->checkArgs(\@_, qw/REC:locations/);
	my $rows = $self->{locations}->put($Location);
	if ( $rows == 0 ) {
		croak "putLocation: location not found (perhaps you meant to use addLocation?)";
	} else {
		return $rows;
	}
}

sub deleteLocation {
	# do we need to allow calls from this package?  I can't think of
	#    any case where that would happen, but we include it for other
	#    deletions, so I'll keep it here.
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ( $self, $locationID ) = shift->checkArgs(\@_, "location_id$U");
	$self->deleteGlobalSetLocation(undef, $locationID);
	$self->deleteUserSetLocation(undef, undef, $locationID);

	# NOTE: the one piece of this that we don't address is if this 
	#    results in all of the locations in a set's restriction being
	#    cleared; in this case, we should probably also reset the 
	#    set->restrict_ip setting as well.  but that requires going 
	#    out and doing a bunch of manipulations that well exceed what
	#    we want to do in this routine, so we'll assume that the user
	#    is smart enough to deal with that on her own.

	# addresses in the location_addresses table also need to be cleared
	$self->deleteLocationAddress($locationID, undef);

	return $self->{locations}->delete($locationID);
}

################################################################################
# location_addresses functions
################################################################################
# this database table is for ip restrictions by assignment
# the location_addresses table defines the ipmasks associate 
#    with the locations that are used for restrictions.

BEGIN { 
	*LocationAddress = gen_schema_accessor("location_addresses");
	*newLocationAddress = gen_new("location_addresses");
	*countLocationAddressesWhere = gen_count_where("location_addresses");
	*existsLocationAddressWhere = gen_exists_where("location_addresses");
	*listLocationAddressesWhere = gen_list_where("location_addresses");
	*getLocationAddressesWhere = gen_get_records_where("location_addresses");
}

sub countAddressLocations { return scalar shift->listAddressLocations(@_) }

sub listAddressLocations { 
	my ($self, $ipmask) = shift->checkArgs(\@_, qw/ip_mask/);
	my $where = [ip_mask_eq => $ipmask];
	if ( wantarray ) {
		return map {@$_} $self->{location_addresses}->get_fields_where(["location_id"],$where);
	} else {
		return $self->{location_addresses}->count_where($where);
	}
}

sub countLocationAddresses { return scalar shift->listLocationAddresses(@_) }

sub listLocationAddresses {
	my ($self, $locationID) = shift->checkArgs(\@_, qw/location_id/);
	my $where = [location_id_eq => $locationID];
	if ( wantarray ) { 
		return map {@$_} $self->{location_addresses}->get_fields_where(["ip_mask"],$where);
	} else {
		return $self->{location_addresses}->count_where($where);
	}
}

sub existsLocationAddress { 
	my ($self, $locationID, $ipmask) = shift->checkArgs(\@_, qw/location_id ip_mask/);
	return $self->{location_addresses}->exists($locationID, $ipmask);
}

# we wouldn't ever getLocationAddress or getLocationAddresses; to use those
#   we would have to know all of the information that we're getting

sub getAllLocationAddresses { 
	my ($self, $locationID) = shift->checkArgs(\@_, qw/location_id/);
	my $where = [location_id_eq => $locationID];
	return $self->{location_addresses}->get_records_where($where);
}

sub addLocationAddress { 
	my ($self, $LocationAddress) = shift->checkArgs(\@_, qw/REC:location_addresses/);
	croak "addLocationAddress: location ", $LocationAddress->location_id, " not found" 
		unless $self->{locations}->exists($LocationAddress->location_id);
	eval {
		return $self->{location_addresses}->add($LocationAddress);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addLocationAddress: location address exists (perhaps you meant to use putLocationAddress?)";
	} elsif ($@) {
		die $@;
	}
}

sub putLocationAddress { 
	my ($self, $LocationAddress) = shift->checkArgs(\@_, qw/REC:location_addresses/);
	my $rows = $self->{location_addresses}->put($LocationAddress);
	if ( $rows == 0 ) {
		croak "putLocationAddress: location address not found (perhaps you meant to use addLocationAddress?)";
	} else {
		return $rows;
	}
}

sub deleteLocationAddress { 
	# allow for undef values
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $locationID, $ipmask) = shift->checkArgs(\@_, "location_id$U", "ip_mask$U");
	return $self->{location_addresses}->delete($locationID, $ipmask);
}


################################################################################
# past_answers functions
################################################################################

BEGIN {
	*PastAnswer = gen_schema_accessor("past_answer");
	*newPastAnswer = gen_new("past_answer");
	*countPastAnswersWhere = gen_count_where("past_answer");
	*existsPastAnswersWhere = gen_exists_where("past_answer");
	*listPastAnswersWhere = gen_list_where("past_answer");
	*getPastAnswersWhere = gen_get_records_where("past_answer");
}

sub countProblemPastAnswers { return scalar shift->listPastAnswers(@_) }

sub listProblemPastAnswers {
        my ($self, $courseID, $userID, $setID, $problemID) = shift->checkArgs(\@_, qw/course_id user_id set_id problem_id/);
 my $where = [course_id_eq_user_id_eq_set_id_eq_problem_id_eq => $courseID,$userID,$setID,$problemID];
        my $order = [ 'answer_id' ];

	if (wantarray) {
		return map { @$_ } $self->{past_answer}->get_fields_where(["answer_id"], $where, $order);
	} else {
		return $self->{past_answer}->count_where($where);
	}
}


sub latestProblemPastAnswer {
        my ($self, $courseID, $userID, $setID, $problemID) = shift->checkArgs(\@_, qw/course_id user_id set_id problem_id/);
	my @answerIDs = $self->listProblemPastAnswers($courseID,$userID,$setID,$problemID);
	#array should already be returned from lowest id to greatest.  Latest answer is greatest
	return $answerIDs[$#answerIDs];
}


sub existsPastAnswer {
	my ($self, $answerID) = shift->checkArgs(\@_, qw/answer_id/);
	return $self->{past_answer}->exists($answerID);
}

sub getPastAnswer {
	my ($self, $answerID) = shift->checkArgs(\@_, qw/answer_id/);
	return ( $self->getPastAnswers([$answerID]) )[0];
}

sub getPastAnswers {
	my ($self, @answerIDs) = shift->checkArgsRefList(\@_, qw/answer_id*/);
	return $self->{past_answer}->gets(map { [$_] } @answerIDs);
}

sub addPastAnswer {
	my ($self, $pastAnswer) = shift->checkArgs(\@_, qw/REC:past_answer/);

#       we dont have a course table yet but when we do we should check this

#	croak "addPastAnswert: course ", $pastAnswer->course_id, " not found"
#		unless $self->{course}->exists($pastAnswer->course_id);

	croak "addPastAnswert: user problem ", $pastAnswer->user_id, " ", 
              $pastAnswer->set_id, " ", $pastAnswer->problem_id, " not found"
		unless 	$self->{problem_user}->exists($pastAnswer->user_id, 
						      $pastAnswer->set_id,
						      $pastAnswer->problem_id);

	eval {
		return $self->{past_answer}->add($pastAnswer);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addPastAnswer: past answer exists (perhaps you meant to use putPastAnswer?)";
	} elsif ($@) {
		die $@;
	}
}

sub putPastAnswer {
	my ($self, $pastAnswer) = shift->checkArgs(\@_, qw/REC:past_answer/);
	my $rows = $self->{past_answer}->put($pastAnswer); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		croak "putPastAnswer: past answer not found (perhaps you meant to use addPastAnswer?)";
	} else {
		return $rows;
	}
}

sub deletePastAnswer {
	# userID and achievementID can be undefined if being called from this package
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $answer_id) = shift->checkArgs(\@_, "answer_id$U");
	return $self->{past_answer}->delete($answer_id);
}


################################################################################
# set functions
################################################################################

BEGIN {
	*GlobalSet = gen_schema_accessor("set");
	*newGlobalSet = gen_new("set");
	*countGlobalSetsWhere = gen_count_where("set");
	*existsGlobalSetWhere = gen_exists_where("set");
	*listGlobalSetsWhere = gen_list_where("set");
	*getGlobalSetsWhere = gen_get_records_where("set");
}

sub countGlobalSets { return scalar shift->listGlobalSets(@_) }

sub listGlobalSets {
	my ($self) = shift->checkArgs(\@_);
	if (wantarray) {
		return map { @$_ } $self->{set}->get_fields_where(["set_id"]);
	} else {
		return $self->{set}->count_where;
	}
}

sub existsGlobalSet {
	my ($self, $setID) = shift->checkArgs(\@_, qw/set_id/);
	return $self->{set}->exists($setID);
}

sub getGlobalSet {
	my ($self, $setID) = shift->checkArgs(\@_, qw/set_id/);
	return ( $self->getGlobalSets($setID) )[0];
}

sub getGlobalSets {
	my ($self, @setIDs) = shift->checkArgs(\@_, qw/set_id*/);
	return $self->{set}->gets(map { [$_] } @setIDs);
}

sub addGlobalSet {
	my ($self, $GlobalSet) = shift->checkArgs(\@_, qw/REC:set/);
	
	eval {

		return $self->{set}->add($GlobalSet);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addGlobalSet: global set exists (perhaps you meant to use putGlobalSet?)";
	} elsif ($@) {
		die $@;
	}
}

sub putGlobalSet {
	my ($self, $GlobalSet) = shift->checkArgs(\@_, qw/REC:set/);
	my $rows = $self->{set}->put($GlobalSet); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		croak "putGlobalSet: global set not found (perhaps you meant to use addGlobalSet?)";
	} else {
		return $rows;
	}
}

sub deleteGlobalSet {
	# setID can be undefined if being called from this package
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $setID) = shift->checkArgs(\@_, "set_id$U");
	$self->deleteUserSet(undef, $setID);
	$self->deleteGlobalProblem($setID, undef);
	$self->deleteGlobalSetLocation($setID, undef);
	return $self->{set}->delete($setID);
}

####################################################################
## achievement functions
###############################################################

BEGIN {
	*Achievement = gen_schema_accessor("achievement");
	*newAchievement = gen_new("achievement");
	*countAchievementsWhere = gen_count_where("achievement");
	*existsAchievementWhere = gen_exists_where("achievement");
	*listAchievementsWhere = gen_list_where("achievement");
	*getAchievementsWhere = gen_get_records_where("achievement");
}

sub countAchievements { return scalar shift->listAchievements(@_) }

sub listAchievements {
	my ($self) = shift->checkArgs(\@_);
	if (wantarray) {
		return map { @$_ } $self->{achievement}->get_fields_where(["achievement_id"]);
	} else {
		return $self->{achievement}->count_where;
	}
}

sub existsAchievement {
	my ($self, $achievementID) = shift->checkArgs(\@_, qw/achievement_id/);
	return $self->{achievement}->exists($achievementID);
}

sub getAchievement {
	my ($self, $achievementID) = shift->checkArgs(\@_, qw/achievement_id/);
	return ( $self->getAchievements($achievementID) )[0];
}

sub getAchievements {
	my ($self, @achievementIDs) = shift->checkArgs(\@_, qw/achievement_id*/);
	return $self->{achievement}->gets(map { [$_] } @achievementIDs);
}

sub addAchievement {
	my ($self, $Achievement) = shift->checkArgs(\@_, qw/REC:achievement/);
	
	eval {

		return $self->{achievement}->add($Achievement);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addAchievement: achievement exists (perhaps you meant to use putAchievement?)";
	} elsif ($@) {
		die $@;
	}
}

sub putAchievement {
	my ($self, $Achievement) = shift->checkArgs(\@_, qw/REC:achievement/);
	my $rows = $self->{achievement}->put($Achievement); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		croak "putAchievement: achievement not found (perhaps you meant to use addAchievement?)";
	} else {
		return $rows;
	}
}

sub deleteAchievement {
	# achievementID can be undefined if being called from this package
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $achievementID) = shift->checkArgs(\@_, "achievement_id$U");
	$self->deleteUserAchievement(undef, $achievementID);
	return $self->{achievement}->delete($achievementID);
}

####################################################################
## global_user_achievement functions
###############################################################

BEGIN {
	*GlobalUserAchievement = gen_schema_accessor("global_user_achievement");
	*newGlobalUserAchievement = gen_new("global_user_achievement");
	*countGlobalUserAchievementsWhere = gen_count_where("global_user_achievement");
	*existsGlobalUserAchievementWhere = gen_exists_where("global_user_achievement");
	*listGlobalUserAchievementsWhere = gen_list_where("global_user_achievement");
	*getGlobalUserAchievementsWhere = gen_get_records_where("global_user_achievement");
}

sub countGlobalUserAchievements { return scalar shift->listGlobalUserAchievements(@_) }

sub listGlobalUserAchievements {
	my ($self) = shift->checkArgs(\@_);
	if (wantarray) {
		return map { @$_ } $self->{global_user_achievement}->get_fields_where(["user_id"]);
	} else {
		return $self->{global_user_achievement}->count_where;
	}
}

sub existsGlobalUserAchievement {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	return $self->{global_user_achievement}->exists($userID);
}

sub getGlobalUserAchievement {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	return ( $self->getGlobalUserAchievements($userID) )[0];
}

sub getGlobalUserAchievements {
	my ($self, @userIDs) = shift->checkArgs(\@_, qw/user_id*/);
	return $self->{global_user_achievement}->gets(map { [$_] } @userIDs);
}

sub addGlobalUserAchievement {
	my ($self, $globalUserAchievement) = shift->checkArgs(\@_, qw/REC:global_user_achievement/);
	
	eval {

	    return $self->{global_user_achievement}->add($globalUserAchievement);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addGlobalUserAchievement: user achievement exists (perhaps you meant to use putGlobalUserAchievement?)";
	} elsif ($@) {
		die $@;
	}
}

sub putGlobalUserAchievement {
	my ($self, $globalUserAchievement) = shift->checkArgs(\@_, qw/REC:global_user_achievement/);
	my $rows = $self->{global_user_achievement}->put($globalUserAchievement); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		croak "putGlobalUserAchievement: user achievement not found (perhaps you meant to use addGlobalUserAchievement?)";
	} else {
		return $rows;
	}
}

sub deleteGlobalUserAchievement {
	# userAchievementID can be undefined if being called from this package
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $userID) = shift->checkArgs(\@_, "user_id$U");
	if ($self->{global_user_achievement}){
		return $self->{global_user_achievement}->delete($userID);
	} else {
		return 0;
	}
}


################################################################################
# achievement_user functions
################################################################################

BEGIN {
	*UserAchievement = gen_schema_accessor("achievement_user");
	*newUserAchievement = gen_new("achievement_user");
	*countUserAchievementsWhere = gen_count_where("achievement_user");
	*existsUserAchievementWhere = gen_exists_where("achievement_user");
	*listUserAchievementsWhere = gen_list_where("achievement_user");
	*getUserAchievementsWhere = gen_get_records_where("achievement_user");
}

sub countAchievementUsers { return scalar shift->listAchievementUsers(@_) }

sub listAchievementUsers {
	my ($self, $achievementID) = shift->checkArgs(\@_, qw/achievement_id/);
	my $where = [achievement_id_eq => $achievementID];
	if (wantarray) {
		return map { @$_ } $self->{achievement_user}->get_fields_where(["user_id"], $where);
	} else {
		return $self->{achievement_user}->count_where($where);
	}
}

sub countUserAchievements { return scalar shift->listUserAchievements(@_) }

sub listUserAchievements {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	my $where = [user_id_eq => $userID];
	if (wantarray) {
		return map { @$_ } $self->{achievement_user}->get_fields_where(["achievement_id"], $where);
	} else {
		return $self->{achievement_user}->count_where($where);
	}
}

sub existsUserAchievement {
	my ($self, $userID, $achievementID) = shift->checkArgs(\@_, qw/user_id achievement_id/);
	return $self->{achievement_user}->exists($userID, $achievementID);
}

sub getUserAchievement {
	my ($self, $userID, $achievementID) = shift->checkArgs(\@_, qw/user_id achievement_id/);
	return ( $self->getUserAchievements([$userID, $achievementID]) )[0];
}

sub getUserAchievements {
	my ($self, @userAchievementIDs) = shift->checkArgsRefList(\@_, qw/user_id achievement_id/);
	return $self->{achievement_user}->gets(@userAchievementIDs);
}

sub addUserAchievement {
	my ($self, $UserAchievement) = shift->checkArgs(\@_, qw/REC:achievement_user/);
	
	croak "addUserAchievement: user ", $UserAchievement->user_id, " not found"
		unless $self->{user}->exists($UserAchievement->user_id);
	croak "addUserAchievement: achievement ", $UserAchievement->achievement_id, " not found"
		unless $self->{achievement}->exists($UserAchievement->achievement_id);
	
	eval {
		return $self->{achievement_user}->add($UserAchievement);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addUserAchievement: user achievement exists (perhaps you meant to use putUserAchievement?)";
	} elsif ($@) {
		die $@;
	}
}

sub putUserAchievement {
	my ($self, $UserAchievement) = shift->checkArgs(\@_, qw/REC:achievement_user/);
	my $rows = $self->{achievement_user}->put($UserAchievement); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		croak "putUserAchievement: user achievement not found (perhaps you meant to use addUserAchievement?)";
	} else {
		return $rows;
	}
}

sub deleteUserAchievement {
	# userID and achievementID can be undefined if being called from this package
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $userID, $achievementID) = shift->checkArgs(\@_, "user_id$U", "achievement_id$U");
	return $self->{achievement_user}->delete($userID, $achievementID);
}

################################################################################
# set_user functions
################################################################################

BEGIN {
	*UserSet = gen_schema_accessor("set_user");
	*newUserSet = gen_new("set_user");
	*countUserSetsWhere = gen_count_where("set_user");
	*existsUserSetWhere = gen_exists_where("set_user");
	*listUserSetsWhere = gen_list_where("set_user");
	*getUserSetsWhere = gen_get_records_where("set_user");
}

sub countSetUsers { return scalar shift->listSetUsers(@_) }

sub listSetUsers {
	my ($self, $setID) = shift->checkArgs(\@_, qw/set_id/);
	my $where = [set_id_eq => $setID];
	if (wantarray) {
		return map { @$_ } $self->{set_user}->get_fields_where(["user_id"], $where);
	} else {
		return $self->{set_user}->count_where($where);
	}
}

sub countUserSets { return scalar shift->listUserSets(@_) }

sub listUserSets {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	my $where = [user_id_eq => $userID];
	if (wantarray) {
		return map { @$_ } $self->{set_user}->get_fields_where(["set_id"], $where);
	} else {
		return $self->{set_user}->count_where($where);
	}
}

sub existsUserSet {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);
	return $self->{set_user}->exists($userID, $setID);
}

sub getUserSet {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);
	return ( $self->getUserSets([$userID, $setID]) )[0];
}

sub getUserSets {
	my ($self, @userSetIDs) = shift->checkArgsRefList(\@_, qw/user_id set_id/);
	return $self->{set_user}->gets(@userSetIDs);
}

# the code from addUserSet() is duplicated in large part following in 
# addVersionedUserSet; changes here should accordingly be propagated down there
sub addUserSet {
	my ($self, $UserSet) = shift->checkArgs(\@_, qw/REC:set_user/);
	
	croak "addUserSet: user ", $UserSet->user_id, " not found"
		unless $self->{user}->exists($UserSet->user_id);
	croak "addUserSet: set ", $UserSet->set_id, " not found"
		unless $self->{set}->exists($UserSet->set_id);
	eval {
		return $self->{set_user}->add($UserSet);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addUserSet: user set exists (perhaps you meant to use putUserSet?)";
	} elsif ($@) {
		die $@;
	}
}

# the code from putUserSet() is duplicated in large part in the following
# putVersionedUserSet; c.f. that routine
sub putUserSet {
	my ($self, $UserSet) = shift->checkArgs(\@_, qw/REC:set_user/);
	my $rows = $self->{set_user}->put($UserSet); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		croak "putUserSet: user set not found (perhaps you meant to use addUserSet?)";
	} else {
		return $rows;
	}
}

sub deleteUserSet {
	# userID and setID can be undefined if being called from this package
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $userID, $setID) = shift->checkArgs(\@_, "user_id$U", "set_id$U");
	$self->deleteSetVersion($userID, $setID, undef);
	$self->deleteUserProblem($userID, $setID, undef);
	return $self->{set_user}->delete($userID, $setID);
}

################################################################################
# set_merged functions
################################################################################

BEGIN {
	*MergedSet = gen_schema_accessor("set_merged");
	#*newMergedSet = gen_new("set_merged");
	#*countMergedSetsWhere = gen_count_where("set_merged");
	*existsMergedSetWhere = gen_exists_where("set_merged");
	#*listMergedSetsWhere = gen_list_where("set_merged");
	*getMergedSetsWhere = gen_get_records_where("set_merged");
}

sub existsMergedSet {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);
	return $self->{set_merged}->exists($userID, $setID);
}

sub getMergedSet {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);
	return ( $self->getMergedSets([$userID, $setID]) )[0];
}

sub getMergedSets {
	my ($self, @userSetIDs) = shift->checkArgsRefList(\@_, qw/user_id set_id/);
	return $self->{set_merged}->gets(@userSetIDs);
}

################################################################################
# set_version functions (NEW)
################################################################################

BEGIN {
	*SetVersion = gen_schema_accessor("set_version");
	*newSetVersion = gen_new("set_version");
	*countSetVersionsWhere = gen_count_where("set_version");
	*existsSetVersionWhere = gen_exists_where("set_version");
	*listSetVersionsWhere = gen_list_where("set_version");
	*getSetVersionsWhere = gen_get_records_where("set_version");
}

# versioned analog of countUserSets
sub countSetVersions { return scalar shift->listSetVersions(@_) }

# versioned analog of listUserSets
sub listSetVersions {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);
	my $where = [user_id_eq_set_id_eq => $userID,$setID];
	my $order = [ 'version_id' ];
	if (wantarray) {
		return map { @$_ } $self->{set_version}->get_fields_where(["version_id"], $where, $order);
	} else {
		return $self->{set_version}->count_where($where);
	}
}

# versioned analog of existsUserSet
sub existsSetVersion {
	my ($self, $userID, $setID, $versionID) = shift->checkArgs(\@_, qw/user_id set_id version_id/);
	return $self->{set_version}->exists($userID, $setID, $versionID);
}

# versioned analog of getUserSet
sub getSetVersion {
	my ($self, $userID, $setID, $versionID) = shift->checkArgs(\@_, qw/user_id set_id version_id/);
	return ( $self->getSetVersions([$userID, $setID, $versionID]) )[0];
}

# versioned analog of getUserSets
sub getSetVersions {
	my ($self, @setVersionIDs) = shift->checkArgsRefList(\@_, qw/user_id set_id version_id/);
	return $self->{set_version}->gets(@setVersionIDs);
}

# versioned analog of addUserSet
sub addSetVersion {
	my ($self, $SetVersion) = shift->checkArgs(\@_, qw/REC:set_version/);
	
	croak "addSetVersion: set ", $SetVersion->set_id, " not found for user ", $SetVersion->user_id
		unless $self->{set_user}->exists($SetVersion->user_id, $SetVersion->set_id);
	
	eval {
		return $self->{set_version}->add($SetVersion);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addSetVersion: set version exists (perhaps you meant to use putSetVersion?)";
	} elsif ($@) {
		die $@;
	}
}

# versioned analog of putUserSet
sub putSetVersion {
	my ($self, $SetVersion) = shift->checkArgs(\@_, qw/REC:set_version/);
	my $rows = $self->{set_version}->put($SetVersion); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		croak "putSetVersion: set version not found (perhaps you meant to use addSetVersion?)";
	} else {
		return $rows;
	}
}

# versioned analog of deleteUserSet
sub deleteSetVersion {
	# userID, setID, and versionID can be undefined if being called from this package
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $userID, $setID, $versionID) = shift->checkArgs(\@_, "user_id$U", "set_id$U", "version_id$U");
	$self->deleteProblemVersion($userID, $setID, $versionID, undef);
	return $self->{set_version}->delete($userID, $setID, $versionID);
}

################################################################################
# set_version_merged functions (NEW)
################################################################################

BEGIN {
	*MergedSetVersion = gen_schema_accessor("set_version_merged");
	#*newMergedSetVersion = gen_new("set_version_merged");
	#*countMergedSetVersionsWhere = gen_count_where("set_version_merged");
	*existsMergedSetVersionWhere = gen_exists_where("set_version_merged");
	#*listMergedSetVersionsWhere = gen_list_where("set_version_merged");
	*getMergedSetVersionsWhere = gen_get_records_where("set_version_merged");
}

sub existsMergedSetVersion {
	my ($self, $userID, $setID, $versionID) = shift->checkArgs(\@_, qw/user_id set_id version_id/);
	return $self->{set_version_merged}->exists($userID, $setID, $versionID);
}

sub getMergedSetVersion {
	my ($self, $userID, $setID, $versionID) = shift->checkArgs(\@_, qw/user_id set_id version_id/);
	return ( $self->getMergedSetVersions([$userID, $setID, $versionID]) )[0];
}

sub getMergedSetVersions {
	my ($self, @setVersionIDs) = shift->checkArgsRefList(\@_, qw/user_id set_id version_id/);
	return $self->{set_version_merged}->gets(@setVersionIDs);
}

################################################################################
# set_locations functions
################################################################################
# this database table is for ip restrictions by assignment
# the set_locations table defines the association between a 
#    global set and the locations to which the set may be 
#    restricted or denied.

BEGIN {
	*GlobalSetLocation = gen_schema_accessor("set_locations");
	*newGlobalSetLocation = gen_new("set_locations");
	*countGlobalSetLocationsWhere = gen_count_where("set_locations");
	*existsGlobalSetLocationWhere = gen_exists_where("set_locations");
	*listGlobalSetLocationsWhere = gen_list_where("set_locations");
	*getGlobalSetLocationsWhere = gen_get_records_where("set_locations");
}

sub countGlobalSetLocations { return scalar shift->listGlobalSetLocations(@_) }

sub listGlobalSetLocations {
	my ( $self, $setID ) = shift->checkArgs(\@_, qw/set_id/);
	my $where = [set_id_eq => $setID];
	if ( wantarray ) {
		my $order = ['location_id'];
		return map { @$_ } $self->{set_locations}->get_fields_where(["location_id"], $where, $order);
	} else {
		return $self->{set_user}->count_where( $where );
	}
}

sub existsGlobalSetLocation { 
	my ( $self, $setID, $locationID ) = shift->checkArgs(\@_, qw/set_id location_id/);
	return $self->{set_locations}->exists( $setID, $locationID );
}

sub getGlobalSetLocation { 
	my ( $self, $setID, $locationID ) = shift->checkArgs(\@_, qw/set_id location_id/);
	return ( $self->getGlobalSetLocations([$setID, $locationID]) )[0];
}

sub getGlobalSetLocations {
	my ( $self, @locationIDs ) = shift->checkArgsRefList(\@_, qw/set_id location_id/);
	return $self->{set_locations}->gets(@locationIDs);
}

sub getAllGlobalSetLocations {
	my ( $self, $setID ) = shift->checkArgs(\@_, qw/set_id/);
	my $where = [set_id_eq => $setID];
	return $self->{set_locations}->get_records_where( $where );
}

sub addGlobalSetLocation { 
	my ( $self, $GlobalSetLocation ) = shift->checkArgs(\@_, qw/REC:set_locations/);
	croak "addGlobalSetLocation: set ", $GlobalSetLocation->set_id, " not found"
		unless $self->{set}->exists($GlobalSetLocation->set_id);
	
	eval {
		return $self->{set_locations}->add($GlobalSetLocation);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addGlobalSetLocation: global set_location exists (perhaps you meant to use putGlobalSetLocation?)";
	} elsif ($@) {
		die $@;
	}
}

sub putGlobalSetLocation {
	my ($self, $GlobalSetLocation) = shift->checkArgs(\@_, qw/REC:set_locations/);
	my $rows = $self->{set_locations}->put($GlobalSetLocation); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		croak "putGlobalSetLocation: global problem not found (perhaps you meant to use addGlobalSetLocation?)";
	} else {
		return $rows;
	}
}

sub deleteGlobalSetLocation {
	# setID and locationID can be undefined if being called from this package
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $setID, $locationID) = shift->checkArgs(\@_, "set_id$U", "location_id$U");
	$self->deleteUserSetLocation(undef, $setID, $locationID);
	return $self->{set_locations}->delete($setID, $locationID);
}

################################################################################
# set_locations_user functions
################################################################################
# this database table is for ip restrictions by assignment
# the set_locations_user table defines the set_user level
#    modifications to the set_locations defined for the 
#    global set

BEGIN {
	*UserSetLocation = gen_schema_accessor("set_locations_user");
	*newUserSetLocation = gen_new("set_locations_user");
	*countUserSetLocationWhere = gen_count_where("set_locations_user");
	*existsUserSetLocationWhere = gen_exists_where("set_locations_user");
	*listUserSetLocationsWhere = gen_list_where("set_locations_user");
	*getUserSetLocationsWhere = gen_get_records_where("set_locations_user");
}

sub countSetLocationUsers { return scalar shift->listSetLocationUsers(@_) }

sub listSetLocationUsers {
	my ($self, $setID, $locationID) = shift->checkArgs(\@_, qw/set_id location_id/);
	my $where = [set_id_eq_location_id_eq => $setID,$locationID];
	if (wantarray) {
		return map { @$_ } $self->{set_locations_user}->get_fields_where(["user_id"], $where);
	} else {
		return $self->{set_locations_user}->count_where($where);
	}
}

sub countUserSetLocations { return scalar shift->listUserSetLocations(@_) }

sub listUserSetLocations {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);
	my $where = [user_id_eq_set_id_eq => $userID,$setID];
	if (wantarray) {
		return map { @$_ } $self->{set_locations_user}->get_fields_where(["location_id"], $where);
	} else {
		return $self->{set_locations_user}->count_where($where);
	}
}

sub existsUserSetLocation {
	my ($self, $userID, $setID, $locationID) = shift->checkArgs(\@_, qw/user_id set_id location_id/);
	return $self->{set_locations_user}->exists($userID,$setID,$locationID);
}

# FIXME: we won't ever use this because all fields are key fields
sub getUserSetLocation {
	my ($self, $userID, $setID, $locationID) = shift->checkArgs(\@_, qw/user_id set_id location_id/);
	return( $self->getUserSetLocations([$userID, $setID, $locationID]) )[0];
}

# FIXME: we won't ever use this because all fields are key fields
sub getUserSetLocations {
	my ($self, @userSetLocationIDs) = shift->checkArgsRefList(\@_, qw/user_id set_id location_id/);
	return $self->{set_locations_user}->gets(@userSetLocationIDs);
}

sub getAllUserSetLocations {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);
	my $where = [user_id_eq_set_id_eq => $userID,$setID];
	return $self->{set_locations_user}->get_records_where($where);
}

sub addUserSetLocation {
	# VERSIONING - accept versioned ID fields
	my ($self, $UserSetLocation) = shift->checkArgs(\@_, qw/VREC:set_locations_user/);
	
	croak "addUserSetLocation: user set ", $UserSetLocation->set_id, " for user ", $UserSetLocation->user_id, " not found"
		unless $self->{set_user}->exists($UserSetLocation->user_id, $UserSetLocation->set_id);
	
	eval {
		return $self->{set_locations_user}->add($UserSetLocation);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addUserSetLocation: user set_location exists (perhaps you meant to use putUserSetLocation?)";
	} elsif ($@) {
		die $@;
	}
}

# FIXME: we won't ever use this because all fields are key fields
# versioned_ok is an optional argument which lets us slip versioned setIDs through checkArgs.
sub putUserSetLocation {
	my $V = $_[2] ? "V" : "";
	my ($self, $UserSetLocation, undef) = shift->checkArgs(\@_, "${V}REC:set_locations_user", "versioned_ok!?");
	
	my $rows = $self->{set_locations_user}->put($UserSetLocation); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		croak "putUserSetLocation: user set location not found (perhaps you meant to use addUserSetLocation?)";
	} else {
		return $rows;
	}
}

sub deleteUserSetLocation {
	# userID, setID, and locationID can be undefined if being called from this package
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $userID, $setID, $locationID) = shift->checkArgs(\@_, "user_id$U", "set_id$U", "set_locations_id$U");
	return $self->{set_locations_user}->delete($userID,$setID,$locationID);
}

################################################################################
# set_locations_merged functions
################################################################################
# this is different from other set_merged functions, because
#    in this case the only data that we have are the set_id,
#    location_id, and user_id, and we want to replace all 
#    locations from GlobalSetLocations with those from 
#    UserSetLocations if the latter exist.

sub getAllMergedSetLocations {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);

	if ( $self->countUserSetLocations($userID, $setID) ) {
		return $self->getAllUserSetLocations( $userID, $setID );
	} else {
		return $self->getAllGlobalSetLocations( $setID );
	}
}


################################################################################
# problem functions
################################################################################

BEGIN {
	*GlobalProblem = gen_schema_accessor("problem");
	*newGlobalProblem = gen_new("problem");
	*countGlobalProblemsWhere = gen_count_where("problem");
	*existsGlobalProblemWhere = gen_exists_where("problem");
	*listGlobalProblemsWhere = gen_list_where("problem");
	*getGlobalProblemsWhere = gen_get_records_where("problem");
}

sub countGlobalProblems { return scalar shift->listGlobalProblems(@_) }

sub listGlobalProblems {
	my ($self, $setID) = shift->checkArgs(\@_, qw/set_id/);
	my $where = [set_id_eq => $setID];
	if (wantarray) {
		return map { @$_ } $self->{problem}->get_fields_where(["problem_id"], $where);
	} else {
		return $self->{problem}->count_where($where);
	}
}

sub existsGlobalProblem {
	my ($self, $setID, $problemID) = shift->checkArgs(\@_, qw/set_id problem_id/);
	return $self->{problem}->exists($setID, $problemID);
}

sub getGlobalProblem {
	my ($self, $setID, $problemID) = shift->checkArgs(\@_, qw/set_id problem_id/);
	return ( $self->getGlobalProblems([$setID, $problemID]) )[0];
}

sub getGlobalProblems {
	my ($self, @problemIDs) = shift->checkArgsRefList(\@_, qw/set_id problem_id/);
	return $self->{problem}->gets(@problemIDs);
}

sub getAllGlobalProblems {
	my ($self, $setID) = shift->checkArgs(\@_, qw/set_id/);
	my $where = [set_id_eq => $setID];
	return $self->{problem}->get_records_where($where);
}

sub addGlobalProblem {	my ($self, $GlobalProblem) = shift->checkArgs(\@_, qw/REC:problem/);
	
	croak "addGlobalProblem: set ", $GlobalProblem->set_id, " not found"
		unless $self->{set}->exists($GlobalProblem->set_id);
	
	eval {
		return $self->{problem}->add($GlobalProblem);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addGlobalProblem: global problem exists (perhaps you meant to use putGlobalProblem?)";
	} elsif ($@) {
		die $@;
	}
}

sub putGlobalProblem {
	my ($self, $GlobalProblem) = shift->checkArgs(\@_, qw/REC:problem/);
	my $rows = $self->{problem}->put($GlobalProblem); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		croak "putGlobalProblem: global problem not found (perhaps you meant to use addGlobalProblem?)";
	} else {
		return $rows;
	}
}

sub deleteGlobalProblem {
	# userID and setID can be undefined if being called from this package
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $setID, $problemID) = shift->checkArgs(\@_, "set_id$U", "problem_id$U");
	$self->deleteUserProblem(undef, $setID, $problemID);
	return $self->{problem}->delete($setID, $problemID);
}

################################################################################
# problem_user functions
################################################################################

BEGIN {
	*UserProblem = gen_schema_accessor("problem_user");
	*newUserProblem = gen_new("problem_user");
	*countUserProblemsWhere = gen_count_where("problem_user");
	*existsUserProblemWhere = gen_exists_where("problem_user");
	*listUserProblemsWhere = gen_list_where("problem_user");
	*getUserProblemsWhere = gen_get_records_where("problem_user");
}

sub countProblemUsers { return scalar shift->listProblemUsers(@_) }

sub listProblemUsers {
	my ($self, $setID, $problemID) = shift->checkArgs(\@_, qw/set_id problem_id/);
	my $where = [set_id_eq_problem_id_eq => $setID,$problemID];
	if (wantarray) {
		return map { @$_ } $self->{problem_user}->get_fields_where(["user_id"], $where);
	} else {
		return $self->{problem_user}->count_where($where);
	}
}

sub countUserProblems { return scalar shift->listUserProblems(@_) }

sub listUserProblems {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);
	my $where = [user_id_eq_set_id_eq => $userID,$setID];
	if (wantarray) {
		return map { @$_ } $self->{problem_user}->get_fields_where(["problem_id"], $where);
	} else {
		return $self->{problem_user}->count_where($where);
	}
}

sub existsUserProblem {
	my ($self, $userID, $setID, $problemID) = shift->checkArgs(\@_, qw/user_id set_id problem_id/);
	return $self->{problem_user}->exists($userID, $setID, $problemID);
}

sub getUserProblem {
	my ($self, $userID, $setID, $problemID) = shift->checkArgs(\@_, qw/user_id set_id problem_id/);
	return ( $self->getUserProblems([$userID, $setID, $problemID]) )[0];
}

sub getUserProblems {
	my ($self, @userProblemIDs) = shift->checkArgsRefList(\@_, qw/user_id set_id problem_id/);
	return $self->{problem_user}->gets(@userProblemIDs);
}

sub getAllUserProblems {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);
	my $where = [user_id_eq_set_id_eq => $userID,$setID];
	return $self->{problem_user}->get_records_where($where);
}

sub addUserProblem {
	# VERSIONING - accept versioned ID fields
	my ($self, $UserProblem) = shift->checkArgs(\@_, qw/VREC:problem_user/);
	
	croak "addUserProblem: user set ", $UserProblem->set_id, " for user ", $UserProblem->user_id, " not found"
		unless $self->{set_user}->exists($UserProblem->user_id, $UserProblem->set_id);

	my ( $nv_set_id, $versionNum ) = grok_vsetID( $UserProblem->set_id );

	croak "addUserProblem: problem ", $UserProblem->problem_id, " in set $nv_set_id not found"
		unless $self->{problem}->exists($nv_set_id, $UserProblem->problem_id);
	
	eval {
		return $self->{problem_user}->add($UserProblem);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addUserProblem: user problem exists (perhaps you meant to use putUserProblem?)";
	} elsif ($@) {
		die $@;
	}
}

# versioned_ok is an optional argument which lets us slip versioned setIDs through checkArgs.
sub putUserProblem {
	my $V = $_[2] ? "V" : "";
	my ($self, $UserProblem, undef) = shift->checkArgs(\@_, "${V}REC:problem_user", "versioned_ok!?");
	
	my $rows = $self->{problem_user}->put($UserProblem); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		croak "putUserProblem: user problem not found (perhaps you meant to use addUserProblem?)";
	} else {
		return $rows;
	}
}

sub deleteUserProblem {
	# userID, setID, and problemID can be undefined if being called from this package
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $userID, $setID, $problemID) = shift->checkArgs(\@_, "user_id$U", "set_id$U", "problem_id$U");
	return $self->{problem_user}->delete($userID, $setID, $problemID);
}

################################################################################
# problem_merged functions
################################################################################

BEGIN {
	*MergedProblem = gen_schema_accessor("problem_merged");
	#*newMergedProblem = gen_new("problem_merged");
	#*countMergedProblemsWhere = gen_count_where("problem_merged");
	*existsMergedProblemWhere = gen_exists_where("problem_merged");
	#*listMergedProblemsWhere = gen_list_where("problem_merged");
	*getMergedProblemsWhere = gen_get_records_where("problem_merged");
}

sub existsMergedProblem {
	my ($self, $userID, $setID, $problemID) = shift->checkArgs(\@_, qw/user_id set_id problem_id/);
	return $self->{problem_merged}->exists($userID, $setID, $problemID);
}

sub getMergedProblem {
	my ($self, $userID, $setID, $problemID) = shift->checkArgs(\@_, qw/user_id set_id problem_id/);
	return ( $self->getMergedProblems([$userID, $setID, $problemID]) )[0];
}

sub getMergedProblems {
	my ($self, @userProblemIDs) = shift->checkArgsRefList(\@_, qw/user_id set_id problem_id/);
	return $self->{problem_merged}->gets(@userProblemIDs);
}

sub getAllMergedUserProblems {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);
	my $where = [user_id_eq_set_id_eq => $userID,$setID];
	return $self->{problem_merged}->get_records_where($where);
}

################################################################################
# problem_version functions (NEW)
################################################################################

BEGIN {
	*ProblemVersion = gen_schema_accessor("problem_version");
	*newProblemVersion = gen_new("problem_version");
	*countProblemVersionsWhere = gen_count_where("problem_version");
	*existsProblemVersionWhere = gen_exists_where("problem_version");
	*listProblemVersionsWhere = gen_list_where("problem_version");
	*getProblemVersionsWhere = gen_get_records_where("problem_version");
}

# versioned analog of countUserProblems
sub countProblemVersions { return scalar shift->listProblemVersions(@_) }

# versioned analog of listUserProblems
sub listProblemVersions { 
	my ($self, $userID, $setID, $versionID) = shift->checkArgs(\@_, qw/user_id set_id version_id/);
	my $where = [user_id_eq_set_id_eq_version_id_eq => $userID,$setID,$versionID];
	if (wantarray) {
		return map { @$_ } $self->{problem_version}->get_fields_where(["problem_id"], $where);
	} else {
		return $self->{problem_version}->count_where($where);
	}
}

# this code returns a list of all problem versions with the given userID,
# setID, and problemID, but that is (darn well ought to be) the same as 
# listSetVersions, so it's not so useful as all that; c.f. above.
# sub listProblemVersions {
# 	my ($self, $userID, $setID, $problemID) = shift->checkArgs(\@_, qw/user_id set_id problem_id/);
# 	my $where = [user_id_eq_set_id_eq_problem_id_eq => $userID,$setID,$problemID];
# 	if (wantarray) {
# 		return grep { @$_ } $self->{problem_version}->get_fields_where(["version_id"], $where);
# 	} else {
# 		return $self->{problem_version}->count_where($where);
# 	}
# }

# versioned analog of existsUserProblem
sub existsProblemVersion {
	my ($self, $userID, $setID, $versionID, $problemID) = shift->checkArgs(\@_, qw/user_id set_id version_id problem_id/);
	return $self->{problem_version}->exists($userID, $setID, $versionID, $problemID);
}

# versioned analog of getUserProblem
sub getProblemVersion {
	my ($self, $userID, $setID, $versionID, $problemID) = shift->checkArgs(\@_, qw/user_id set_id version_id problem_id/);
	return ( $self->getProblemVersions([$userID, $setID, $versionID, $problemID]) )[0];
}

# versioned analog of getUserProblems
sub getProblemVersions {
	my ($self, @problemVersionIDs) = shift->checkArgsRefList(\@_, qw/user_id set_id version_id problem_id/);
	return $self->{problem_version}->gets(@problemVersionIDs);
}

# versioned analog of getAllUserProblems
sub getAllProblemVersions {
	my ( $self, $userID, $setID, $versionID ) = shift->checkArgs(\@_, qw/user_id set_id version_id/);
	my $where = [user_id_eq_set_id_eq_version_id_eq => $userID,$setID,$versionID];
	my $order = ["problem_id"];
	return $self->{problem_version_merged}->get_records_where($where,$order);
}


# versioned analog of addUserProblem
sub addProblemVersion {
	my ($self, $ProblemVersion) = shift->checkArgs(\@_, qw/REC:problem_version/);
	
	croak "addProblemVersion: set version ", $ProblemVersion->version_id, " of set ", $ProblemVersion->set_id, " not found for user ", $ProblemVersion->user_id
		unless $self->{set_version}->exists($ProblemVersion->user_id, $ProblemVersion->set_id, $ProblemVersion->version_id);
	croak "addProblemVersion: problem ", $ProblemVersion->problem_id, " of set ", $ProblemVersion->set_id, " not found for user ", $ProblemVersion->user_id
		unless $self->{problem_user}->exists($ProblemVersion->user_id, $ProblemVersion->set_id, $ProblemVersion->problem_id);
	
	eval {
		return $self->{problem_version}->add($ProblemVersion);
	};
	if (my $ex = caught WeBWorK::DB::Ex::RecordExists) {
		croak "addProblemVersion: problem version exists (perhaps you meant to use putProblemVersion?)";
	} elsif ($@) {
		die $@;
	}
}

# versioned analog of putUserProblem
sub putProblemVersion {
	my ($self, $ProblemVersion) = shift->checkArgs(\@_, qw/REC:problem_version/);
	my $rows = $self->{problem_version}->put($ProblemVersion); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		croak "putProblemVersion: problem version not found (perhaps you meant to use addProblemVersion?)";
	} else {
		return $rows;
	}
}

# versioned analog of deleteUserProblem
sub deleteProblemVersion {
	# userID, setID, versionID, and problemID can be undefined if being called from this package
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $userID, $setID, $versionID, $problemID) = shift->checkArgs(\@_, "user_id$U", "set_id$U", "version_id$U", "problem_id$U");
	return $self->{problem_version}->delete($userID, $setID, $versionID, $problemID);
}

################################################################################
# problem_version_merged functions (NEW)
################################################################################

BEGIN {
	*MergedProblemVersion = gen_schema_accessor("problem_version_merged");
	#*newMergedProblemVersion = gen_new("problem_version_merged");
	#*countMergedProblemVersionsWhere = gen_count_where("problem_version_merged");
	*existsMergedProblemVersionWhere = gen_exists_where("problem_version_merged");
	#*listMergedProblemVersionsWhere = gen_list_where("problem_version_merged");
	*getMergedProblemVersionsWhere = gen_get_records_where("problem_version_merged");
}

sub existsMergedProblemVersion {
	my ($self, $userID, $setID, $versionID, $problemID) = shift->checkArgs(\@_, qw/user_id set_id version_id problem_id/);
	return $self->{problem_version_merged}->exists($userID, $setID, $versionID, $problemID);
}

sub getMergedProblemVersion {
	my ($self, $userID, $setID, $versionID, $problemID) = shift->checkArgs(\@_, qw/user_id set_id version_id problem_id/);
	return ( $self->getMergedProblemVersions([$userID, $setID, $versionID, $problemID]) )[0];
}

sub getMergedProblemVersions {
	my ($self, @problemVersionIDs) = shift->checkArgsRefList(\@_, qw/user_id set_id version_id problem_id/);
	return $self->{problem_version_merged}->gets(@problemVersionIDs);
}

sub getAllMergedProblemVersions {
	my ($self, $userID, $setID, $versionID) = shift->checkArgs(\@_, qw/user_id set_id version_id/);
	my $where = [user_id_eq_set_id_eq_version_id_eq => $userID,$setID,$versionID];
	my $order = ["problem_id"];
	return $self->{problem_version_merged}->get_records_where($where,$order);
}

################################################################################
# utilities
################################################################################

sub check_user_id { #  (valid characters are [-a-zA-Z0-9_.,@]) 
	my $value = shift;
	if ($value =~ m/^[-a-zA-Z0-9_.@]*,?(set_id:)?[-a-zA-Z0-9_.@]*(,g)?$/ ) {
		return 1;
	} else {
		croak "invalid characters in user_id field: '$value' (valid characters are [-a-zA-Z0-9_.,@])";
		return 0;
	}
}
# the (optional) second argument to checkKeyfields is to support versioned
# (gateway) sets, which may include commas in certain fields (in particular,
# set names (e.g., setDerivativeGateway,v1) and user names (e.g., 
# username,proctorname)

sub checkKeyfields($;$) {
	my ($Record, $versioned) = @_;
	foreach my $keyfield ($Record->KEYFIELDS) {
		my $value = $Record->$keyfield;
		my $fielddata = $Record->FIELD_DATA;
		return if ($fielddata->{$keyfield}{type}=~/AUTO_INCREMENT/);

		croak "undefined '$keyfield' field"
			unless defined $value;
		croak "empty '$keyfield' field"
			unless $value ne "";
		
		if ($keyfield eq "problem_id") {
			croak "invalid characters in '$keyfield' field: '$value' (valid characters are [0-9])"
				unless $value =~ m/^[0-9]*$/;
		} elsif ($versioned and $keyfield eq "set_id") {
			croak "invalid characters in '$keyfield' field: '$value' (valid characters are [-a-zA-Z0-9_.,])"
				unless $value =~ m/^[-a-zA-Z0-9_.,]*$/;
		# } elsif ($versioned and $keyfield eq "user_id") { 
		} elsif ($keyfield eq "user_id") { 
			check_user_id($value); #  (valid characters are [-a-zA-Z0-9_.,]) see above.
		} elsif ($keyfield eq "ip_mask") {
			croak "invalid characters in '$keyfield' field: '$value' (valid characters are [-a-fA-F0-9_.:/])"
				unless $value =~ m/^[-a-fA-F0-9_.:\/]*$/;
			    
		} else {
			croak "invalid characters in '$keyfield' field: '$value' (valid characters are [-a-zA-Z0-9_.])"
				unless $value =~ m/^[-a-zA-Z0-9_.]*$/;
		}
	}
}


# checkArgs spec syntax:
# 
# spec = list_item | item*
# list_item = item is_list
# is_list = "*"
# item = item_name undef_ok? optional?
# item_name = record_item | bare_item
# record_item = is_versioned? "REC:" table
# is_versioned = "V"
# table = \w+
# bare_item = \w+
# undef_ok = "!"
# optional = "?"
# 
# [[V]REC:]foo[!][?][*]

sub checkArgs {
	my ($self, $args, @spec) = @_;
	
	my $is_list = @spec == 1 && $spec[0] =~ s/\*$//;
	my ($min_args, $max_args);
	if ($is_list) {
		$min_args = 0;
	} else {
		foreach my $i (0..$#spec) {
			#print "$i - $spec[$i]\n";
			if ($spec[$i] =~ s/\?$//) {
				#print "$i - matched\n";
				$min_args = $i unless defined $min_args;
			}
		}
		$min_args = @spec unless defined $min_args;
		$max_args = @spec;
	}
	
	if (@$args < $min_args or defined $max_args and @$args > $max_args) {
		if ($min_args == $max_args) {
			my $s = $min_args == 1 ? "" : "s";
			croak "requires $min_args argument$s";
		} elsif (defined $max_args) {
			croak "requires between $min_args and $max_args arguments";
		} else {
			my $s = $min_args == 1 ? "" : "s";
			croak "requires at least $min_args argument$s";
		}
	}
	
	my ($name, $versioned, $table);
	if ($is_list) {
		$name = $spec[0];
		($versioned, $table) = $name =~ /^(V?)REC:(.*)/;
	}
	
	foreach my $i (0..@$args-1) {
		my $arg = $args->[$i];
		my $pos = $i+1;
		
		unless ($is_list) {
			$name = $spec[$i];
			($versioned, $table) = $name =~ /^(V?)REC:(.*)/;
		}
		
		if (defined $table) {
			my $class = $self->{$table}{record};
			#print "arg=$arg class=$class\n";
			croak "argument $pos must be of type $class"
				unless defined $arg and ref $arg and $arg->isa($class);
			eval { checkKeyfields($arg, $versioned) };
			croak "argument $pos contains $@" if $@;
		} else {
			if ($name !~ /!$/) {
				croak "argument $pos must contain a $name"
					unless defined $arg;
			}
		}
	}
	
	return $self, @$args;
}

sub checkArgsRefList {
	my ($self, $items, @spec) = @_;
	foreach my $i (0..@$items-1) {
		my $item = $items->[$i];
		my $pos = $i+1;
		croak "item $pos must be a reference to an array"
			unless UNIVERSAL::isa($item, "ARRAY");
		eval { $self->checkArgs($item, @spec) };
		croak "item $pos $@" if $@;
	}
	
	return $self, @$items;
}

1;
