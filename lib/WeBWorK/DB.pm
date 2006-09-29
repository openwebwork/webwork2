################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB.pm,v 1.77 2006/09/29 16:49:47 sh002i Exp $
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

sub new($$) {
	my ($invocant, $dbLayout) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {};
	bless $self, $class; # bless this here so we can pass it to the schema
	
	# load the modules required to handle each table, and create driver
	my %dbLayout = %$dbLayout;
	foreach my $table (keys %dbLayout) {
		my $layout = $dbLayout{$table};
		my $record = $layout->{record};
		my $schema = $layout->{schema};
		my $driver = $layout->{driver};
		my $source = $layout->{source};
		my $params = $layout->{params};
		
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
	
	return $self;
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
# moodle functions
################################################################################

sub getMoodleSession {
	my ($self, $key) = @_;
	return $self->{moodlekey}->get($key);
}

sub extendMoodleSession {
	my ($self, $key) = @_;
	return $self->{moodlekey}->extend($key);
}

################################################################################
# create/rename/delete tables
################################################################################

sub create_tables {
	my ($self) = @_;
	
	foreach my $table (keys %$self) {
		next if $table =~ /^_/; # skip non-table self fields (none yet)
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
# password functions
################################################################################

BEGIN { *newPassword = gen_new("password"); }

sub listPasswords {
	my ($self) = @_;
	
	croak "listPasswords: requires 0 arguments"
		unless @_ == 1;
	
	return map { $_->[0] }
		$self->{password}->list(undef);
}

sub addPassword {
	my ($self, $Password) = @_;
	
	croak "addPassword: requires 1 argument"
		unless @_ == 2;
	croak "addPassword: argument 1 must be of type ", $self->{password}->{record}
		unless ref $Password eq $self->{password}->{record};
	
	checkKeyfields($Password);
	
	croak "addPassword: password exists (perhaps you meant to use putPassword?)"
		if $self->{password}->exists($Password->user_id);
	croak "addPassword: user ", $Password->user_id, " not found"
		unless $self->{user}->exists($Password->user_id);
	
	return $self->{password}->add($Password);
}

sub getPassword {
	my ($self, $userID) = @_;
	
	croak "getPassword: requires 1 argument"
		unless @_ == 2;
	croak "getPassword: argument 1 must contain a user_id"
		unless defined $userID;
	
	#return $self->{password}->get($userID);
	return ( $self->getPasswords($userID) )[0];
}

sub getPasswords {
	my ($self, @userIDs) = @_;
	
	#croak "getPasswords: requires 1 or more argument"
	#	unless @_ >= 2;
	foreach my $i (0 .. $#userIDs) {
		croak "getPasswords: element $i of argument list must contain a user_id"
			unless defined $userIDs[$i];
	}
	
	my @Passwords = $self->{password}->gets(map { [$_] } @userIDs);
	
	for (my $i = 0; $i < @Passwords; $i++) {
		my $Password = $Passwords[$i];
		my $userID = $userIDs[$i];
		if (not defined $Password) {
			if ($self->{user}->exists($userID)) {
				$Password = $self->newPassword(user_id => $userID);
				eval { $self->addPassword($Password) };
				if ($@ and $@ !~ m/password exists/) {
					die "error while auto-creating password record for user $userID: \"$@\"";
				}
			}
		}
	}
	
	return @Passwords;
}

sub putPassword($$) {
	my ($self, $Password) = @_;
	
	croak "putPassword: requires 1 argument"
		unless @_ == 2;
	croak "putPassword: argument 1 must be of type ", $self->{password}->{record}
		unless ref $Password eq $self->{password}->{record};
	
	checkKeyfields($Password);
	
	# For Passwords and PermissionLevels, auto-create a record when it doesn't
	# already exist. This should be safe.
	if ($self->{password}->exists($Password->user_id)) {
		return $self->{password}->put($Password);
	} else {
		return $self->addPassword($Password);
	}
}

sub deletePassword($$) {
	my ($self, $userID) = @_;
	
	croak "putPassword: requires 1 argument"
		unless @_ == 2;
	croak "deletePassword: argument 1 must contain a user_id"
		unless defined $userID;
	
	return $self->{password}->delete($userID);
}

################################################################################
# permission functions
################################################################################

BEGIN { *newPermissionLevel = gen_new("permission"); }

sub listPermissionLevels($) {
	my ($self) = @_;
	
	croak "listPermissionLevels: requires 0 arguments"
		unless @_ == 1;
	
	return map { $_->[0] }
		$self->{permission}->list(undef);
}

sub addPermissionLevel($$) {
	my ($self, $PermissionLevel) = @_;
	
	croak "addPermissionLevel: requires 1 argument"
		unless @_ == 2;
	croak "addPermissionLevel: argument 1 must be of type ", $self->{permission}->{record}
		unless ref $PermissionLevel eq $self->{permission}->{record};
	
	checkKeyfields($PermissionLevel);
	
	croak "addPermissionLevel: permission level exists (perhaps you meant to use putPermissionLevel?)"
		if $self->{permission}->exists($PermissionLevel->user_id);
	croak "addPermissionLevel: user ", $PermissionLevel->user_id, " not found"
		unless $self->{user}->exists($PermissionLevel->user_id);
	
	return $self->{permission}->add($PermissionLevel);
}

sub getPermissionLevel($$) {
	my ($self, $userID) = @_;
	
	croak "getPermissionLevel: requires 1 argument"
		unless @_ == 2;
	croak "getPermissionLevel: argument 1 must contain a user_id"
		unless defined $userID;
	
	#return $self->{permission}->get($userID);
	return ( $self->getPermissionLevels($userID) )[0];
}

sub getPermissionLevels {
	my ($self, @userIDs) = @_;
	
	#croak "getPermissionLevels: requires 1 or more argument"
	#	unless @_ >= 2;
	foreach my $i (0 .. $#userIDs) {
		croak "getPermissionLevels: element $i of argument list must contain a user_id"
			unless defined $userIDs[$i];
	}
	
	my @PermissionLevels = $self->{permission}->gets(map { [$_] } @userIDs);
	
	for (my $i = 0; $i < @PermissionLevels; $i++) {
		my $PermissionLevel = $PermissionLevels[$i];
		my $userID = $userIDs[$i];
		if (not defined $PermissionLevel) {
			if ($self->{user}->exists($userID)) {
				$PermissionLevel = $self->newPermissionLevel(user_id => $userID);
				eval { $self->addPermissionLevel($PermissionLevel) };
				if ($@ and $@ !~ m/permission level exists/) {
					die "error while auto-creating permission level record for user $userID: \"$@\"";
				}
				$PermissionLevels[$i] = $PermissionLevel;
			}
		}
	}
	
	return @PermissionLevels;
}

sub putPermissionLevel($$) {
	my ($self, $PermissionLevel) = @_;
	
	croak "putPermissionLevel: requires 1 argument"
		unless @_ == 2;
	croak "putPermissionLevel: argument 1 must be of type ", $self->{permission}->{record}
		unless ref $PermissionLevel eq $self->{permission}->{record};
	
	checkKeyfields($PermissionLevel);
	
	# For Passwords and PermissionLevels, auto-create a record when it doesn't
	# already exist. This should be safe.
	if ($self->{permission}->exists($PermissionLevel->user_id)) {
		return $self->{permission}->put($PermissionLevel);
	} else {
		return $self->{permission}->add($PermissionLevel);
	}
}

sub deletePermissionLevel($$) {
	my ($self, $userID) = @_;
	
	croak "deletePermissionLevel: requires 1 argument"
		unless @_ == 2;
	croak "deletePermissionLevel: argument 1 must contain a user_id"
		unless defined $userID;
	
	return $self->{permission}->delete($userID);
}

################################################################################
# key functions
################################################################################

BEGIN { *newKey = gen_new("key"); }

sub listKeys($) {
	my ($self) = @_;
	
	croak "listKeys: requires 0 arguments"
		unless @_ == 1;
	
	return map { $_->[0] }
		$self->{key}->list(undef);
}

sub addKey($$) {
	my ($self, $Key) = @_;
	
	croak "addKey: requires 1 argument"
		unless @_ == 2;
	croak "addKey: argument 1 must be of type ", $self->{key}->{record}
		unless ref $Key eq $self->{key}->{record};
	
	checkKeyfields($Key, 1); # 1 flags that we can have a comma
	
	croak "addKey: key exists (perhaps you meant to use putKey?)"
		if $self->{key}->exists($Key->user_id);
	if ( $Key->user_id !~ /,/ ) {
	    croak "addKey: user ", $Key->user_id, " not found"
		unless $self->{user}->exists($Key->user_id);
	} else {
	    my ( $userID, $proctorID ) = split(/,/, $Key->user_id);
	    croak "addKey: user $userID not found"
		unless $self->{user}->exists($userID);
	    croak "addKey: proctor $proctorID not found"
		unless $self->{user}->exists($proctorID);
	}
	
	return $self->{key}->add($Key);
}

sub getKey($$) {
	my ($self, $userID) = @_;
	
	croak "getKey: requires 1 argument"
		unless @_ == 2;
	croak "getKey: argument 1 must contain a user_id"
		unless defined $userID;
	
	return $self->{key}->get($userID);
}

sub getKeys {
	my ($self, @userIDs) = @_;
	
	#croak "getKeys: requires 1 or more argument"
	#	unless @_ >= 2;
	foreach my $i (0 .. $#userIDs) {
		croak "getKeys: element $i of argument list must contain a user_id"
			unless defined $userIDs[$i];
	}
	
	return $self->{key}->gets(map { [$_] } @userIDs);
}

sub putKey($$) {
	my ($self, $Key) = @_;
	
	croak "putKey: requires 1 argument"
		unless @_ == 2;
	croak "putKey: argument 1 must be of type ", $self->{key}->{record}
		unless ref $Key eq $self->{key}->{record};
	
	checkKeyfields($Key, 1);  # 1 allows commas for versioned sets
	
	croak "putKey: key not found (perhaps you meant to use addKey?)"
		unless $self->{key}->exists($Key->user_id);
	
	return $self->{key}->put($Key);
}

sub deleteKey($$) {
	my ($self, $userID) = @_;
	
	croak "deleteKey: requires 1 argument"
		unless @_ == 2;
	croak "deleteKey: argument 1 must contain a user_id"
		unless defined $userID;
	
	return $self->{key}->delete($userID);
}

################################################################################
# user functions
################################################################################

BEGIN { *newUser = gen_new("user"); }

sub listUsers {
	my ($self) = @_;
	
	croak "listUsers: requires 0 arguments"
		unless @_ == 1;
	
	return map { $_->[0] }
		$self->{user}->list(undef);
}

sub addUser {
	my ($self, $User) = @_;
	
	croak "addUser: requires 1 argument"
		unless @_ == 2;
	croak "addUser: argument 1 must be of type ", $self->{user}->{record}
		unless ref $User eq $self->{user}->{record};
	
	checkKeyfields($User);
	
	croak "addUser: user exists (perhaps you meant to use putUser?)"
		if $self->{user}->exists($User->user_id);
	
	return $self->{user}->add($User);
}

sub getUser {
	my ($self, $userID) = @_;
	
	croak "getUser: requires 1 argument"
		unless @_ == 2;
	croak "getUser: argument 1 must contain a user_id"
		unless defined $userID;
	
	return $self->{user}->get($userID);
}

sub getUsers {
	my ($self, @userIDs) = @_;
	
	#croak "getUsers: requires 1 or more argument"
	#	unless @_ >= 2;
	foreach my $i (0 .. $#userIDs) {
		croak "getUsers: element $i of argument list must contain a user_id"
			unless defined $userIDs[$i];
	}
	
	return $self->{user}->gets(map { [$_] } @userIDs);
}

sub putUser {
	my ($self, $User) = @_;
	
	croak "putUser: requires 1 argument"
		unless @_ == 2;
	croak "putUser: argument 1 must be of type ", $self->{user}->{record}
		unless ref $User eq $self->{user}->{record};
	
	checkKeyfields($User);
	
	croak "putUser: user not found (perhaps you meant to use addUser?)"
		unless $self->{user}->exists($User->user_id);
	
	return $self->{user}->put($User);
}

sub deleteUser {
	my ($self, $userID) = @_;
	
	croak "deleteUser: requires 1 argument"
		unless @_ == 2;
	croak "deleteUser: argument 1 must contain a user_id"
		unless defined $userID;
	
	$self->deleteUserSet($userID, undef);
	$self->deletePassword($userID);
	$self->deletePermissionLevel($userID);
	$self->deleteKey($userID);
	return $self->{user}->delete($userID);
}

################################################################################
# set functions
################################################################################

BEGIN { *newGlobalSet = gen_new("set"); }

sub listGlobalSets {
	my ($self) = @_;
	
	croak "listGlobalSets: requires 0 arguments"
		unless @_ == 1;
	
	return map { $_->[0] }
		$self->{set}->list(undef);
}

sub addGlobalSet {
	my ($self, $GlobalSet) = @_;
	
	croak "addGlobalSet: requires 1 argument"
		unless @_ == 2;
	croak "addGlobalSet: argument 1 must be of type ", $self->{set}->{record}
		unless ref $GlobalSet eq $self->{set}->{record};
	
	checkKeyfields($GlobalSet);
	
	croak "addGlobalSet: global set exists (perhaps you meant to use putGlobalSet?)"
		if $self->{set}->exists($GlobalSet->set_id);
	
	return $self->{set}->add($GlobalSet);
}

sub getGlobalSet {
	my ($self, $setID) = @_;
	
	croak "getGlobalSet: requires 1 argument"
		unless @_ == 2;
	croak "getGlobalSet: argument 1 must contain a set_id"
		unless defined $setID;
	
	return $self->{set}->get($setID);
}

sub getGlobalSets {
	my ($self, @setIDs) = @_;
	
	#croak "getGlobalSets: requires 1 or more argument"
	#	unless @_ >= 2;
	foreach my $i (0 .. $#setIDs) {
		croak "getGlobalSets: element $i of argument list must contain a set_id"
			unless defined $setIDs[$i];
	}
	
	return $self->{set}->gets(map { [$_] } @setIDs);
}

sub putGlobalSet {
	my ($self, $GlobalSet) = @_;
	
	croak "putGlobalSet: requires 1 argument"
		unless @_ == 2;
	croak "putGlobalSet: argument 1 must be of type ", $self->{set}->{record}
		unless ref $GlobalSet eq $self->{set}->{record};
	
	checkKeyfields($GlobalSet);
	
	croak "putGlobalSet: global set not found (perhaps you meant to use addGlobalSet?)"
		unless $self->{set}->exists($GlobalSet->set_id);
	
	return $self->{set}->put($GlobalSet);
}

sub deleteGlobalSet {
	my ($self, $setID) = @_;
	
	croak "deleteGlobalSet: requires 1 argument"
		unless @_ == 2;
	croak "deleteGlobalSet: argument 1 must contain a set_id"
		unless defined $setID or caller eq __PACKAGE__;
	
	$self->deleteUserSet(undef, $setID);
	$self->deleteGlobalProblem($setID, undef);
	return $self->{set}->delete($setID);
}

################################################################################
# set_user functions
################################################################################

BEGIN { *newUserSet = gen_new("set_user"); }

sub countSetUsers {
	my ($self, $setID) = @_;
	
	croak "countSetUsers: requires 1 argument"
		unless @_ == 2;
	croak "countSetUsers: argument 1 must contain a set_id"
		unless defined $setID;
	
	# inefficient way
	#return scalar $self->{set_user}->list(undef, $setID);
	
	# efficient way
	return $self->{set_user}->count(undef, $setID);
}

sub listSetUsers {
	my ($self, $setID) = @_;
	
	carp "listSetUsers called in SCALAR context: use countSetUsers instead!\n"
		unless wantarray;
	
	croak "listSetUsers: requires 1 argument"
		unless @_ == 2;
	croak "listSetUsers: argument 1 must contain a set_id"
		unless defined $setID;
	
	return map { $_->[0] } # extract user_id
		$self->{set_user}->list(undef, $setID);
}

sub countUserSets {
	my ($self, $userID) = @_;
	
	croak "countUserSets: requires 1 argument"
		unless @_ == 2;
	croak "countUserSets: argument 1 must contain a user_id"
		unless defined $userID;
		
# don't count versioned sets.  I think this is the correct behavior...
	my $n = $self->{set_user}->count($userID, undef);
	my $nv = $self->countUserSetVersions($userID);
	return $n - $nv;
}

sub countUserSetVersions {
# return the total number of versioned sets associated with the user
	my ($self, $userID) = @_;
	
	croak "countUserSetVersions: requires 1 argument"
		unless @_ == 2;
	croak "countUserSetVersions: argument 1 must contain a user_id"
		unless defined $userID;

	my @versionedSetList = $self->listUserSetVersions($userID);
	return scalar(@versionedSetList);
}

sub listUserSets {
	my ($self, $userID) = @_;
	
	croak "listUserSets: requires 1 argument"
		unless @_ == 2;
	croak "listUserSets: argument 1 must contain a user_id"
		unless defined $userID;
	
    # the following specifically excludes versioned sets, so that 
    # this behaves as non-gateway code expects
	return( grep !/,v\d+$/, ( map { $_->[1] } # extract set_id
				  $self->{set_user}->list($userID, undef) ) );
}

sub listUserSetVersions {
	my ($self, $userID) = @_;
	
	croak "listUserSetVersions: requires 1 argument"
		unless @_ == 2;
	croak "listUserSetVersions: argument 1 must contain a user_id"
		unless defined $userID;
	
	return( grep /,v\d+$/, ( map { $_->[1] } # extract set_id
				$self->{set_user}->list($userID, undef) ) );
}

# the code from addUserSet() is duplicated in large part following in 
# addVersionedUserSet; changes here should accordingly be propagated down there

sub addUserSet {
	my ($self, $UserSet) = @_;
	
	croak "addUserSet: requires 1 argument"
		unless @_ == 2;
	croak "addUserSet: argument 1 must be of type ", $self->{set_user}->{record}
		unless ref $UserSet eq $self->{set_user}->{record};
	
	checkKeyfields($UserSet);
	
	croak "addUserSet: user set exists (perhaps you meant to use putUserSet?)"
		if $self->{set_user}->exists($UserSet->user_id, $UserSet->set_id);
	croak "addUserSet: user ", $UserSet->user_id, " not found"
		unless $self->{user}->exists($UserSet->user_id);
	croak "addUserSet: set ", $UserSet->set_id, " not found"
		unless $self->{set}->exists($UserSet->set_id);
	
	return $self->{set_user}->add($UserSet);
}

sub addVersionedUserSet {
    my ($self, $UserSet) = @_;

# this is the same as addUserSet,allowing for set names of the form setID,vN
	
    croak "addVersionedUserSet: requires 1 argument"
	unless @_ == 2;
    croak "addVersionedUserSet: argument 1 must be of type ", 
        $self->{set_user}->{record} 
	unless ref $UserSet eq $self->{set_user}->{record};
	
# $versioned is a flag that we send in to allow commas in the set name 
#    for versioned sets
    my $versioned = 1;
    checkKeyfields($UserSet, $versioned);
    my ($nonVersionedSetName) = ($UserSet->set_id =~ /^(.*),v\d+$/);
	
    croak "addUserSet: user set exists (perhaps you meant to use putUserSet?)"
	if $self->{set_user}->exists($UserSet->user_id, $UserSet->set_id);
    croak "addUserSet: user ", $UserSet->user_id, " not found"
	unless $self->{user}->exists($UserSet->user_id);
#	croak "addUserSet: set ", $UserSet->set_id, " not found"
#		unless $self->{set}->exists($UserSet->set_id);
# here the appropriate check is whether a global set of the nonversioned set
#    name exists
    croak "addVersionedUserSet: set ", $nonVersionedSetName, " not found"
	unless $self->{set}->exists( $nonVersionedSetName );
	
    return $self->{set_user}->add($UserSet);
}

sub getUserSet {
	my ($self, $userID, $setID) = @_;
	
	croak "getUserSet: requires 2 arguments"
		unless @_ == 3;
	croak "getUserSet: argument 1 must contain a user_id"
		unless defined $userID;
	croak "getUserSet: argument 2 must contain a set_id"
		unless defined $setID;
	
	#return $self->{set_user}->get($userID, $setID);
	return ( $self->getUserSets([$userID, $setID]) )[0];
}

sub getUserSets {
	my ($self, @userSetIDs) = @_;
	
	#croak "getUserSets: requires 1 or more argument"
	#	unless @_ >= 2;
	foreach my $i (0 .. $#userSetIDs) {
		croak "getUserSets: element $i of argument list must contain a <user_id, set_id> pair"
			unless defined $userSetIDs[$i]
			       and ref $userSetIDs[$i] eq "ARRAY"
			       and @{$userSetIDs[$i]} == 2
			       and defined $userSetIDs[$i]->[0]
			       and defined $userSetIDs[$i]->[1];
	}
	
	return $self->{set_user}->gets(@userSetIDs);
}

sub getUserSetVersions {
    my ( $self, $uid, $sid, $versionNum ) = @_;
# in:  $uid is a userID, $sid is a setID, and $versionNum is a version number
#      userID has set versions 1 through $versionNum defined
# out: an array of user set objects is returned for the indicated version 
#      numbers

    croak "getUserSetVersions: requires three arguments, userID, setID, and " .
	"versionNum" if ( @_ < 3 );

    my @userSetIDs = ();
    foreach my $i ( 1 .. $versionNum ) {
	push( @userSetIDs, [ $uid, "$sid,v$i" ] );
    }

    return $self->getUserSets( @userSetIDs );
}

# the code from putUserSet() is duplicated in large part in the following
# putVersionedUserSet; c.f. that routine

sub putUserSet {
	my ($self, $UserSet) = @_;
	
	croak "putUserSet: requires 1 argument"
		unless @_ == 2;
	croak "putUserSet: argument 1 must be of type ", $self->{set_user}->{record}
		unless ref $UserSet eq $self->{set_user}->{record};
	
	checkKeyfields($UserSet);
	
	croak "putUserSet: user set not found (perhaps you meant to use addUserSet?)"
		unless $self->{set_user}->exists($UserSet->user_id, $UserSet->set_id);
	croak "putUserSet: user ", $UserSet->user_id, " not found"
		unless $self->{user}->exists($UserSet->user_id);
	croak "putUserSet: set ", $UserSet->set_id, " not found"
		unless $self->{set}->exists($UserSet->set_id);
	
	return $self->{set_user}->put($UserSet);
}

sub putVersionedUserSet {
    my ($self, $UserSet) = @_;
# this exists separate from putUserSet only so that we can make it harder
#   for anyone else to use commas in setIDs
	
    croak "putUserSet: requires 1 argument"
	unless @_ == 2;
    croak "putUserSet: argument 1 must be of type ", $self->{set_user}->{record}
	unless ref $UserSet eq $self->{set_user}->{record};
	
    # versioned allows us to have a wacked out setID
    my $versioned = 1;
    checkKeyfields($UserSet, $versioned);
	
    my $nonVersionedSetID = $UserSet->set_id;
    $nonVersionedSetID =~ s/,v\d+$//;
#    my ($nonVersionedSetID) = ($UserSet->set_id =~ /^(.*)(,v\d+)?$/);
    croak "putVersionedUserSet: user set not found (perhaps you meant " .
        "to use addUserSet?)"
	unless $self->{set_user}->exists($UserSet->user_id, $UserSet->set_id);
    croak "putVersionedUserSet: user ", $UserSet->user_id, " not found"
	unless $self->{user}->exists($UserSet->user_id);
    croak "putVersionedUserSet: set $nonVersionedSetID not found"
	unless $self->{set}->exists($nonVersionedSetID);
	
    return $self->{set_user}->put($UserSet);
}

sub deleteUserSet {
	my ($self, $userID, $setID, $skipVersionDel) = @_;
	
	croak "getUserSet: requires 2 or 3 arguments"
		unless @_ == 3 or @_ == 4;
	croak "getUserSet: argument 1 must contain a user_id"
		unless defined $userID or caller eq __PACKAGE__;
	croak "getUserSet: argument 2 must contain a set_id"
		unless defined $userID or caller eq __PACKAGE__;
	
	$self->deleteUserSetVersions( $userID, $setID ) 
	    if ( defined($setID) && ! ( defined($skipVersionDel) && 
		 $skipVersionDel ) );
	$self->deleteUserProblem($userID, $setID, undef);
	return $self->{set_user}->delete($userID, $setID);
}

sub deleteUserSetVersions {
    my ($self, $userID, $setID) = @_;

# this only gets called from deleteUserSet, so we don't worry about $setID
#    not being defined 

# make a list of all users to delete set versions for.  if we have a userID, 
#    then just delete versions for that user
    my @allUsers = ();
    if ( defined( $userID ) ) {
	push( @allUsers, $userID );
    } else {
# otherwise, get a list of all users to whom the set is assigned, and delete
#    all versions for all of them
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

sub getUserSetVersionNumber {
    my ( $self, $uid, $sid ) = @_;
# in:  uid and sid are user and set ids.  the setID is the 'global' setID
#      for the user, not a versioned value
# out: the latest version number of the set that has been assigned to the
#      user is returned.

    croak "getUserSetVersionNumber: requires 2 arguments, a user and set ID"
	unless @_ == 3 && defined $uid && defined $sid;

# we just get all sets for the user and figure out which of them 
#    look like the sid.
    my @allSetIDs = $self->listUserSetVersions( $uid );
    my @setIDs = sort( grep { /^$sid,v\d+$/ } @allSetIDs );
    my $lastSetID = $setIDs[-1];
# I think this should be defined, unless the set hasn't been assigned to 
#    the user at all, which we hope wouldn't have happened at this juncture
    if ( not defined($lastSetID) ) {
	return 0;
    } else {
  # we have to deal with the fact that 10 sorts to precede 2 (etc.)
	my @vNums = map { /^$sid,v(\d+)$/ } @setIDs;
	return ( ( sort {$a<=>$b} @vNums )[-1] );
    }
}

################################################################################
# problem functions
################################################################################

BEGIN { *newGlobalProblem = gen_new("problem"); }

sub listGlobalProblems {
	my ($self, $setID) = @_;
	
	croak "listGlobalProblems: requires 1 arguments"
		unless @_ == 2;
	croak "listGlobalProblems: argument 1 must contain a set_id"
		unless defined $setID;
	
	return map { $_->[1] }
		$self->{problem}->list($setID, undef);
}

sub addGlobalProblem {
	my ($self, $GlobalProblem) = @_;
	
	croak "addGlobalProblem: requires 1 argument"
		unless @_ == 2;
	croak "addGlobalProblem: argument 1 must be of type ", $self->{problem}->{record}
		unless ref $GlobalProblem eq $self->{problem}->{record};
	
	checkKeyfields($GlobalProblem);
	
	croak "addGlobalProblem: global problem exists (perhaps you meant to use putGlobalProblem?)"
		if $self->{problem}->exists($GlobalProblem->set_id, $GlobalProblem->problem_id);
	croak "addGlobalProblem: set ", $GlobalProblem->set_id, " not found"
		unless $self->{set}->exists($GlobalProblem->set_id);
	
	return $self->{problem}->add($GlobalProblem);
}

sub getGlobalProblem {
	my ($self, $setID, $problemID) = @_;
	
	croak "getGlobalProblem: requires 2 arguments"
		unless @_ == 3;
	croak "getGlobalProblem: argument 1 must contain a set_id"
		unless defined $setID;
	croak "getGlobalProblem: argument 2 must contain a problem_id"
		unless defined $problemID;
	
	return $self->{problem}->get($setID, $problemID);
}

sub getGlobalProblems {
	my ($self, @problemIDs) = @_;
	
	#croak "getGlobalProblems: requires 1 or more argument"
	#	unless @_ >= 2;
	foreach my $i (0 .. $#problemIDs) {
		croak "getGlobalProblems: element $i of argument list must contain a <set_id, problem_id> pair"
			unless defined $problemIDs[$i]
			       and ref $problemIDs[$i] eq "ARRAY"
			       and @{$problemIDs[$i]} == 2
			       and defined $problemIDs[$i]->[0]
			       and defined $problemIDs[$i]->[1];
	}
	
	return $self->{problem}->gets(@problemIDs);
}

sub getAllGlobalProblems {
	my ($self, $setID) = @_;
	
	croak "getAllGlobalProblems: requires 1 arguments"
		unless @_ == 2;
	croak "getAllGlobalProblems: argument 1 must contain a set_id"
		unless defined $setID;
	
	if ($self->{problem}->can("getAll")) {
		return $self->{problem}->getAll($setID);
	} else {
		my @problemIDPairs = $self->{problem}->list($setID, undef);
		return $self->{problem}->gets(@problemIDPairs);
	}
}

sub putGlobalProblem {
	my ($self, $GlobalProblem) = @_;
	
	croak "putGlobalProblem: requires 1 argument"
		unless @_ == 2;
	croak "putGlobalProblem: argument 1 must be of type ", $self->{problem}->{record}
		unless ref $GlobalProblem eq $self->{problem}->{record};
	
	checkKeyfields($GlobalProblem);
	
	croak "putGlobalProblem: global problem not found (perhaps you meant to use addGlobalProblem?)"
		unless $self->{problem}->exists($GlobalProblem->set_id, $GlobalProblem->problem_id);
	croak "putGlobalProblem: set ", $GlobalProblem->set_id, " not found"
		unless $self->{set}->exists($GlobalProblem->set_id);
	
	return $self->{problem}->put($GlobalProblem);
}

sub deleteGlobalProblem {
	my ($self, $setID, $problemID) = @_;
	
	croak "deleteGlobalProblem: requires 2 arguments"
		unless @_ == 3;
	croak "deleteGlobalProblem: argument 1 must contain a set_id"
		unless defined $setID or caller eq __PACKAGE__;
	croak "deleteGlobalProblem: argument 2 must contain a problem_id"
		unless defined $problemID or caller eq __PACKAGE__;
	
	$self->deleteUserProblem(undef, $setID, $problemID);
	return $self->{problem}->delete($setID, $problemID);
}

################################################################################
# problem_user functions
################################################################################

BEGIN { *newUserProblem = gen_new("problem_user"); }

sub countProblemUsers {
	my ($self, $setID, $problemID) = @_;
	
	croak "countProblemUsers: requires 2 arguments"
		unless @_ == 3;
	croak "countProblemUsers: argument 1 must contain a set_id"
		unless defined $setID;
	croak "countProblemUsers: argument 2 must contain a problem_id"
		unless defined $problemID;
	
	# the slow way
	#return scalar $self->{problem_user}->list(undef, $setID, $problemID);
	
	# the fast way
	return $self->{problem_user}->count(undef, $setID, $problemID);
}

sub listProblemUsers {
	my ($self, $setID, $problemID) = @_;
	
	carp "listProblemUsers called in SCALAR context: use countProblemUsers instead!\n"
		unless wantarray;
	
	croak "listProblemUsers: requires 2 arguments"
		unless @_ == 3;
	croak "listProblemUsers: argument 1 must contain a set_id"
		unless defined $setID;
	croak "listProblemUsers: argument 2 must contain a problem_id"
		unless defined $problemID;
	
	return map { $_->[0] } # extract user_id
		$self->{problem_user}->list(undef, $setID, $problemID);
}

sub listUserProblems {
	my ($self, $userID, $setID) = @_;
	
	croak "listUserProblems: requires 2 arguments"
		unless @_ == 3;
	croak "listUserProblems: argument 1 must contain a user_id"
		unless defined $userID;
	croak "listUserProblems: argument 2 must contain a set_id"
		unless defined $setID;
	
	return map { $_->[2] } # extract problem_id
		$self->{problem_user}->list($userID, $setID, undef);
}

sub addUserProblem {
	my ($self, $UserProblem) = @_;
	
	croak "addUserProblem: requires 1 argument"
		unless @_ == 2;
	croak "addUserProblem: argument 1 must be of type ", $self->{problem_user}->{record}
		unless ref $UserProblem eq $self->{problem_user}->{record};

# catch versioned sets here and check them allowing commas in some fields
	my $setID = $UserProblem->set_id;
	if ( $setID =~ /^(.*),v\d+/ ) {  # then it's a versioned set
	    $setID = $1;
	    checkKeyfields($UserProblem, 1);
	} else {
	    checkKeyfields($UserProblem);
	}
	
	croak "addUserProblem: user problem exists (perhaps you meant to use putUserProblem?)"
		if $self->{problem_user}->exists($UserProblem->user_id, $UserProblem->set_id, $UserProblem->problem_id);
	croak "addUserProblem: user set ", $UserProblem->set_id, " for user ", $UserProblem->user_id, " not found"
		unless $self->{set_user}->exists($UserProblem->user_id, $setID);
	croak "addUserProblem: problem ", $UserProblem->problem_id, " in set ", $UserProblem->set_id, " not found"
		unless $self->{problem}->exists($setID, $UserProblem->problem_id);
	
	return $self->{problem_user}->add($UserProblem);
}

sub getUserProblem {
	my ($self, $userID, $setID, $problemID) = @_;
	
	croak "getUserProblem: requires 3 arguments"
		unless @_ == 4;
	croak "getUserProblem: argument 1 must contain a user_id"
		unless defined $userID;
	croak "getUserProblem: argument 2 must contain a set_id"
		unless defined $setID;
	croak "getUserProblem: argument 3 must contain a problem_id"
		unless defined $problemID;
	
	return ( $self->getUserProblems([$userID, $setID, $problemID]) )[0];
}

sub getUserProblems {
	my ($self, @userProblemIDs) = @_;
	
	#croak "getUserProblems: requires 1 or more argument"
	#	unless @_ >= 2;
	foreach my $i (0 .. $#userProblemIDs) {
		croak "getUserProblems: element $i of argument list must contain a <user_id, set_id, problem_id> triple"
			unless defined $userProblemIDs[$i]
			       and ref $userProblemIDs[$i] eq "ARRAY"
			       and @{$userProblemIDs[$i]} == 3
			       and defined $userProblemIDs[$i]->[0]
			       and defined $userProblemIDs[$i]->[1]
			       and defined $userProblemIDs[$i]->[2];
	}
	
	return $self->{problem_user}->gets(@userProblemIDs);
}

sub getAllUserProblems {
	my ($self, $userID, $setID) = @_;
	
	croak "getAllUserProblems: requires 2 arguments"
		unless @_ == 3;
	croak "getAllUserProblems: argument 1 must contain a user_id"
		unless defined $userID;
	croak "getAllUserProblems: argument 2 must contain a set_id"
		unless defined $setID;
	
	if ($self->{problem_user}->can("getAll")) {
		return $self->{problem_user}->getAll($userID, $setID);
	} else {
		my @problemIDTriples = $self->{problem_user}->list($userID, $setID, undef);
		return $self->{problem_user}->gets(@problemIDTriples);
	}
}

sub getAllMergedUserProblems {
	my ($self, $userID, $setID) = @_;

	croak "getAllMergedUserProblems: requires 2 arguments"
		unless @_ == 3;
	croak "getAllMergedUserProblems: argument 1 must contain a user_id"
		unless defined $userID;
	croak "getAllMergedUserProblems: argument 2 must contain a set_id"
		unless defined $setID;

	my @userProblemRecords = $self->getAllUserProblems( $userID, $setID );
	my @userProblemIDs = map { [$userID, $setID, $_->problem_id] } @userProblemRecords;
	return $self->getMergedProblems( @userProblemIDs );
}

sub putUserProblem {
	my ($self, $UserProblem, $versioned) = @_;
# $versioned is an optional argument which lets us slip versioned setIDs
#    through checkKeyfields.  this makes the first croak message a little 
#    disingenuous, of course.
	
	croak "putUserProblem: requires 1 argument"
		unless @_ == 2 or @_ == 3;
	croak "putUserProblem: argument 1 must be of type ", $self->{problem_user}->{record}
		unless ref $UserProblem eq $self->{problem_user}->{record};
	
	checkKeyfields($UserProblem, $versioned);
	
	croak "putUserProblem: user set ", $UserProblem->set_id, " for user ", $UserProblem->user_id, " not found"
		unless $self->{set_user}->exists($UserProblem->user_id, $UserProblem->set_id);
	croak "putUserProblem: user problem not found (perhaps you meant to use addUserProblem?)"
		unless $self->{problem_user}->exists($UserProblem->user_id, $UserProblem->set_id, $UserProblem->problem_id);

# allow versioned set names when $versioned is defined and true
	my $unversionedSetID = $UserProblem->set_id;
	$unversionedSetID =~ s/,v\d+$// if ( defined($versioned) && $versioned );

	croak "putUserProblem: problem ", $UserProblem->problem_id, " in set ", $UserProblem->set_id, " not found"
		unless $self->{problem}->exists($unversionedSetID, $UserProblem->problem_id);
	
	return $self->{problem_user}->put($UserProblem);
}

sub deleteUserProblem {
	my ($self, $userID, $setID, $problemID) = @_;
	
	croak "getUserProblem: requires 3 arguments"
		unless @_ == 4;
	croak "getUserProblem: argument 1 must contain a user_id"
		unless defined $userID or caller eq __PACKAGE__;
	croak "getUserProblem: argument 2 must contain a set_id"
		unless defined $setID or caller eq __PACKAGE__;
	croak "getUserProblem: argument 3 must contain a problem_id"
		unless defined $problemID or caller eq __PACKAGE__;
	
	return $self->{problem_user}->delete($userID, $setID, $problemID);
}

################################################################################
# set+set_user functions
################################################################################

sub getGlobalUserSet {
	carp "getGlobalUserSet: this method is deprecated -- use getMergedSet instead";
	return shift->getMergedSet(@_);
}

sub getMergedSet {
	my ($self, $userID, $setID) = @_;
	
	croak "getMergedSet: requires 2 arguments"
		unless @_ == 3;
	croak "getMergedSet: argument 1 must contain a user_id"
		unless defined $userID;
	croak "getMergedSet: argument 2 must contain a set_id"
		unless defined $setID;
	
	return ( $self->getMergedSets([$userID, $setID]) )[0];
}

sub getMergedVersionedSet {
    my ( $self, $userID, $setID, $versionNum ) = @_;
#
# getMergedVersionedSet( self, uid, sid [, versionNum] )
#    in:  userID uid, setID sid, and optionally version number versionNum
#    out: the merged set version for the user; if versionNum is specified,
#         return that set version and otherwise the latest version.  if 
#         no versioned set exists for the user, return undef.
#    note that sid can be setid,vN, thereby specifying the version number
#      explicitly.  if this is the case, any specified versionNum is ignored
# we'd like to use getMergedSet to do the dirty work here, but that runs 
#    into problems because we want to merge with both the template set
#    (that is, the userSet setID) and the global set 

    croak "getMergedVersionedSet: requires at least two arguments, a userID " .
	"and setID (missing setID)" if ( @_ < 3 || ! defined( $setID ) );

    my $versionedSetID = $setID;

    if ( ( ! defined($versionNum) || ! $versionNum ) && $setID !~ /,v\d+$/ ) {
	$versionNum = $self->getUserSetVersionNumber( $userID, $setID );

	if ( ! $versionNum ) {
	    return undef;
	} else {
	    $versionedSetID .= ",v$versionNum";
	}
    } elsif ( defined($versionNum) && $versionNum ) {
	$versionedSetID = ($setID =~ /,v\d+$/ ? $setID : "$setID,v$versionNum");
    } else {  # the last case is that $setID =~ /,v\d+$/
	$setID =~ s/,v\d+//;
    }

    croak "getMergedVersionedSet: requires at least two arguments, a userID " .
	"and setID (missing userID)" if ( ! defined( $userID ) );

    return ( $self->getMergedVersionedSets( [$userID, $setID, 
					     $versionedSetID] ) )[0];
}

# a significant amount of getMergedSets is duplicated in getMergedVersionedSets
# below

sub getMergedSets {
	my ($self, @userSetIDs) = @_;
	
	#croak "getMergedSets: requires 1 or more argument"
	#	unless @_ >= 2;
	foreach my $i (0 .. $#userSetIDs) {
		croak "getMergedSets: element $i of argument list must contain a <user_id, set_id> pair"
			unless defined $userSetIDs[$i]
			       and ref $userSetIDs[$i] eq "ARRAY"
			       and @{$userSetIDs[$i]} == 2
			       and defined $userSetIDs[$i]->[0]
			       and defined $userSetIDs[$i]->[1];
	}
	
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

sub getMergedVersionedSets {
    my ($self, @userSetIDs) = @_;
	
    foreach my $i (0 .. $#userSetIDs) {
	croak "getMergedSets: element $i of argument list must contain a " .
	    "<user_id, set_id, versioned_set_id> triple"
	    unless( defined $userSetIDs[$i]
		    and ref $userSetIDs[$i] eq "ARRAY"
		    and @{$userSetIDs[$i]} == 3
		    and defined $userSetIDs[$i]->[0]
		    and defined $userSetIDs[$i]->[1]
		    and defined $userSetIDs[$i]->[2] );
    }

# these are [user_id, set_id] pairs
    my @nonversionedUserSetIDs = map { [$_->[0], $_->[1]] } @userSetIDs;
# these are [user_id, versioned_set_id] pairs
    my @versionedUserSetIDs = map { [$_->[0], $_->[2]] } @userSetIDs;

# we merge the nonversioned ("template") user sets (user_id, set_id) and
#    the global data into the versioned user sets	
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
    my @commonFields = 
	grep { exists $globalSetFields{$_} } $self->newUserSet->FIELDS;
	
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
# problem+problem_user functions
################################################################################

sub getGlobalUserProblem {
	carp "getGlobalUserProblem: this method is deprecated -- use getMergedProblem instead";
	return shift->getMergedProblem(@_);
}

sub getMergedProblem {
	my ($self, $userID, $setID, $problemID) = @_;
	
	croak "getGlobalUserSet: requires 3 arguments"
		unless @_ == 4;
	croak "getGlobalUserSet: argument 1 must contain a user_id"
		unless defined $userID;
	croak "getGlobalUserSet: argument 2 must contain a set_id"
		unless defined $setID;
	croak "getGlobalUserSet: argument 3 must contain a problem_id"
		unless defined $problemID;
	
	return ( $self->getMergedProblems([$userID, $setID, $problemID]) )[0];
}

sub getMergedVersionedProblem {
    my ($self, $userID, $setID, $setVersionID, $problemID) = @_;

# this exists distinct from getMergedProblem only to be able to include the
#    setVersionID
    
    croak "getGlobalUserSet: requires 4 arguments"
	unless @_ == 5;
    croak "getGlobalUserSet: argument 1 must contain a user_id"
	unless defined $userID;
    croak "getGlobalUserSet: argument 2 must contain a set_id"
	unless defined $setID;
    croak "getGlobalUserSet: argument 3 must contain a versioned set_id"
	unless defined $setVersionID;
    croak "getGlobalUserSet: argument 4 must contain a problem_id"
	unless defined $problemID;
	
    return ($self->getMergedVersionedProblems([$userID, $setID, $setVersionID,
					       $problemID]))[0];
}

sub getMergedProblems {
	my ($self, @userProblemIDs) = @_;
	
	#croak "getMergedProblems: requires 1 or more argument"
	#	unless @_ >= 2;
	foreach my $i (0 .. $#userProblemIDs) {
		croak "getMergedProblems: element $i of argument list must contain a <user_id, set_id, problem_id> triple"
			unless defined $userProblemIDs[$i]
			       and ref $userProblemIDs[$i] eq "ARRAY"
			       and @{$userProblemIDs[$i]} == 3
			       and defined $userProblemIDs[$i]->[0]
			       and defined $userProblemIDs[$i]->[1]
			       and defined $userProblemIDs[$i]->[2];
	}
	
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

sub getMergedVersionedProblems {
    my ($self, @userProblemIDs) = @_;
	
    foreach my $i (0 .. $#userProblemIDs) {
	croak "getMergedProblems: element $i of argument list must contain a " .
	    "<user_id, set_id, versioned_set_id, problem_id> quadruple"
	    unless( defined $userProblemIDs[$i]
		    and ref $userProblemIDs[$i] eq "ARRAY"
		    and @{$userProblemIDs[$i]} == 4
		    and defined $userProblemIDs[$i]->[0]
		    and defined $userProblemIDs[$i]->[1]
		    and defined $userProblemIDs[$i]->[2]
		    and defined $userProblemIDs[$i]->[3] );
    }
	
    debug("DB: getUserProblems start");

# these are triples [user_id, set_id, problem_id]
    my @nonversionedProblemIDs = map {[$_->[0],$_->[1],$_->[3]]} @userProblemIDs;
# these are triples [user_id, versioned_set_id, problem_id]
    my @versionedProblemIDs = map {[$_->[0],$_->[2],$_->[3]]} @userProblemIDs;

# these are the actual user problems for the version
    my @versionUserProblems = $self->getUserProblems(@versionedProblemIDs);

# get global problems (no user_id, set_id = nonversioned set_id) and 
#    template problems (user_id, set_id = nonversioned set_id); we merge with
#    both of these, replacing global values with template values and not 
#    taking either in the event that the versioned problem already has a 
#    value for the field in question
    debug("DB: pull out set/problem IDs start");
    my @globalProblemIDs = map { [ $_->[1], $_->[2] ] } @nonversionedProblemIDs;
    debug("DB: getGlobalProblems start");
    my @GlobalProblems = $self->getGlobalProblems( @globalProblemIDs );
    debug("DB: getTemplateProblems start");
    my @TemplateProblems = $self->getUserProblems( @nonversionedProblemIDs );
	
    debug("DB: calc common fields start");

    my %globalProblemFields = map { $_ => 1 } $self->newGlobalProblem->FIELDS;
    my @commonFields = 
	grep { exists $globalProblemFields{$_} } $self->newUserProblem->FIELDS;
	
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
	foreach my $i (@$items) {
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
