package WeBWorK::ContentGenerator::Instructor;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Instructor - Abstract superclass for the Instructor pages

=cut

use strict;
use warnings;
use CGI qw();

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

sub assignProblemToUser {
	my ($self, $user, $globalProblem) = @_;
	my $db = $self->{db};
	my $userProblem = $db->{problem_user}->{record}->new;
	# Set up the key
	$userProblem->user_id($user);
	$userProblem->set_id($globalProblem->set_id);
	$userProblem->problem_id($globalProblem->problem_id);
	
	# Initialize user-only fields
	$userProblem->status(0.0);
	$userProblem->attempted(0);
	$userProblem->num_correct(0);
	$userProblem->num_incorrect(0);
	$userProblem->attempted(0);
	$userProblem->problem_seed(int(rand(5000)));
	
	$db->addUserProblem($userProblem);
}

sub assignSetToUser {
	my ($self, $user, $globalSet) = @_;
	my $db = $self->{db};
	my $userSet = $db->{set_user}->{record}->new;
	my $setID = $globalSet->set_id;

	$userSet->user_id($user);
	$userSet->set_id($setID);
	$db->addUserSet($userSet);
	
	foreach my $problemID ($db->listGlobalProblems) {
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
