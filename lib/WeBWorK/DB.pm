################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB;

=head1 NAME

WeBWorK::DB - interface with the WeBWorK databases (WWDBv2).

=cut

use strict;
use warnings;
use WeBWorK::Utils qw(runtime_use);

use constant TABLES => qw(password permission user set set_user problem problem_user);

################################################################################
# constructor
################################################################################

sub new($$) {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $ce = shift;
	
	# load the modules required to handle each table, and create driver
	foreach my $table (TABLES) {
		die "Layout for table $table not specified in dbLayout.\n"
			unless defined $ce->{dbLayout}->{$table};
		
		my $layout = $ce->{dbLayout}->{$table};
		my $schema = $layout->{schema};
		my $driver = $layout->{driver};
		my $source = $layout->{source};
		
		runtime_use($schema, $driver);
		$self->{$table} = $schema->new($driver->new($source), $table);
	}
	
	bless $self, $class;
	return $self;
}

################################################################################
# password functions
################################################################################

sub listPasswords($) {
	my ($self) = @_;
	return $self->{password}->list();
}

sub newPassword($$) {
	my ($self, $Password) = @_;
	die "newPassword failed: user ", $Password->user_id, " does not exist.\n"
		unless $self->{user}->exists($Password->user_id);
	return $self->{password}->add($Password);
}

sub getPassword($$) {
	my ($self, $userID) = @_;
	return $self->{password}->get($userID);
}

sub putPassword($$) {
	my ($self, $Password) = @_;
	return $self->{password}->put($Password);
}

sub deletePassword($$) {
	my ($self, $userID) = @_;
	return $self->{password}->delete($userID);
}

################################################################################
# permission functions
################################################################################

sub listPermissionLevels($) {
	my ($self) = @_;
	return $self->{permission}->list();
}

sub newPermissionLevel($$) {
	my ($self, $PermissionLevel) = @_;
	die "newPermissionLevel failed: user ", $PermissionLevel->user_id, " does not exist.\n"
		unless $self->{user}->exists($PermissionLevel->user_id);
	return $self->{permission}->add($PermissionLevel);
}

sub getPermissionLevel($$) {
	my ($self, $userID) = @_;
	return $self->{permission}->get($userID);
}

sub putPermissionLevel($$) {
	my ($self, $PermissionLevel) = @_;
	return $self->{permission}->put($PermissionLevel);
}

sub deletePermissionLevel($$) {
	my ($self, $userID) = @_;
	return $self->{permission}->delete($userID);
}

################################################################################
# key functions
################################################################################

sub listKeys($) {
	my ($self) = @_;
	return $self->{key}->list();
}

sub newKey($$) {
	my ($self, $Key) = @_;
	die "newKey failed: user ", $Key->user_id, " does not exist.\n"
		unless $self->{user}->exists($Key->user_id);
	return $self->{key}->add($Key);
}

sub getKey($$) {
	my ($self, $userID) = @_;
	return $self->{key}->get($userID);
}

sub putKey($$) {
	my ($self, $Key) = @_;
	return $self->{key}->put($Key);
}

sub deleteKey($$) {
	my ($self, $userID) = @_;
	return $self->{key}->delete($userID);
}

################################################################################
# user functions
################################################################################

sub listUsers($) {
	my ($self) = @_;
	return $self->{user}->list();
}

sub newUser($$) {
	my ($self, $User) = @_;
	return $self->{user}->add($User);
}

sub getUser($$) {
	my ($self, $userID) = @_;
	return $self->{user}->get($userID);
}

sub putUser($$) {
	my ($self, $User) = @_;
	return $self->{user}->put($User);
}

sub deleteUser($$) {
	my ($self, $userID) = @_;
	$self->deletePassword($userID);
	$self->deletePermissionLevel($userID);
	$self->deleteKey($userID);
	$self->deleteUserSet($userID, $_)
		foreach $self->listUsers();
	return $self->{user}->delete($userID);
}

################################################################################
# set functions
################################################################################

sub listGlobalSets($) {
	my ($self) = @_;
	return $self->{set}->list();
}

sub newGlobalSet($$) {
	my ($self, $GlobalSet) = @_;
	return $self->{set}->add($GlobalSet);
}

