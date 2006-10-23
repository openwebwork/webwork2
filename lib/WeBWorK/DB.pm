################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB.pm,v 1.83 2006/10/19 17:35:24 sh002i Exp $
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

sub gen_new {
	my ($table) = @_;
	return sub {
		my ($self, @prototype) = @_;
		return $self->{$table}{record}->new(@prototype);
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

BEGIN { *newUser = gen_new("user"); }

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

BEGIN { *newPassword = gen_new("password"); }

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

BEGIN { *newPermissionLevel = gen_new("permission"); }

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

BEGIN { *newKey = gen_new("key"); }

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

BEGIN { *newGlobalSet = gen_new("set"); }

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

# setID can be undefined if being called from this package
sub deleteGlobalSet {
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $setID) = shift->checkArgs(\@_, "set_id$U");
	$self->deleteUserSet(undef, $setID);
	$self->deleteGlobalProblem($setID, undef);
	return $self->{set}->delete($setID);
}

################################################################################
# set_user functions
################################################################################

BEGIN { *newUserSet = gen_new("set_user"); }

sub countSetUsers { return scalar shift->listSetUsers(@_) }

sub listSetUsers {
	my ($self, $setID) = shift->checkArgs(\@_, qw/set_id/);
	my $where = [set_id_eq => $setID];
	if (wantarray) {
		return map { @$_ } $self->{set_user}->get_fields_where(["user_id"], $where);
	} else {
		return $self->{set_user}->count_where({set_id=>$setID});
	}
}

sub countUserSets { return scalar shift->listUserSets(@_) }

sub listUserSets {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	# VERSIONING -- only list non-versioned sets
	my $where = [nonversionedset_user_id_eq => $userID];
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

# userID and setID can be undefined if being called from this package
sub deleteUserSet {
	my $U = caller eq __PACKAGE__ ? "!" : "";
	# VERSIONING - skipVersionDel flag
	my ($self, $userID, $setID, $skipVersionDel) = shift->checkArgs(\@_, "user_id$U", "set_id$U", "skipVersionDel!?");
	# VERSIONING - delete versions for this user set
	if (defined $setID and not $skipVersionDel) {
		$self->deleteUserSetVersions($userID, $setID);
	}
	$self->deleteUserProblem($userID, $setID, undef);
	return $self->{set_user}->delete($userID, $setID);
}

################################################################################
# problem functions
################################################################################

BEGIN { *newGlobalProblem = gen_new("problem"); }

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

# userID and setID can be null if being called from this package
sub deleteGlobalProblem {
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $setID, $problemID) = shift->checkArgs(\@_, "set_id$U", "problem_id$U");
	$self->deleteUserProblem(undef, $setID, $problemID);
	return $self->{problem}->delete($setID, $problemID);
}

################################################################################
# problem_user functions
################################################################################

BEGIN { *newUserProblem = gen_new("problem_user"); }

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
	croak "addUserProblem: problem ", $UserProblem->problem_id, " in set ", $UserProblem->set_id, " not found"
		unless $self->{problem}->exists($UserProblem->set_id, $UserProblem->problem_id);
	
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

# userID, setID, and problemID can be undefined if being called from this package
sub deleteUserProblem {
	my $U = caller eq __PACKAGE__ ? "!" : "";
	my ($self, $userID, $setID, $problemID) = shift->checkArgs(\@_, "user_id$U", "set_id$U", "problem_id$U");
	return $self->{problem_user}->delete($userID, $setID, $problemID);
}

################################################################################
# set+set_user functions
################################################################################

sub existsMergedSet {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);
	return $self->{set_merged}->exists($userID, $setID);
}

sub getMergedSet {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);
	return ( $self->getMergedSets([$userID, $setID]) )[0];
}

