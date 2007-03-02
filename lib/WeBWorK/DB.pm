################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB.pm,v 1.90 2007/03/01 22:15:24 glarose Exp $
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
use WeBWorK::DB::Schema;
use WeBWorK::DB::Utils qw/make_vsetID grok_vsetID grok_setID_from_vsetID_sql
	grok_versionID_from_vsetID_sql/;
use WeBWorK::Debug;
use WeBWorK::Utils qw(runtime_use);

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

################################################################################
# create/rename/delete tables
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
	if (my $ex = caught WeBWorK::DB::Schema::Exception::RecordExists) {
		croak "addUser: user exists (perhaps you meant to use putUser?)";
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
	if (my $ex = caught WeBWorK::DB::Schema::Exception::RecordExists) {
		croak "addPassword: password exists (perhaps you meant to use putPassword?)";
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
	if (my $ex = caught WeBWorK::DB::Schema::Exception::RecordExists) {
		croak "addPermissionLevel: permission level exists (perhaps you meant to use putPermissionLevel?)";
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
	if ($Key->user_id =~ /([^,]+)(?:,(.*))?/) {
		my ($userID, $proctorID) = ($1, $2);
		croak "addKey: user $userID not found"
			unless $self->{user}->exists($userID);
		croak "addKey: proctor $proctorID not found"
			unless $self->{user}->exists($proctorID);
	} else {
		croak "addKey: user ", $Key->user_id, " not found"
			unless $self->{user}->exists($Key->user_id);
	}
	
	eval {
		return $self->{key}->add($Key);
	};
	if (my $ex = caught WeBWorK::DB::Schema::Exception::RecordExists) {
		croak "addKey: key exists (perhaps you meant to use putKey?)";
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
	if (my $ex = caught WeBWorK::DB::Schema::Exception::RecordExists) {
		croak "addGlobalSet: global set exists (perhaps you meant to use putGlobalSet?)";
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
	return $self->{set}->delete($setID);
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
	if (my $ex = caught WeBWorK::DB::Schema::Exception::RecordExists) {
		croak "addUserSet: user set exists (perhaps you meant to use putUserSet?)";
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
	if (my $ex = caught WeBWorK::DB::Schema::Exception::RecordExists) {
		croak "addGlobalProblem: global problem exists (perhaps you meant to use putGlobalProblem?)";
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

	# gateway: we need to check for the existence of the problem with
	# the non-versioned set_id (this should probably do something with
	# grok_vsetID, but I don't think that does both versioned and
	# unversioned set IDs)
	my $nv_set_id = ( $UserProblem->set_id =~ /(.+),v\d+$/ ) ? $1 : 
		$UserProblem->set_id;
	croak "addUserProblem: problem ", $UserProblem->problem_id, " in set $nv_set_id not found"
		unless $self->{problem}->exists($nv_set_id, $UserProblem->problem_id);
	
	eval {
		return $self->{problem_user}->add($UserProblem);
	};
	if (my $ex = caught WeBWorK::DB::Schema::Exception::RecordExists) {
		croak "addUserProblem: user problem exists (perhaps you meant to use putUserProblem?)";
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
# versioned set_user functions (OLD)
################################################################################

# USED NOWHERE
sub countUserSetVersions {
	croak "listUserSetVersions deprecated in favor of countSetVersionsWhere([user_id_eq=>\$userID])";
}

# USED IN Grades.pm, ProblemSets.pm
sub listUserSetVersions {
	croak "listUserSetVersions deprecated in favor of listSetVersionsWhere([user_id_eq=>\$userID])";
}

# USED IN GatewayQuiz.pm
sub getUserSetVersions {
	croak "getUserSetVersions deprecated in favor of getSetVersionsWhere([user_id_eq_set_id_eq_version_id_le => \$userID,\$setID,\$versionID])";
}

# USED IN Instructor.pm
sub addVersionedUserSet {
	croak "addVersionedUserSet deprecated in favor of addSetVersion";
}

# USED IN GatewayQuiz.pm, LoginProctor.pm
sub putVersionedUserSet {
	croak "putVersionedUserSet deprecated in favor of putSetVersion";
}

# USED IN GatewayQuiz.pm, Scoring.pm, StudentProgress.pm, Instructor.pm
# in:  uid and sid are user and set ids.  the setID is the 'global' setID
#	   for the user, not a versioned value
# out: the latest version number of the set that has been assigned to the
#	   user is returned.
sub getUserSetVersionNumber {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);
	# FIXME passing a literal SQL expression into SQL::Abstract prevents fieldoverride translation
	# from occuring!
	# FIXME the whole idea of constructing SQL here is evil and corrupt! fortunately, this will
	# go away once we move versioned sets into their own table, which is hopefully going to happen
	# before we want to support other RDBMSs.
	my $field = "IFNULL(MAX(" . grok_versionID_from_vsetID_sql("set_id") . "),0)";
	my $where = [user_id_eq_set_id_eq => $userID,$setID];
	return ( $self->{set_version}->get_fields_where($field, $where) )[0]->[0];
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
# this returns a list of array refs, which is non-intuitive?  let's try the 
# second version, which returns a list of version_ids
#		return grep { @$_ } $self->{set_version}->get_fields_where(["version_id"], $where);

		return map { @$_ } grep { @$_ } $self->{set_version}->get_fields_where(["version_id"], $where, $order );
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
	if (my $ex = caught WeBWorK::DB::Schema::Exception::RecordExists) {
		croak "addSetVersion: set version exists (perhaps you meant to use putSetVersion?)";
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
# for consistency, we should name this "listProblemVersions", but that is
# confusing, as that sounds as if we're listing the versions of a problem.
# however, that's nonsensical, so we appropriate it here and don't worry
# about the confusion.
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
	return $self->{problem_version_merged}->get_records_where($where);
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
	if (my $ex = caught WeBWorK::DB::Schema::Exception::RecordExists) {
		croak "addProblemVersion: problem version exists (perhaps you meant to use putProblemVersion?)";
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
# versioned set_merged functions (OLD)
################################################################################

# getMergedVersionedSet( self, uid, sid [, versionNum] )
#	 in:  userID uid, setID sid, and optionally version number versionNum
#	 out: the merged set version for the user; if versionNum is specified,
#		  return that set version and otherwise the latest version.	 if 
#		  no versioned set exists for the user, return undef.
#	 note that sid can be setid,vN, thereby specifying the version number
#	   explicitly.	if this is the case, any specified versionNum is ignored
# we'd like to use getMergedSet to do the dirty work here, but that runs 
#	 into problems because we want to merge with both the template set
#	 (that is, the userSet setID) and the global set 
sub getMergedVersionedSet {
	my ($self, $userID, $setID, $versionID) = shift->checkArgs(\@_, qw/user_id set_id version_id!?/);
	
	# get version ID from $setID if $setID includes the version ID
	# otherwise, use the explicit $versionID if given, or get the latest version
	my ($using_setID, $using_versionID, $using_vsetID);
	my ($grokked_setID, $grokked_versionID) = grok_vsetID($setID);
	if ($grokked_versionID) {
		# setID was versioned
		$using_setID = $grokked_setID;
		$using_versionID = $grokked_versionID;
		$using_vsetID = $setID;
	} else {
		# setID was not versioned
		$using_setID = $setID;
		$using_versionID = $versionID || $self->getUserSetVersionNumber($userID, $setID);
		$using_vsetID = make_vsetID($using_setID, $using_versionID);
	}
	
	return ( $self->getMergedVersionedSets([$userID, $using_setID, $using_vsetID]) )[0];
}

sub getMergedVersionedSets {
	my ($self, @userSetIDs) = shift->checkArgsRefList(\@_, qw/user_id set_id vset_id/);

	# these are [user_id, set_id] pairs
	my @nonversionedUserSetIDs = map { [$_->[0], $_->[1]] } @userSetIDs;
	
	# these are [user_id, versioned_set_id] pairs
	my @versionedUserSetIDs = map { [$_->[0], $_->[2]] } @userSetIDs;

	# we merge the nonversioned ("template") user sets (user_id, set_id) and
	#	 the global data into the versioned user sets		
	debug("DB: getUserSets start (nonversioned)");
	my @TemplateUserSets = $self->getUserSets(@nonversionedUserSetIDs);
	
	debug("DB: getUserSets start (versioned)");
	# these are the actual user sets that we want to use
	my @versionedUserSets = $self->getUserSets(@versionedUserSetIDs);
	
	debug("DB: pull out set IDs start");
	my @globalSetIDs = map { $_->[1] } @userSetIDs;
	
	debug("DB: getGlobalSets start");
	my @GlobalSets = $self->getGlobalSets(@globalSetIDs);
	
	debug("DB: calc common fields start");
	my %globalSetFields = map { $_ => 1 } $self->newGlobalSet->FIELDS;
	my @commonFields = grep { exists $globalSetFields{$_} } $self->newUserSet->FIELDS;
	
	debug("DB: merge start");
	for (my $i = 0; $i < @TemplateUserSets; $i++) {
		next unless( defined $versionedUserSets[$i] and 
					 (defined $TemplateUserSets[$i] or
					  defined $GlobalSets[$i]) );
		foreach my $field (@commonFields) {
			next if ( defined( $versionedUserSets[$i]->$field ) && 
					  $versionedUserSets[$i]->$field ne '' );
			$versionedUserSets[$i]->$field($GlobalSets[$i]->$field) if 
				(defined($GlobalSets[$i]->$field) && 
				 $GlobalSets[$i]->$field ne '');
			$versionedUserSets[$i]->$field($TemplateUserSets[$i]->$field)
				if (defined($TemplateUserSets[$i]) &&
					defined($TemplateUserSets[$i]->$field) &&
					$TemplateUserSets[$i]->$field ne '');
		}
	}
	debug("DB: merge done!");
		
	return @versionedUserSets;
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
# versioned problem_merged functions (OLD)
################################################################################

# this exists distinct from getMergedProblem only to be able to include the setVersionID
sub getMergedVersionedProblem {
	my ($self, $userID, $setID, $setVersionID, $problemID) = shift->checkArgs(\@_, qw/user_id set_id version_id problem_id/);
	return ( $self->getMergedVersionedProblems([$userID, $setID, $setVersionID, $problemID]) )[0];
}

sub getMergedVersionedProblems {
	my ($self, @userProblemIDs) = shift->checkArgsRefList(\@_, qw/user_id set_id vset_id problem_id/);
	
	debug("DB: getUserProblems start");
	
	# these are triples [user_id, set_id, problem_id]
	my @nonversionedProblemIDs = map {[$_->[0],$_->[1],$_->[3]]} @userProblemIDs;
	
	# these are triples [user_id, versioned_set_id, problem_id]
	my @versionedProblemIDs = map {[$_->[0],$_->[2],$_->[3]]} @userProblemIDs;
	
	# these are the actual user problems for the version
	my @versionUserProblems = $self->getUserProblems(@versionedProblemIDs);
	
	# get global problems (no user_id, set_id = nonversioned set_id) and template
	# problems (user_id, set_id = nonversioned set_id); we merge with both of these,
	# replacing global values with template values and not taking either in the event
	# that the versioned problem already has a value for the field in question
	debug("DB: pull out set/problem IDs start");
	my @globalProblemIDs = map { [ $_->[1], $_->[2] ] } @nonversionedProblemIDs;
	
	debug("DB: getGlobalProblems start");
	my @GlobalProblems = $self->getGlobalProblems( @globalProblemIDs );
	
	debug("DB: getTemplateProblems start");
	my @TemplateProblems = $self->getUserProblems( @nonversionedProblemIDs );
	
	debug("DB: calc common fields start");
	my %globalProblemFields = map { $_ => 1 } $self->newGlobalProblem->FIELDS;
	my @commonFields = grep { exists $globalProblemFields{$_} } $self->newUserProblem->FIELDS;
	
	debug("DB: merge start");
	for (my $i = 0; $i < @versionUserProblems; $i++) {
		my $UserProblem = $versionUserProblems[$i];
		my $GlobalProblem = $GlobalProblems[$i];
		my $TemplateProblem = $TemplateProblems[$i];
		next unless defined $UserProblem and ( defined $GlobalProblem or
											   defined $TemplateProblem );
		foreach my $field (@commonFields) {
			next if defined $UserProblem->$field && $UserProblem->$field ne '';
			$UserProblem->$field($GlobalProblem->$field) 
				if ( defined($GlobalProblem) && defined($GlobalProblem->$field)
					 && $GlobalProblem->$field ne '' );
			$UserProblem->$field($TemplateProblem->$field)
				if ( defined($TemplateProblem) && 
					 defined($TemplateProblem->$field) &&
					 $TemplateProblem->$field ne '' );
		}
	}
	debug("DB: merge done!");
	
	return @versionUserProblems;
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
	return $self->{problem_version_merged}->get_records_where($where);
}

################################################################################
# utilities
################################################################################

# the (optional) second argument to checkKeyfields is to support versioned
# (gateway) sets, which may include commas in certain fields (in particular,
# set names (e.g., setDerivativeGateway,v1) and user names (e.g., 
# username,proctorname)

sub checkKeyfields($;$) {
	my ($Record, $versioned) = @_;
	foreach my $keyfield ($Record->KEYFIELDS) {
		my $value = $Record->$keyfield;
		
		croak "undefined '$keyfield' field"
			unless defined $value;
		croak "empty '$keyfield' field"
			unless $value ne "";
		
		if ($keyfield eq "problem_id") {
			croak "invalid characters in '$keyfield' field: '$value' (valid characters are [0-9])"
				unless $value =~ m/^[0-9]*$/;
		} elsif ($versioned and ($keyfield eq "set_id" or $keyfield eq "user_id")) {
			croak "invalid characters in '$keyfield' field: '$value' (valid characters are [-a-zA-Z0-9_.,])"
				unless $value =~ m/^[-a-zA-Z0-9_.,]*$/;
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