sub getGlobalSet($$) {
	my ($self, $setID) = @_;
	return $self->{set}->get($setID);
}

sub putGlobalSet($$) {
	my ($self, $GlobalSet) = @_;
	return $self->{set}->put($GlobalSet);
}

sub deleteGlobalSet($$) {
	my ($self, $setID) = @_;
	$self->deleteGlobalProblem($setID, $_)
		foreach $self->listGlobalProblems($setID);
	$self->deleteUserSet($_, $setID)
		foreach $self->listUsers();
	return $self->{set}->delete($setID);
}

################################################################################
# set_user functions
################################################################################

sub listUserSets($) {
	my ($self, $userID) = @_;
	return map { $_->[1] }
		grep { $_->[0] eq $userID }
			$self->{set_user}->list();
}

sub newUserSet($$) {
	my ($self, $UserSet) = @_;
	die "newUserSet failed: user ", $UserSet->user_id, " does not exist.\n"
		unless $self->{user}->exists($UserSet->user_id);
	die "newUserSet failed: set ", $UserSet->set_id, " does not exist.\n"
		unless $self->{set}->exists($UserSet->set_id);
	return $self->{set_user}->add($UserSet);
}

sub getUserSet($$) {
	my ($self, $userID, $setID) = @_;
	return $self->{set_user}->get($userID, $setID);
}

sub putUserSet($$) {
	my ($self, $UserSet) = @_;
	return $self->{set_user}->put($UserSet);
}

sub deleteUserSet($$) {
	my ($self, $userID, $setID) = @_;
	$self->deleteUserProblem($userID, $setID, $_)
		foreach $self->listUserProblems($userID, $setID);
	return $self->{set_user}->delete($userID, $setID);
}

################################################################################
# problem functions
################################################################################

sub listGlobalProblems($$) {
	my ($self, $setID) = @_;
	return map { $_->[1] }
		grep { $_->[0] eq $setID }
			$self->{problem}->list();
}

sub newGlobalProblem($$) {
	my ($self, $GlobalProblem) = @_;
	die "newGlobalProblem failed: set ", $GlobalProblem->set_id, " does not exist.\n"
		unless $self->{set}->exists($GlobalProblem->set_id);
	return $self->{problem}->add($GlobalProblem);
}

sub getGlobalProblem($$$) {
	my ($self, $setID, $problemID) = @_;
	return $self->{problem}->get($problemID);
}

sub putGlobalProblem($$) {
	my ($self, $GlobalProblem) = @_;
	return $self->{problem}->put($GlobalProblem);
}

sub deleteGlobalProblem($$$) {
	my ($self, $setID, $problemID) = @_;
	$self->deleteUserProblem($_, $setID, $problemID)
		foreach $self->listUsers();
	return $self->{problem}->delete($setID, $problemID);
}

################################################################################
# problem_user functions
################################################################################

sub listUserProblems($$$) {
	my ($self, $userID, $setID) = @_;
	return map { $_->[2] }
		grep { $_->[0] eq $userID and $_->[1] eq $setID }
			$self->{problem_user}->list();
}

sub newUserProblem($$) {
	my ($self, $UserProblem) = @_;
	die "newUserProblem failed: user set ", $UserProblem->set_id, " does not exist.\n"
		unless $self->{set_user}->exists($UserProblem->set_id);
	die "newUserProblem failed: problem ", $UserProblem->problem_id, " does not exist.\n"
		unless $self->{problem}->exists($UserProblem->set_id);
	return $self->{problem_user}->add($UserProblem);
}

sub getUserProblem($$) {
	my ($self, $userID, $setID, $problemID) = @_;
	return $self->{problem_user}->get($userID, $setID, $problemID);
}

sub putUserProblem($$) {
	my ($self, $UserProblem) = @_;
	return $self->{problem_user}->put($UserProblem);
}

sub deleteUserProblem($$) {
	my ($self, $userID, $setID, $problemID) = @_;
	return $self->{problem_user}->delete($userID, $setID, $problemID);
}

################################################################################
# set+set_user functions
################################################################################

# ***

################################################################################
# problem+problem_user functions
################################################################################

# ***

1;
