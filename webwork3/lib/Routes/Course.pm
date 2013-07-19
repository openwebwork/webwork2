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

prefix '/course';

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
    return Routes::convertObjectToHash(\@allUsers);
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

	return Routes::convertObjectToHash(\@globalSets);
};

put '/:course/users/:new_user' => sub {
	if( ! session 'logged_in'){
		return { error=>"You need to login in again."};
	}

	if (0+(session 'permission') < 10) {
		return {error=>"You don't have the necessary permission"};
	}

	debug("addings a new user with user_id: " . param('new_user'));

	return "Hi";

};

return 1;