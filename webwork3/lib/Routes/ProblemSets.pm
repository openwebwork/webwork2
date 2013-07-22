### Course routes
##
#  These are the routes for all /course URLs in the RESTful webservice
#
##

package Routes::ProblemSets;

use strict;
use warnings;
use Dancer ':syntax';
use Routes qw/convertObjectToHash/;

prefix '/courses';

###
#  return all users for course :course
#
#  User user_id must have at least permissions>=10
#
##

get '/:course_id/sets' => sub {

	if( ! session 'logged_in'){
		return { error=>"You need to login in again."};
	}

	if (0+(session 'permission') < 10 && param('user') ne param('user_id')) {
		return {error=>"You don't have the necessary permission"};
	}

    my $db = vars->{db};

    my @userSetNames = $db->listUserSets(param('user'));
	debug(@userSetNames);
  	
  	my @userSets = $db->getGlobalSets(@userSetNames);
    
    return \@userSetNames;
};


return 1;