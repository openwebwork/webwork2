################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB;

=head1 NAME

WeBWorK::DB - interface with the WeBWorK databases.

=head1 SYNOPSIS

 my $db = WeBWorK::DB->new($courseEnvironment);
 
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
class, data source, and additional parameters are specified by the C<%dbLayout>
hash in the course environment.

=head1 ARCHITECTURE

The new database system uses a three-tier architecture to insulate each layer
from the adjacent layers.

=head2 Top Layer: DB

The top layer of the architecture is the DB module. It provides the methods
listed below, and uses schema modules (via tables) to implement those methods.

            / new* list* exists* add* get* put* delete* \             <- api
 +------------------------------------------------------------------+
 |                                DB                                |
 +------------------------------------------------------------------+
  \ password permission key user set set_user problem problem_user /  <- tables

=head2 Middle Layer: Schemas

The middle layer of the architecture is provided by one or more schema modules.
They are called "schema" modules because they control the structure of the data
for a table. This includes odd things like the way multiple tables are encoded
in a single hash in the WW1Hash schema, and the encoding scheme used.

The schema modules provide an API that matches the requirements of the DB
layer, on a per-table basis. Each schema module has a style that determines
which drivers it can interface with. For example, WW1Hash is a "hash" style
schema. SQL is a "dbi" style schema.

=head3 Examples

Both WeBWorK 1.x and 2.x courses use:

  / password  permission  key \        / user \      <- tables provided
 +-----------------------------+  +----------------+
 |          Auth1Hash          |  | Classlist1Hash |
 +-----------------------------+  +----------------+
             \ hash /                  \ hash /      <- driver style required

WeBWorK 1.x courses also use:

  / set_user problem_user \       / set problem \    
 +-------------------------+  +---------------------+
 |         WW1Hash         |  | GlobalTableEmulator |
 +-------------------------+  +---------------------+
           \ hash /                   \ null /       

The GlobalTableEmulator schema emulates the global set and problem tables using
data from the set_user and problem_user tables.

WeBWorK 2.x courses also use:

  / set set_user problem problem_user \ 
 +-------------------------------------+
 |               WW2Hash               |
 +-------------------------------------+
                 \ hash /               

=head2 Bottom Layer: Drivers

Driver modules implement a style for a schema. They provide physical access to
a data source containing the data for a table. The style of a driver determines
what methods it provides. All drivers provide C<connect(MODE)> and
C<disconnect()> methods. A hash style driver provides a C<hash()> method which
returns the tied hash. A dbi style driver provides a C<handle()> method which
returns the DBI handle.

=head3 Examples

  / hash \    / hash \    / hash \  <- style
 +--------+  +--------+  +--------+
 |   DB   |  |  GDBM  |  |   DB3  |
 +--------+  +--------+  +--------+

  / dbi \    / ldap \ 
 +-------+  +--------+
 |  SQL  |  |  LDAP  |
 +-------+  +--------+

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
use WeBWorK::Timing;
use WeBWorK::Utils qw(runtime_use);

################################################################################
# constructor
################################################################################

=head1 CONSTRUCTOR

=over

=item new($ce)

The C<new> method creates a DB object and brings up the underlying
schema/driver structure according to the C<%dbLayout> hash in C<$ce>, a
WeBWorK::CourseEnvironment object.

=back

=head2 C<%dbLayout> Format

The C<%dbLayout> hash consists of items keyed by table names. The value of each
item is a reference to a hash containing the following items:

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

For each table defined in C<%dbLayout>, C<new> loads the record, schema, and
driver modules. It the schema module's C<tables> method lists the current table
(or contains the string "*") and the output of the schema and driver modules'
C<style> methods match, the table is installed. Otherwise, an exception is
thrown.

=cut

