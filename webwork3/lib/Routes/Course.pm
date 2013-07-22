### Course routes
##
#  These are the routes for all /course URLs in the RESTful webservice
#
##

package Routes::Course;

use strict;
use warnings;
use Dancer ':syntax';
use Routes qw/convertObjectToHash/;
use WeBWorK::Utils qw(cryptPassword);

prefix '/courses';

###
#  return all users for course :course
#
#  User user_id must have at least permissions>=10
#
##

get '/:course/users' => sub {

	if( ! session 'logged_in'){
		return { error=>"You need to login in again."};
	}

	if (0+(session 'permission') < 10) {
		return {error=>"You don't have the necessary permission"};
	}

    my $ce = vars->{ce};
    my $db = vars->{db};


    my @allUsers = $db->getUsers($db->listUsers);
    my %permissionsHash =  reverse %{$ce->{userRoles}};
    foreach my $u (@allUsers)
    {
        my $PermissionLevel = $db->getPermissionLevel($u->{'user_id'});
        $u->{'permission'} = $PermissionLevel->{'permission'};

		my $studid= $u->{'student_id'};
		$u->{'student_id'} = "$studid";  # make sure that the student_id is returned as a string. 
		
    }
    return Routes::convertArrayOfObjectsToHash(\@allUsers);
};

get '/:course/sets' => sub {

	if( ! session 'logged_in'){
		return { error=>"You need to login in again."};
	}

	if (0+(session 'permission') < 10) {
		return {error=>"You don't have the necessary permission"};
	}

	my $db = vars->{db};
 	my @globalSets = $db->getGlobalSets($db->listGlobalSets);
  	foreach my $set (@globalSets){
		my @users = $db->listSetUsers($set->{set_id});
		$set->{assigned_users} = \@users;
	}

	return Routes::convertArrayOfObjectsToHash(\@globalSets);
};

##
#
#  Returns all users for course course_id and set set_id
#
#  return:  array of user_id's.
##


get '/:course_id/sets/:set_id/users' => sub {
	if( ! session 'logged_in'){
		return { error=>"You need to login in again."};
	}

	if (0+(session 'permission') < 10) {
		return {error=>"You don't have the necessary permission"};
	}

	my @sets = vars->{db}->listSetUsers(param('set_id'));
	return \@sets;
};

###
#
#  create a new user user_id in course *course_id*
#
###


post '/:course_id/users/:user_id' => sub {
	if( ! session 'logged_in'){
		return { error=>"You need to login in again."};
	}

	if (0+(session 'permission') < 10) {
		return {error=>"You don't have the necessary permission"};
	}

	debug("adding a new user with user_id: " . param('user_id'));


	my $user = vars->{db}->getUser(param('user_id'));
	return {error=>"The user with login " . param('user_id') . " already exists"} if $user;

	my $new_student = vars->{db}->{user}->{record}->new();
	my $enrolled = vars->{ce}->{statuses}->{Enrolled}->{abbrevs}->[0];
	$new_student->user_id(param('user_id'));
	$new_student->first_name(param('first_name'));
	$new_student->last_name(param('last_name'));
	$new_student->status($enrolled);
	$new_student->student_id(param('student_id'));
	$new_student->email_address(param('email_address'));
	$new_student->recitation(param('recitation'));
	$new_student->section(param('section'));
	$new_student->comment(param('comment'));
	
	# password record
	my $cryptedpassword = "";
	if (param('password')) {
		$cryptedpassword = cryptPassword(param('password'));
	}
	elsif ($new_student->student_id()) {
		$cryptedpassword = cryptPassword($new_student->student_id());
	}
	my $password = vars->{db}->newPassword(user_id => param('user_id'));
	$password->password($cryptedpassword);
	
	# permission record
	my $permission = param('permission') || "";
	if (defined(vars->{ce}->{userRoles}{$permission})) {
		$permission = vars->{ce}->newPermissionLevel(
			user_id => param('user_id'), 
			permission => vars->{ce}->{userRoles}{$permission});
	}
	else {
		$permission = vars->{db}->newPermissionLevel(user_id => param('user_id'), 
			permission => vars->{ce}->{userRoles}{student});
	}

	my @messages = ();
	eval{ vars->{db}->addUser($new_student); };
	if ($@) {
		push(@messages,"Add user for " . param('user_id') . " failed!");
	}
	
	eval { vars->{db}->addPassword($password); };
	if ($@) {
		push(@messages,"Add password for " . param('user_id') . " failed!");
	}
	
	eval { vars->{db}->addPermissionLevel($permission); };
	if ($@) {
		push(@messages,"Add permission for " . param('user_id') . " failed!");
	}

	if (scalar(@messages)>0) {
		return {error=>"Attempt to add user failed", message=>\@messages};
	} else {
		return Routes::convertObjectToHash($new_student);
	}
};



###
#
#  create a new user user_id in course *course_id*
#
###


del '/:course_id/users/:user_id' => sub {
	if( ! session 'logged_in'){
		return { error=>"You need to login in again."};
	}

	if (0+(session 'permission') < 10) {
		return {error=>"You don't have the necessary permission"};
	}

	debug("Deleting user with user_id: " . param('user_id'));

	# check to see if the user exists

	my $user = vars->{db}->getUser(param('user_id')); # checked
	return {error=>"Record for visible user " . param('user_id') . ' not found.'} unless $user;

	if (param('user_id') eq param('user') )
	{
		return {error=>"You can't delete yourself from the course."};
	} 

	my $del = vars->{db}->deleteUser(param('user_id'));
		
	if($del) {
		return {success=>"User with login " . param('user_id') . ' successfully deleted.'};
	} else {
		return {error=>"User with login " . param('user_id') . ' could not be deleted.'};
	}

};

return 1;