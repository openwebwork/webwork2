package WeBWorK::ContentGenerator::Instructor;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Instructor - Abstract superclass for the Instructor pages

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::DB::Utils qw(global2user initializeUserProblem);

sub hiddenEditForUserFields {
	my ($self, @editForUser) = @_;
	my $return = "";
	foreach my $editUser (@editForUser) {
		$return .= CGI::input({type=>"hidden", name=>"editForUser", value=>$editUser});
	}
	
	return $return;
}

sub userCountMessage {
	my ($self, $count, $numUsers) = @_;
	
	my $message;
	if ($count == 0) {
		$message = CGI::em("no users");
	} elsif ($count == $numUsers) {
		$message = "all users";
	} elsif ($count == 1) {
		$message = "1 user";
	} elsif ($count > $numUsers || $count < 0) {
		$message = CGI::em("an impossible number of users: $count out of $numUsers");
	} else {
		$message = "$count users";
	}
	
	return $message;
}

### Utility functions for assigning sets to users.
# These silently fail if the problem or set exists for the user.

sub assignProblemToUser {
	my ($self, $user, $globalProblem) = @_;
	my $db = $self->{db};
	my $userProblem = $db->{problem_user}->{record}->new;

	# Set up the key
	$userProblem->user_id($user);
	$userProblem->set_id($globalProblem->set_id);
	$userProblem->problem_id($globalProblem->problem_id);
	
	initializeUserProblem($userProblem);
	eval {$db->addUserProblem($userProblem)};
}

sub assignSetToUser {
	my ($self, $user, $globalSet) = @_;
	my $db = $self->{db};
	my $userSet = $db->{set_user}->{record}->new;
	my $setID = $globalSet->set_id;

	$userSet->user_id($user);
	$userSet->set_id($setID);
	eval {$db->addUserSet($userSet)};
	
	foreach my $problemID ($db->listGlobalProblems($setID)) {
		my $problemRecord = $db->getGlobalProblem($setID, $problemID);
		$self->assignProblemToUser($user, $problemRecord);
	}
}

# When a new problem is added to a set, all students to whom the set 
# it belongs to is assigned should have it assigned to them.
# Note that this does NOT assign to all users of a course, just all users
# of a set.
sub assignProblemToAllUsers {
	my ($self, $globalProblem) = @_;
	my $db = $self->{db};
	my $setID = $globalProblem->set_id;
	my @users = $db->listSetUsers($setID);
	
	foreach my $user (@users) {
		$self->assignProblemToUser($user, $globalProblem);
	}
}

# READ THIS: Unlike the above function, "All" here refers to all of the
# users of a course.
# This function caches database data as a speed optimization.
sub assignSetToAllUsers {
	my ($self, $setID) = @_;
	my $db = $self->{db};
	my @problems = ();
	my @users = $db->listUsers($setID);
	my @problemRecords = map {$db->getGlobalProblem($setID, $_)} $db->listGlobalProblems($setID);
	
	foreach my $user (@users) {
		# FIXME: Create a UserSet record for the user!!!!
		my $userSet = $db->{set_user}->{record}->new;
		$userSet->user_id($user);
		$userSet->set_id($setID);
		eval {$db->addUserSet($userSet)};
		foreach my $problemRecord (@problemRecords) {
			$self->assignProblemToUser($user, $problemRecord);
		}
	}
}

## Template Escapes ##

sub links {
 	my $self 		= shift;
 	
 	# keep the links from the parent
 	my $pathString 	= "";
 	
	
	my $ce = $self->{ce};
	my $db = $self->{db};
	my $userName = $self->{r}->param("user");
	my $courseName = $ce->{courseName};
	my $root = $ce->{webworkURLs}->{root};
	my $permLevel = $db->getPermissionLevel($userName)->permission();
	my $key = $db->getKey($userName)->key();
	return "" unless defined $key;
	
	# new URLS
	my $classList	= "$root/$courseName/instructor/users/?". $self->url_authen_args();
	my $addStudent  = "$root/$courseName/instructor/addStudent/?". $self->url_authen_args();
	my $problemSetList = "$root/$courseName/instructor/sets/?". $self->url_authen_args();
	
	if ($permLevel > 0 ) {
		$pathString .="<hr>";
		$pathString .=  CGI::a({-href=>$classList}, "Class&nbsp;editor") . CGI::br();
		$pathString .=  '&nbsp;&nbsp;'.CGI::a({-href=>$addStudent}, "Add&nbsp;Student") . CGI::br();
		$pathString .= CGI::a({-href=>$problemSetList}, "ProbSet&nbsp;list") . CGI::br();
	}
	return $self->SUPER::links() . $pathString;
}

1;