sub new($$) {
	my ($invocant, $ce) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {};
	bless $self, $class; # bless this here so we can pass it to the schema
	
	# load the modules required to handle each table, and create driver
	my %dbLayout = %{$ce->{dbLayout}};
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
			$self, $driver->new($source, $params),
			$table, $record, $params) };
		croak "error instantiating DB schema $schema for table $table: $@"
			if $@;
		
		$self->{$table} = $schemaObject;
	}
	
	return $self;
}

=head1 METHODS

=cut

################################################################################
# password functions
################################################################################

=head2 Password Methods

=over

=item newPassword()

Returns a new, empty password object.

=cut 

sub newPassword {
	my ($self, $prototype) = @_;
	return $self->{password}->{record}->new($prototype);
}

=item listPasswords()

Returns a list of user IDs representing the records in the password table.

=cut

sub listPasswords {
	my ($self) = @_;
	
	croak "listPasswords: requires 0 arguments"
		unless @_ == 1;
	
	return map { $_->[0] }
		$self->{password}->list(undef);
}

=item addPassword($Password)

$Password is a record object. The password will be added to the password table
if a password with the same user ID does not already exist. If one does exist,
an exception is thrown. To add a password, a user with a matching user ID must
exist in the user table.

=cut

sub addPassword($$) {
	my ($self, $Password) = @_;
	
	croak "addPassword: requires 1 argument"
		unless @_ == 2;
	croak "addPassword: argument 1 must be of type ", $self->{password}->{record}
		unless ref $Password eq $self->{password}->{record};
	croak "addPassword: password exists (perhaps you meant to use putPassword?)"
		if $self->{password}->exists($Password->user_id);
	croak "addPassword: user ", $Password->user_id, " not found"
		unless $self->{user}->exists($Password->user_id);
	
	checkKeyfields($Password);
	
	return $self->{password}->add($Password);
}

=item getPassword($userID)

If a record with a matching user ID exists, a record object containting that
record's data will be returned. If no such record exists, an undefined value
will be returned.

=cut

sub getPassword($$) {
	my ($self, $userID) = @_;
	
	croak "getPassword: requires 1 argument"
		unless @_ == 2;
	croak "getPassword: argument 1 must contain a user_id"
		unless defined $userID;
	
	return $self->{password}->get($userID);
}

=item putPassword($Password)

$Password is a record object. If a password record with the same user ID exists
in the password table, the data in the record is replaced with the data in
$Password. If a matching password record does not exist, an exception is
thrown.

=cut

sub putPassword($$) {
	my ($self, $Password) = @_;
	
	croak "putPassword: requires 1 argument"
		unless @_ == 2;
	croak "putPassword: argument 1 must be of type ", $self->{password}->{record}
		unless ref $Password eq $self->{password}->{record};
	croak "putPassword: password not found (perhaps you meant to use addPassword?)"
		unless $self->{password}->exists($Password->user_id);
	
	checkKeyfields($Password);
	
	return $self->{password}->put($Password);
}

=item deletePassword($userID)

If a password record with a user ID matching $userID exists in the password
table, it is removed and the method returns a true value. If one does exist,
a false value is returned.

=cut

sub deletePassword($$) {
	my ($self, $userID) = @_;
	
	croak "putPassword: requires 1 argument"
		unless @_ == 2;
	croak "deletePassword: argument 1 must contain a user_id"
		unless defined $userID;
	
	return $self->{password}->delete($userID);
}

=back

=cut

################################################################################
# permission functions
################################################################################

=head2 Permission Level Methods

=over

=item newPermissionLevel()

Returns a new, empty permission level object.

=cut 

sub newPermissionLevel {
	my ($self, $prototype) = @_;
	return $self->{permission}->{record}->new($prototype);
}

=item listPermissionLevels()

Returns a list of user IDs representing the records in the permission table.

=cut

sub listPermissionLevels($) {
	my ($self) = @_;
	
	croak "listPermissionLevels: requires 0 arguments"
		unless @_ == 1;
	
	return map { $_->[0] }
		$self->{permission}->list(undef);
}

=item addPermissionLevel($PermissionLevel)

