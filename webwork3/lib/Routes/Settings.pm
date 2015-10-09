### Library routes
##
#  These are the routes for all library functions in the RESTful webservice
#
##

package Routes::Settings;

our $PERMISSION_ERROR = "You don't have the necessary permissions.";

use strict;
use warnings;
use Utils::CourseUtils qw/getCourseSettings/;
use Utils::Authentication qw/checkPermissions/;
use Utils::GeneralUtils qw/writeConfigToFile getCourseSettingsWW2/;
use Dancer ':syntax';

####
#
#  get /courses/:course_id/settings
#
#  return an array of all course settings
#
###

get '/courses/:course_id/settings' => sub {

	checkPermissions(10,session->{user});

	return getCourseSettings;

};

####
#
#  CRUD for /courses/:course_id/settings/:setting_id
#
#  returns the setting where the var is *setting_id*
#
###

get '/courses/:course_id/settings/:setting_id' => sub {

	checkPermissions(10,session->{user});

	my $ConfigValues = getConfigValues(vars->{ce});

	foreach my $oneConfig (@$ConfigValues) {
		foreach my $hash (@$oneConfig) {
			if (ref($hash)=~/HASH/){
				if ($hash->{var} eq params->{setting_id}){
					if($hash->{type} eq 'boolean'){
						$hash->{value} = $hash->{value} ? JSON::true : JSON::false;
					}
					return $hash;
				}
			}
		}
	}

	return {};
};

## save the setting

put '/courses/:course_id/settings/:setting_id' => sub {

	checkPermissions(10,session->{user});

	#debug "in PUT /course/:course_id/settings/:setting_id";
	
	my $ConfigValues = getCourseSettingsWW2(vars->{ce});
	foreach my $oneConfig (@$ConfigValues) {
		foreach my $hash (@$oneConfig) {
			if (ref($hash)=~/HASH/){
				if ($hash->{var} eq params->{setting_id}){
					if($hash->{type} eq 'boolean'){
						$hash->{value} = params->{value} ? 1 : 0;
					} else {
						$hash->{value} = params->{value};
					}
					return writeConfigToFile(vars->{ce},$hash);
				}
			}
		}
	}

	return {};
};




1;