# a significant amount of getMergedSets is duplicated in getMergedVersionedSets below
sub getMergedSets_old {
	my ($self, @userSetIDs) = shift->checkArgsRefList(\@_, qw/user_id set_id/);
	
	debug("DB: getUserSets start");
	my @UserSets = $self->getUserSets(@userSetIDs); # checked
	
	debug("DB: pull out set IDs start");
	my @globalSetIDs = map { $_->[1] } @userSetIDs;
	debug("DB: getGlobalSets start");
	my @GlobalSets = $self->getGlobalSets(@globalSetIDs); # checked
	
	debug("DB: calc common fields start");
	my %globalSetFields = map { $_ => 1 } $self->newGlobalSet->FIELDS;
	my @commonFields = grep { exists $globalSetFields{$_} } $self->newUserSet->FIELDS;
	
	debug("DB: merge start");
	for (my $i = 0; $i < @UserSets; $i++) {
		my $UserSet = $UserSets[$i];
		my $GlobalSet = $GlobalSets[$i];
		next unless defined $UserSet and defined $GlobalSet;
		foreach my $field (@commonFields) {
			#next if defined $UserSet->$field;
			# ok, now we're testing for emptiness as well as definedness.
			next if defined $UserSet->$field and $UserSet->$field ne "";
			$UserSet->$field($GlobalSet->$field);
		}
	}
	debug("DB: merge done!");
	
	return @UserSets;
}

sub getMergedSets {
	my ($self, @userSetIDs) = shift->checkArgsRefList(\@_, qw/user_id set_id/);
	return $self->{set_merged}->gets(@userSetIDs);
}

################################################################################
# problem+problem_user functions
################################################################################

sub existsMergedProblem {
	my ($self, $userID, $setID, $problemID) = shift->checkArgs(\@_, qw/user_id set_id problem_id/);
	return $self->{problem_merged}->exists($userID, $setID, $problemID);
}

sub getMergedProblem {
	my ($self, $userID, $setID, $problemID) = shift->checkArgs(\@_, qw/user_id set_id problem_id/);
	return ( $self->getMergedProblems([$userID, $setID, $problemID]) )[0];
}

sub getMergedProblems_old {
	my ($self, @userProblemIDs) = shift->checkArgsRefList(\@_, qw/user_id set_id problem_id/);
	
	debug("DB: getUserProblems start");
	my @UserProblems = $self->getUserProblems(@userProblemIDs); # checked
	
	debug("DB: pull out set/problem IDs start");
	my @globalProblemIDs = map { [ $_->[1], $_->[2] ] } @userProblemIDs;
	debug("DB: getGlobalProblems start");
	my @GlobalProblems = $self->getGlobalProblems(@globalProblemIDs); # checked
	
	debug("DB: calc common fields start");
	my %globalProblemFields = map { $_ => 1 } $self->newGlobalProblem->FIELDS;
	my @commonFields = grep { exists $globalProblemFields{$_} } $self->newUserProblem->FIELDS;
	
	debug("DB: merge start");
	for (my $i = 0; $i < @UserProblems; $i++) {
		my $UserProblem = $UserProblems[$i];
		my $GlobalProblem = $GlobalProblems[$i];
		next unless defined $UserProblem and defined $GlobalProblem;
		foreach my $field (@commonFields) {
			# FIXME: we currently promote undef to "" in SQL.pm, so we need to override on
			# empty strings as well as undefined values.
			next if defined $UserProblem->$field and $UserProblem->$field ne "";
			$UserProblem->$field($GlobalProblem->$field);
		}
	}
	debug("DB: merge done!");
	
	return @UserProblems;
}

sub getMergedProblems {
	my ($self, @userProblemIDs) = shift->checkArgsRefList(\@_, qw/user_id set_id problem_id/);
	return $self->{problem_merged}->gets(@userProblemIDs);
}

sub getAllMergedUserProblems_old {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);
	my $where = [user_id_eq_set_id_eq => $userID,$setID];
	my @userProblemIDs = $self->{problem_user}->get_fields_where([qw/user_id set_id problem_id/],
		$where);
	return $self->getMergedProblems(@userProblemIDs);
}

sub getAllMergedUserProblems {
	my ($self, $userID, $setID) = shift->checkArgs(\@_, qw/user_id set_id/);
	my $where = [user_id_eq_set_id_eq => $userID,$setID];
	return $self->{problem_merged}->get_records_where($where);
}