$PermissionLevel is a record object. The permission level will be added to the
permission table if a permission level with the same user ID does not already
exist. If one does exist, an exception is thrown. To add a permission level, a
user with a matching user ID must exist in the user table.

=cut

sub addPermissionLevel($$) {
	my ($self, $PermissionLevel) = @_;
	
	croak "addPermissionLevel: requires 1 argument"
		unless @_ == 2;
	croak "addPermissionLevel: argument 1 must be of type ", $self->{permission}->{record}
		unless ref $PermissionLevel eq $self->{permission}->{record};
	croak "addPermissionLevel: permission level exists (perhaps you meant to use putPermissionLevel?)"
		if $self->{permission}->exists($PermissionLevel->user_id);
	croak "addPermissionLevel: user ", $PermissionLevel->user_id, " not found"
		unless $self->{user}->exists($PermissionLevel->user_id);
	
	checkKeyfields($PermissionLevel);
	
	return $self->{permission}->add($PermissionLevel);
}

=item getPermissionLevel($userID)

If a record with a matching user ID exists, a record object containting that
record's data will be returned. If no such record exists, an undefined value
will be returned.

=cut

sub getPermissionLevel($$) {
	my ($self, $userID) = @_;
	
	croak "getPermissionLevel: requires 1 argument"
		unless @_ == 2;
	croak "getPermissionLevel: argument 1 must contain a user_id"
		unless defined $userID;
	
	return $self->{permission}->get($userID);
}

=item putPermissionLevel($PermissionLevel)

$PermissionLevel is a record object. If a permission level record with the same
user ID exists in the permission table, the data in the record is replaced with
the data in $PermissionLevel. If a matching permission level record does not
exist, an exception is thrown.

=cut

sub putPermissionLevel($$) {
	my ($self, $PermissionLevel) = @_;
	
	croak "putPermissionLevel: requires 1 argument"
		unless @_ == 2;
	croak "putPermissionLevel: argument 1 must be of type ", $self->{permission}->{record}
		unless ref $PermissionLevel eq $self->{permission}->{record};
	croak "putPermissionLevel: permission level not found (perhaps you meant to use addPermissionLevel?)"
		unless $self->{permission}->exists($PermissionLevel->user_id);
	
	checkKeyfields($PermissionLevel);
	
	return $self->{permission}->put($PermissionLevel);
}

=item deletePermissionLevel($userID)

If a permission level record with a user ID matching $userID exists in the
permission table, it is removed and the method returns a true value. If one
does exist, a false value is returned.

=cut

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

=head2 Key Methods

=over

=item newKey()

Returns a new, empty key object.

=cut 

sub newKey {
	my ($self, $prototype) = @_;
	return $self->{key}->{record}->new($prototype);
}

=item listKeys()

Returns a list of user IDs representing the records in the key table.

=cut

sub listKeys($) {
	my ($self) = @_;
	
	croak "listKeys: requires 0 arguments"
		unless @_ == 1;
	
	return map { $_->[0] }
		$self->{key}->list(undef);
}

=item addKey($Key)

$Key is a record object. The key will be added to the key table if a key with
the same user ID does not already exist. If one does exist, an exception is
thrown. To add a key, a user with a matching user ID must exist in the user
table.

=cut

sub addKey($$) {
	my ($self, $Key) = @_;
	
	croak "addKey: requires 1 argument"
		unless @_ == 2;
	croak "addKey: argument 1 must be of type ", $self->{key}->{record}
		unless ref $Key eq $self->{key}->{record};
	croak "addKey: key exists (perhaps you meant to use putKey?)"
		if $self->{key}->exists($Key->user_id);
	croak "addKey: user ", $Key->user_id, " not found"
		unless $self->{user}->exists($Key->user_id);
	
	checkKeyfields($Key);
	
	return $self->{key}->add($Key);
}

=item getKey($userID)

If a record with a matching user ID exists, a record object containting that
record's data will be returned. If no such record exists, an undefined value
will be returned.

=cut

