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
use Data::Dumper;
use WeBWorK::Utils qw(runtime_use);

use constant TABLES => qw(password permission key user set set_user problem problem_user);

################################################################################
# constructor
################################################################################

sub new($$) {
	my ($invocant, $ce) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {};
	
	# load the modules required to handle each table, and create driver
	foreach my $table (TABLES) {
		unless (defined $ce->{dbLayout}->{$table}) {
			#warn "ignoring table $table: layout not specified in dbLayout"; # ***
			next;
		}
		
		my $layout = $ce->{dbLayout}->{$table};
		my $record = $layout->{record};
		my $schema = $layout->{schema};
		my $driver = $layout->{driver};
		my $source = $layout->{source};
		my $params = $layout->{params};
		
		runtime_use($record);
		runtime_use($schema);
		runtime_use($driver);
		$self->{$table} = $schema->new($driver->new($source, $params), $table, $record, $params);
	}
	
	bless $self, $class;
	return $self;
}

################################################################################
# password functions
################################################################################

sub listPasswords($) {
	my ($self) = @_;
	return map { $_->[0] }
		$self->{password}->list(undef);
}

sub addPassword($$) {
	my ($self, $Password) = @_;
	die "addPassword failed: user ", $Password->user_id, " does not exist.\n"
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
	return map { $_->[0] }
		$self->{permission}->list(undef);
}

sub addPermissionLevel($$) {
	my ($self, $PermissionLevel) = @_;
	die "addPermissionLevel failed: user ", $PermissionLevel->user_id, " does not exist.\n"
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
	return map { $_->[0] }
		$self->{key}->list(undef);
}

sub addKey($$) {
	my ($self, $Key) = @_;
	die "addKey failed: user ", $Key->user_id, " does not exist.\n"
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
	return map { $_->[0] }
		$self->{user}->list(undef);
}

sub addUser($$) {
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
	return map { $_->[0] }
		$self->{set}->list(undef);
}

sub addGlobalSet($$) {
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
	return map { $_->[1] } # extract set_id
		$self->{set_user}->list($userID, undef);
}

sub addUserSet($$) {
	my ($self, $UserSet) = @_;
	die "addUserSet failed: user ", $UserSet->user_id, " does not exist.\n"
		unless $self->{user}->exists($UserSet->user_id);
	die "addUserSet failed: set ", $UserSet->set_id, " does not exist.\n"
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
			$self->{problem}->list(undef, undef);
}

sub addGlobalProblem($$) {
	my ($self, $GlobalProblem) = @_;
	die "addGlobalProblem failed: set ", $GlobalProblem->set_id, " does not exist.\n"
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
		$self->{problem_user}->list($userID, $setID, undef);
}

sub addUserProblem($$) {
	my ($self, $UserProblem) = @_;
	die "addUserProblem failed: user set ", $UserProblem->set_id, " does not exist.\n"
		unless $self->{set_user}->exists($UserProblem->user_id, $UserProblem->set_id);
	die "addUserProblem failed: problem ", $UserProblem->problem_id, " does not exist.\n"
		unless $self->{problem}->exists($UserProblem->user_id, $UserProblem->set_id);
	return $self->{problem_user}->add($UserProblem);
}

sub getUserProblem($$$$) {
	my ($self, $userID, $setID, $problemID) = @_;
	return $self->{problem_user}->get($userID, $setID, $problemID);
}

sub putUserProblem($$) {
	my ($self, $UserProblem) = @_;
	return $self->{problem_user}->put($UserProblem);
}

sub deleteUserProblem($$$$) {
	my ($self, $userID, $setID, $problemID) = @_;
	return $self->{problem_user}->delete($userID, $setID, $problemID);
}

################################################################################
# set+set_user functions
################################################################################

sub getGlobalUserSet($$$) {
	my ($self, $userID, $setID) = @_;
	my $UserSet = $self->getUserSet($userID, $setID);
	return unless $UserSet;
	my $GlobalSet = $self->getGlobalSet($setID);
	if ($GlobalSet) {
		foreach ($UserSet->FIELDS()) {
			next unless $GlobalSet->can($_);
			next if $UserSet->$_();
			$UserSet->$_($GlobalSet->$_());
		}
	}
	return $UserSet;
}

################################################################################
# problem+problem_user functions
################################################################################

sub getGlobalUserProblem($$$$) {
	my ($self, $userID, $setID, $problemID) = @_;
	my $UserProblem = $self->getUserProblem($userID, $setID, $problemID);
	return unless $UserProblem;
	my $GlobalProblem = $self->getGlobalProblem($setID, $problemID);
	if ($GlobalProblem) {
		foreach ($UserProblem->FIELDS()) {
			next unless $GlobalProblem->can($_);
			next if $UserProblem->$_();
			$UserProblem->$_($GlobalProblem->$_());
		}
	}
	return $UserProblem;
}

################################################################################
# debugging
################################################################################

sub dumpDB($$) {
	my ($self, $table) = @_;
	return $self->{$table}->dumpDB();
}

1;