################################################################################
# versioned set_user functions
################################################################################

sub countUserSetVersions { return scalar shift->listUserSetVersions(@_) }

sub listUserSetVersions {
	my ($self, $userID) = shift->checkArgs(\@_, qw/user_id/);
	my $where = [versionedset_user_id_eq => $userID];
	if (wantarray) {
		return map { @$_ } $self->{set_user}->get_fields_where(["set_id"], $where);
	} else {
		return $self->{set_user}->count_where($where);
	}
}

# in:  $uid is a userID, $sid is a setID, and $versionNum is a version number
#	   userID has set versions 1 through $versionNum defined
# out: an array of user set objects is returned for the indicated version 
#	   numbers
sub getUserSetVersions {
	my ($self, $userID, $setID, $versionID) = shift->checkArgs(\@_, qw/user_id set_id version_id/);
	my $where = [versionedset_user_id_eq_set_id_eq_version_id_le => $userID,$setID,$versionID];
	# FIXME this is a literal order clause, which defeats field translation
	my $order = \(grok_versionID_from_vsetID_sql('set_id'));
	return $self->{set_user}->get_records_where($where, $order);
}

sub addVersionedUserSet {
	my ($self, $UserSet) = shift->checkArgs(\@_, qw/VREC:set_user/);
	my ($setID, undef) = grok_vsetID($UserSet->set_id);
		
	croak "addUserSet: user ", $UserSet->user_id, " not found"
		unless $self->{user}->exists($UserSet->user_id);
	croak "addVersionedUserSet: set $setID not found"
		unless $self->{set}->exists($setID);
	
	eval {
		return $self->{set_user}->add($UserSet);
	};
	if (my $ex = caught WeBWorK::DB::Schema::Exception::RecordExists) {
		croak "addVersionedUserSet: versioned user set exists (perhaps you meant to use putVersionedUserSet?)";
	}
}

# this exists separate from putUserSet only so that we can make it harder
# for anyone else to use commas in setIDs
sub putVersionedUserSet {
	my ($self, $UserSet) = shift->checkArgs(\@_, qw/VSET:set_user/);
	my $rows = $self->{set_user}->put($UserSet); # DBI returns 0E0 for 0.
	if ($rows == 0) {
		croak "putVersionedUserSet: user set not found (perhaps you meant to use putVersionedUserSet?)";
	} else {
		return $rows;
	}
}

sub deleteUserSetVersions {
	my ($self, $userID, $setID) = @_;

# this only gets called from deleteUserSet, so we don't worry about $setID
#	 not being defined 

# make a list of all users to delete set versions for.	if we have a userID, 
#	 then just delete versions for that user
	my @allUsers = ();
	if ( defined( $userID ) ) {
		push( @allUsers, $userID );
	} else {
# otherwise, get a list of all users to whom the set is assigned, and delete
#	 all versions for all of them
		@allUsers = $self->listSetUsers( $setID );
	}

# skip version deletion when calling deleteUserSet from here
	my $skipVersionDel = 1;

# go through each userID and delete all versions of the set for each
	foreach my $uid ( @allUsers ) {
		my $setVersionNumber = $self->getUserSetVersionNumber($uid, $setID);
		if ( $setVersionNumber ) {
			for ( my $i=1; $i<=$setVersionNumber; $i++ ) {
				eval { $self->deleteUserSet( $uid, "$setID,v$i",
											 $skipVersionDel ) };
				return $@ if ( $@ );
			}
		}
	}
}

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
	my $where = [versionedset_user_id_eq_set_id_eq => $userID,$setID];
	return ( $self->{set_user}->get_fields_where($field, $where) )[0]->[0];
}

# a useful expression:
# 
# select user_id,substring(set_id,1,instr(set_id,',v')-1) as set_id,
# substring(set_id,instr(set_id,',v')+2) as version_id from sam_course_set_user
# where set_id like '%,v%';

################################################################################
# versioned set+set_user functions
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
		$using_versionID = $versionID || $self->getUserSetVersionNumver($userID, $setID);
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
# versioned problem+problem_user functions
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