sub getKey($$) {
	my ($self, $userID) = @_;
	
	croak "getKey: requires 1 argument"
		unless @_ == 2;
	croak "getKey: argument 1 must contain a user_id"
		unless defined $userID;
	
	return $self->{key}->get($userID);
}

=item putKey($Key)

$Key is a record object. If a key record with the same user ID exists in the
key table, the data in the record is replaced with the data in $Key. If a
matching key record does not exist, an exception is thrown.

=cut

sub putKey($$) {
	my ($self, $Key) = @_;
	
	croak "putKey: requires 1 argument"
		unless @_ == 2;
	croak "putKey: argument 1 must be of type ", $self->{key}->{record}
		unless ref $Key eq $self->{key}->{record};
	croak "putKey: key not found (perhaps you meant to use addKey?)"
		unless $self->{key}->exists($Key->user_id);
	
	checkKeyfields($Key);
	
	return $self->{key}->put($Key);
}

=item deleteKey($userID)

If a key record with a user ID matching $userID exists in the key table, it is
removed and the method returns a true value. If one does exist, a false value
is returned.

=cut

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

=head2 User Methods

=over

=item newUser()

Returns a new, empty user object.

=cut 

sub newUser {
	my ($self, $prototype) = @_;
	return $self->{user}->{record}->new($prototype);
}

=item listUsers()

Returns a list of user IDs representing the records in the user table.

=cut

sub listUsers($) {
	my ($self) = @_;
	
	croak "listUsers: requires 0 arguments"
		unless @_ == 1;
	
	return map { $_->[0] }
		$self->{user}->list(undef);
}

=item addUser($User)

$User is a record object. The user will be added to the user table if a user
with the same user ID does not already exist. If one does exist, an exception
is thrown.

=cut

sub addUser($$) {
	my ($self, $User) = @_;
	
	croak "addUser: requires 1 argument"
		unless @_ == 2;
	croak "addUser: argument 1 must be of type ", $self->{user}->{record}
		unless ref $User eq $self->{user}->{record};
	croak "addUser: user exists (perhaps you meant to use putUser?)"
		if $self->{user}->exists($User->user_id);
	
	checkKeyfields($User);
	
	return $self->{user}->add($User);
}

=item getUser($userID)

If a record with a matching user ID exists, a record object containting that
record's data will be returned. If no such record exists, an undefined value
will be returned.

=cut

sub getUser($$) {
	my ($self, $userID) = @_;
	
	croak "getUser: requires 1 argument"
		unless @_ == 2;
	croak "getUser: argument 1 must contain a user_id"
		unless defined $userID;
	
	return $self->{user}->get($userID);
}

=item putUser($User)

$User is a record object. If a user record with the same user ID exists in the
user table, the data in the record is replaced with the data in $User. If a
matching user record does not exist, an exception is thrown.

=cut

sub putUser($$) {
	my ($self, $User) = @_;
	
	croak "putUser: requires 1 argument"
		unless @_ == 2;
	croak "putUser: argument 1 must be of type ", $self->{user}->{record}
		unless ref $User eq $self->{user}->{record};
	croak "putUser: user not found (perhaps you meant to use addUser?)"
		unless $self->{user}->exists($User->user_id);
	
	checkKeyfields($User);
	
	return $self->{user}->put($User);
}

=item deleteUser($userID)

If a user record with a user ID matching $userID exists in the user table, it
is removed and the method returns a true value. If one does exist, a false
value is returned. When a user record is deleted, all records associated with
that user are also deleted. This includes the password, permission, and key
records, and all user set records for that user.

=cut

sub deleteUser($$) {
	my ($self, $userID) = @_;
	
	croak "deleteUser: requires 1 argument"
		unless @_ == 2;
	croak "deleteUser: argument 1 must contain a user_id"
		unless defined $userID;
	
	#$self->deleteUserSet($userID, $_)
	#	foreach $self->listUserSets($userID);
	$self->deleteUserSet($userID, undef);
	$self->deletePassword($userID);
	$self->deletePermissionLevel($userID);
	$self->deleteKey($userID);
	return $self->{user}->delete($userID);
}

################################################################################
# set functions
################################################################################

sub newGlobalSet {
	my ($self, $prototype) = @_;
	return $self->{set}->{record}->new($prototype);
}

sub listGlobalSets($) {
	my ($self) = @_;
	
	croak "listGlobalSets: requires 0 arguments"
		unless @_ == 1;
	
	return map { $_->[0] }
		$self->{set}->list(undef);
}

sub addGlobalSet($$) {
	my ($self, $GlobalSet) = @_;
	
	croak "addGlobalSet: requires 1 argument"
		unless @_ == 2;
	croak "addGlobalSet: argument 1 must be of type ", $self->{set}->{record}
		unless ref $GlobalSet eq $self->{set}->{record};
	croak "addGlobalSet: global set exists (perhaps you meant to use putGlobalSet?)"
		if $self->{set}->exists($GlobalSet->set_id);
	
	checkKeyfields($GlobalSet);
	
	return $self->{set}->add($GlobalSet);
}

sub getGlobalSet($$) {
	my ($self, $setID) = @_;
	
	croak "getGlobalSet: requires 1 argument"
		unless @_ == 2;
	croak "getGlobalSet: argument 1 must contain a set_id"
		unless defined $setID;
	
	return $self->{set}->get($setID);
}

sub putGlobalSet($$) {
	my ($self, $GlobalSet) = @_;
	
	croak "putGlobalSet: requires 1 argument"
		unless @_ == 2;
	croak "putGlobalSet: argument 1 must be of type ", $self->{set}->{record}
		unless ref $GlobalSet eq $self->{set}->{record};
	croak "putGlobalSet: global set not found (perhaps you meant to use addGlobalSet?)"
		unless $self->{set}->exists($GlobalSet->set_id);
	
	checkKeyfields($GlobalSet);
	
	return $self->{set}->put($GlobalSet);
}

sub deleteGlobalSet($$) {
	my ($self, $setID) = @_;
	
	croak "deleteGlobalSet: requires 1 argument"
		unless @_ == 2;
	croak "deleteGlobalSet: argument 1 must contain a set_id"
		unless defined $setID or caller eq __PACKAGE__;
	
	#$self->deleteUserSet($_, $setID)
	#	foreach $self->listSetUsers($setID);
	#$self->deleteGlobalProblem($setID, $_)
	#	foreach $self->listGlobalProblems($setID);
	$self->deleteUserSet(undef, $setID);
	$self->deleteGlobalProblem($setID, undef);
	return $self->{set}->delete($setID);
}

################################################################################
# set_user functions
################################################################################

sub newUserSet {
	my ($self, $prototype) = @_;
	return $self->{set_user}->{record}->new($prototype);
}

sub listSetUsers($$) {
	my ($self, $setID) = @_;
	
	croak "listSetUsers: requires 1 argument"
		unless @_ == 2;
	croak "listSetUsers: argument 1 must contain a set_id"
		unless defined $setID;
	
	return map { $_->[0] } # extract user_id
		$self->{set_user}->list(undef, $setID);
}

sub listUserSets($$) {
	my ($self, $userID) = @_;
	
	croak "listUserSets: requires 1 argument"
		unless @_ == 2;
	croak "listUserSets: argument 1 must contain a user_id"
		unless defined $userID;
	
	return map { $_->[1] } # extract set_id
		$self->{set_user}->list($userID, undef);
}

sub addUserSet($$) {
	my ($self, $UserSet) = @_;
	
	croak "addUserSet: requires 1 argument"
		unless @_ == 2;
	croak "addUserSet: argument 1 must be of type ", $self->{set_user}->{record}
		unless ref $UserSet eq $self->{set_user}->{record};
	croak "addUserSet: user set exists (perhaps you meant to use putUserSet?)"
		if $self->{set_user}->exists($UserSet->user_id, $UserSet->set_id);
	croak "addUserSet: user ", $UserSet->user_id, " not found"
		unless $self->{user}->exists($UserSet->user_id);
	croak "addUserSet: set ", $UserSet->set_id, " not found"
		unless $self->{set}->exists($UserSet->set_id);
	
	checkKeyfields($UserSet);
	
	return $self->{set_user}->add($UserSet);
}

sub getUserSet($$$) {
	my ($self, $userID, $setID) = @_;
	
	croak "getUserSet: requires 2 arguments"
		unless @_ == 3;
	croak "getUserSet: argument 1 must contain a user_id"
		unless defined $userID;
	croak "getUserSet: argument 2 must contain a set_id"
		unless defined $setID;
	
	return $self->{set_user}->get($userID, $setID);
}

sub putUserSet($$) {
	my ($self, $UserSet) = @_;
	
	croak "putUserSet: requires 1 argument"
		unless @_ == 2;
	croak "putUserSet: argument 1 must be of type ", $self->{set_user}->{record}
		unless ref $UserSet eq $self->{set_user}->{record};
	croak "putUserSet: user set not found (perhaps you meant to use addUserSet?)"
		unless $self->{set_user}->exists($UserSet->user_id, $UserSet->set_id);
	croak "putUserSet: user ", $UserSet->user_id, " not found"
		unless $self->{user}->exists($UserSet->user_id);
	croak "putUserSet: set ", $UserSet->set_id, " not found"
		unless $self->{set}->exists($UserSet->set_id);
	
	checkKeyfields($UserSet);
	
	return $self->{set_user}->put($UserSet);
}

sub deleteUserSet($$$) {
	my ($self, $userID, $setID) = @_;
	
	croak "getUserSet: requires 2 arguments"
		unless @_ == 3;
	croak "getUserSet: argument 1 must contain a user_id"
		unless defined $userID or caller eq __PACKAGE__;
	croak "getUserSet: argument 2 must contain a set_id"
		unless defined $userID or caller eq __PACKAGE__;
	
	#$self->deleteUserProblem($userID, $setID, $_)
	#	foreach $self->listUserProblems($userID, $setID);
	$self->deleteUserProblem($userID, $setID, undef);
	return $self->{set_user}->delete($userID, $setID);
}

################################################################################
# problem functions
################################################################################

sub newGlobalProblem {
	my ($self, $prototype) = @_;
	return $self->{problem}->{record}->new($prototype);
}

sub listGlobalProblems($$) {
	my ($self, $setID) = @_;
	
	croak "listGlobalProblems: requires 1 arguments"
		unless @_ == 2;
	croak "listGlobalProblems: argument 1 must contain a set_id"
		unless defined $setID;
	
	return map { $_->[1] }
		$self->{problem}->list($setID, undef);
}

sub addGlobalProblem($$) {
	my ($self, $GlobalProblem) = @_;
	
	croak "addGlobalProblem: requires 1 argument"
		unless @_ == 2;
	croak "addGlobalProblem: argument 1 must be of type ", $self->{problem}->{record}
		unless ref $GlobalProblem eq $self->{problem}->{record};
	croak "addGlobalProblem: global problem exists (perhaps you meant to use putGlobalProblem?)"
		if $self->{problem}->exists($GlobalProblem->set_id, $GlobalProblem->problem_id);
	croak "addGlobalProblem: set ", $GlobalProblem->set_id, " not found"
		unless $self->{set}->exists($GlobalProblem->set_id);
	
	checkKeyfields($GlobalProblem);
	
	return $self->{problem}->add($GlobalProblem);
}

sub getGlobalProblem($$$) {
	my ($self, $setID, $problemID) = @_;
	
	croak "getGlobalProblem: requires 2 arguments"
		unless @_ == 3;
	croak "getGlobalProblem: argument 1 must contain a set_id"
		unless defined $setID;
	croak "getGlobalProblem: argument 2 must contain a problem_id"
		unless defined $problemID;
	
	return $self->{problem}->get($setID, $problemID);
}

sub putGlobalProblem($$) {
	my ($self, $GlobalProblem) = @_;
	
	croak "putGlobalProblem: requires 1 argument"
		unless @_ == 2;
	croak "putGlobalProblem: argument 1 must be of type ", $self->{problem}->{record}
		unless ref $GlobalProblem eq $self->{problem}->{record};
	croak "putGlobalProblem: global problem not found (perhaps you meant to use addGlobalProblem?)"
		unless $self->{problem}->exists($GlobalProblem->set_id, $GlobalProblem->problem_id);
	croak "putGlobalProblem: set ", $GlobalProblem->set_id, " not found"
		unless $self->{set}->exists($GlobalProblem->set_id);
	
	checkKeyfields($GlobalProblem);
	
	return $self->{problem}->put($GlobalProblem);
}

sub deleteGlobalProblem($$$) {
	my ($self, $setID, $problemID) = @_;
	
	croak "deleteGlobalProblem: requires 2 arguments"
		unless @_ == 3;
	croak "deleteGlobalProblem: argument 1 must contain a set_id"
		unless defined $setID or caller eq __PACKAGE__;
	croak "deleteGlobalProblem: argument 2 must contain a problem_id"
		unless defined $problemID or caller eq __PACKAGE__;
	
	#$self->deleteUserProblem($_, $setID, $problemID)
	#	foreach $self->listProblemUsers($setID, $problemID);
	$self->deleteUserProblem(undef, $setID, $problemID);
	return $self->{problem}->delete($setID, $problemID);
}

################################################################################
# problem_user functions
################################################################################

sub newUserProblem {
	my ($self, $prototype) = @_;
	return $self->{problem_user}->{record}->new($prototype);
}

sub listProblemUsers($$$) {
	my ($self, $setID, $problemID) = @_;
	
	croak "listProblemUsers: requires 2 arguments"
		unless @_ == 3;
	croak "listProblemUsers: argument 1 must contain a set_id"
		unless defined $setID;
	croak "listProblemUsers: argument 2 must contain a problem_id"
		unless defined $problemID;
	
	return map { $_->[0] } # extract user_id
		$self->{problem_user}->list(undef, $setID, $problemID);
}

sub listUserProblems($$$) {
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

sub addUserProblem($$) {
	my ($self, $UserProblem) = @_;
	
	croak "addUserProblem: requires 1 argument"
		unless @_ == 2;
	croak "addUserProblem: argument 1 must be of type ", $self->{problem_user}->{record}
		unless ref $UserProblem eq $self->{problem_user}->{record};
	croak "addUserProblem: user problem exists (perhaps you meant to use putUserProblem?)"
		if $self->{problem_user}->exists($UserProblem->user_id, $UserProblem->set_id, $UserProblem->problem_id);
	croak "addUserProblem: user set ", $UserProblem->set_id, " for user ", $UserProblem->user_id, " not found"
		unless $self->{set_user}->exists($UserProblem->user_id, $UserProblem->set_id);
	croak "addUserProblem: problem ", $UserProblem->problem_id, " in set ", $UserProblem->set_id, " not found"
		unless $self->{problem}->exists($UserProblem->set_id, $UserProblem->problem_id);
	
	checkKeyfields($UserProblem);
	
	return $self->{problem_user}->add($UserProblem);
}

sub getUserProblem($$$$) {
	my ($self, $userID, $setID, $problemID) = @_;
	
	croak "getUserProblem: requires 3 arguments"
		unless @_ == 4;
	croak "getUserProblem: argument 1 must contain a user_id"
		unless defined $userID;
	croak "getUserProblem: argument 2 must contain a set_id"
		unless defined $setID;
	croak "getUserProblem: argument 3 must contain a problem_id"
		unless defined $problemID;
	
	return $self->{problem_user}->get($userID, $setID, $problemID);
}

sub putUserProblem($$) {
	my ($self, $UserProblem) = @_;
	
	croak "putUserProblem: requires 1 argument"
		unless @_ == 2;
	croak "putUserProblem: argument 1 must be of type ", $self->{problem_user}->{record}
		unless ref $UserProblem eq $self->{problem_user}->{record};
	croak "putUserProblem: user set ", $UserProblem->set_id, " for user ", $UserProblem->user_id, " not found"
		unless $self->{set_user}->exists($UserProblem->user_id, $UserProblem->set_id);
	croak "putUserProblem: user problem not found (perhaps you meant to use addUserProblem?)"
		unless $self->{problem_user}->exists($UserProblem->user_id, $UserProblem->set_id, $UserProblem->problem_id);
	croak "putUserProblem: problem ", $UserProblem->problem_id, " in set ", $UserProblem->set_id, " not found"
		unless $self->{problem}->exists($UserProblem->set_id, $UserProblem->problem_id);
	
	checkKeyfields($UserProblem);
	
	return $self->{problem_user}->put($UserProblem);
}

sub deleteUserProblem($$$$) {
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
	
	#my $timer = WeBWorK::Timing->new("getMergedSet");
	
	croak "getGlobalUserSet: requires 2 arguments"
		unless @_ == 3;
	croak "getGlobalUserSet: argument 1 must contain a user_id"
		unless defined $userID;
	croak "getGlobalUserSet: argument 2 must contain a set_id"
		unless defined $setID;
	
	#$timer->start;
	my $UserSet = $self->getUserSet($userID, $setID);
	#$timer->continue("got user set");
	return unless $UserSet;
	my $GlobalSet = $self->getGlobalSet($setID);
	#$timer->continue("got global set");
	if ($GlobalSet) {
		foreach ($UserSet->FIELDS()) {
			next unless $GlobalSet->can($_);
			next if $UserSet->$_();
			$UserSet->$_($GlobalSet->$_());
		}
	}
	#$timer->continue("merged records");
	#$timer->stop;
	return $UserSet;
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
	
	#my $timer = WeBWorK::Timing->new("getMergedSet");
	
	croak "getGlobalUserSet: requires 3 arguments"
		unless @_ == 4;
	croak "getGlobalUserSet: argument 1 must contain a user_id"
		unless defined $userID;
	croak "getGlobalUserSet: argument 2 must contain a set_id"
		unless defined $setID;
	croak "getGlobalUserSet: argument 3 must contain a problem_id"
		unless defined $problemID;
	
	#$timer->start;
	my $UserProblem = $self->getUserProblem($userID, $setID, $problemID);
	#$timer->continue("got user problem");
	return unless $UserProblem;
	my $GlobalProblem = $self->getGlobalProblem($setID, $problemID);
	#$timer->continue("got global problem");
	if ($GlobalProblem) {
		foreach ($UserProblem->FIELDS()) {
			next unless $GlobalProblem->can($_);
			next if $UserProblem->$_();
			$UserProblem->$_($GlobalProblem->$_());
		}
	}
	#$timer->continue("merged records");
	#$timer->stop;
	return $UserProblem;
}

################################################################################
# debugging
################################################################################

sub dumpDB($$) {
	my ($self, $table) = @_;
	return $self->{$table}->dumpDB();
}

################################################################################
# sanity checking
################################################################################

sub checkKeyfields($) {
	my ($Record) = @_;
	foreach my $keyfield ($Record->KEYFIELDS) {
		my $value = $Record->$keyfield;
		croak "checkKeyfields: $keyfield is empty"
			unless defined $value and $value ne "";
			
		if ($keyfield eq "problem_id") {
			croak "checkKeyfields: invalid characters in $keyfield field: $value (valid characters are [0-9])"
				unless $value =~ m/^\d*$/;
		} else {
			croak "checkKeyfields: invalid characters in $keyfield field: $value (valid characters are [A-Za-z0-9_])"
				unless $value =~ m/^[\w-]*$/;
		}
	}
}

=head1 AUTHOR

Written by Sam Hathaway, sh002i (at) math.rochester.edu.

=cut

1;
