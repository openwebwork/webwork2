################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2012 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: /webwork/cvs/system/webwork2/lib/WeBWorK/Authen/LTIBasic.pm,v 1.1 2012/05/17 18:50:11 wheeler Exp $
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

package WeBWorK::Authen::LTIBasic;
use base qw/WeBWorK::Authen/;

=head1 NAME

WeBWorK::Authen::LTIBasic - Authenticate from a Learning Management System
via the IMS LTI Basic/OAuth protocol.

=cut

use strict;
use warnings;
use Carp;
use WeBWorK::Debug;
use DBI;
use WeBWorK::CGI;
use WeBWorK::Utils qw(formatDateTime);
use WeBWorK::Localize;
use URI::Escape;
use Net::OAuth;
use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

$Net::OAuth::PROTOCOL_VERSION = Net::OAuth::PROTOCOL_VERSION_1_0A;

#$WeBWorK::Debug::Enabled = 1;

BEGIN {
	if (MP2) {
		require APR::SockAddr;
		APR::SockAddr->import();
		require Apache2::Connection;
		Apache2::Connection->import();
		require APR::Request::Error;
		APR::Request::Error->import;
	}
}

our $GENERIC_ERROR_MESSAGE = 
	"Your authentication failed.  Please return to "
	. "your Course Management System (e.g., Oncourse, Moodle, "
	. "Blackboard, Canvas, Sakai, etc.)  and login again.";
our $GENERIC_MISSING_USER_ID_ERROR_MESSAGE = 
	"Your authentication failed.  Please return to "
	. "your Course Management System (e.g., Oncourse, Moodle, "
	. "Blackboard, Canvas, Sakai, etc.)  and login again.";
our $GENERIC_DENIED_LOGIN_ERROR_MESSAGE = 
	"You are not permitted to login into this site at this time. "
	. "Please speak with your instructor.";
our $GENERIC_UNKNOWN_USER_ERROR_MESSAGE = 
	"This username does not appear on the roster for this WeBWorK site." ;
our $GENERIC_UNKNOWN_INSTRUCTOR_ERROR_MESSAGE = 
	"You have attemped to access this site as an instructor without prior authorization.";

=head1 CONSTRUCTOR

=over

=item new($r)

Instantiates a new WeBWorK::Authen object for the given WeBWorK::Requst ($r).

=cut

sub new {
	my ($invocant, $r) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {
		r => $r,
	};
	#initialize
	bless $self, $class;
	return $self;
}

=back

=cut




## this is only overridden for debug logging
#sub verify {
#	debug("BEGIN LTIBasic VERIFY");
#	my $result = $_[0]->SUPER::verify(@_[1..$#_]);
#	debug("END LTIBasic VERIFY");
#	return $result;
#}

# This module is similar to the base class, with these differences:
#  1. no WeBWorK guest/practice logins
#  2. uses the Key database to store nonces, where
#     the $Key -> username = the nonce
#         $Key -> key = "nonce"
#         $Key -> timestamp = the nonce's timestamp
#  3. when this method is used, there needs to be a CRON job
#     to delete old nonce records 
#  4. A program ww_purge_old_nonces is available for
#     deleting old nonce records.  It should be placed
#     in webwork2/system/bin

########
#  Example of parameters forwarded by a Course Management System
#user_id=wheeler
#roles=Instructor
#
#lis_person_name_full=William+H.+Wheeler
#lis_person_name_family=Wheeler
#lis_person_contact_email_primary=wheeler%40indiana.edu
#lis_person_sourcedid=wheeler
#lis_person_name_given=William+H.
#
#basiclti_submit=Press+to+continue+to+external+tool.
#lti_version=LTI-1p0
#lti_message_type=basic-lti-launch-request
#
#context_id=a75a6608-3698-4b62-803d-063040fce113
#context_title=Math+Tools+Pages
#context_label=Math+Tools+Pages
#
#resource_link_description=Linking+to+WeBWorK%40IU
#resource_link_id=109f9125-c711-4151-8601-4567518aed82
#resource_link_title=WeBWorK+LTI
#
#launch_presentation_locale=en_US
#
#ext_sakai_serverid=esappo06
#ext_sakai_server=https%3A%2F%2Foncourse.iu.edu
#ext_sakai_session=8991b6d6c83c085f5ebb8707048e6631c946310870d6147e9e5e619b0686dafc736891ace760a6b8
#
#oauth_version=1.0
#oauth_consumer_key=webwork
#oauth_signature=fxcs0nuFgvSGQGnJck59Y2w8VHs%3D
#oauth_nonce=201683935212232
#oauth_signature_method=HMAC-SHA1
#oauth_callback=about%3Ablank
#oauth_timestamp=1309888775
#
#custom_semster=?
#custom_section=?

sub  request_has_data_for_this_verification_module {
	#debug("LTIBasic has been called for data verification");
	my $self = shift;
	my $r = $self -> {r};

	# See comment in get_credentials()
	if ($r->{xmlrpc}) {
		#debug("LTIBasic returning 1 because it is an xmlrpc call");
		return 1;
	}
	if (!(defined $r->param("oauth_consumer_key"))
			or !(defined $r -> param("oauth_signature"))
			or !(defined $r -> param("oauth_nonce"))
			or !(defined $r -> param("oauth_timestamp")) ) {
		#debug("LTIBasic returning that it has insufficent data");
		return(0);
	} else {
		#debug(("LTIBasic returning that it has sufficient data");
		return(1);
	}
}

sub get_credentials {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $r -> {ce};
	
	#debug("LTIBasic::get_credentials has been called\n");
	
	## debug code MEG
	if ( $ce->{debug_lti_parameters} ) {
		my $rh_headers = $r->headers_in;  #request headers
	
		my @parameter_names = $r->param;       # form parameter names
		my $parameter_report = '';
		foreach my $key (@parameter_names) {
			$parameter_report .= "$key => ".$r->param($key). "\n";
		}
		warn ("===== parameters received =======\n", $parameter_report);
	}
	###
	
	
	
	
	#disable password login
	$self->{external_auth} = 1;

	# This next part is necessary because some parts of webwork (e.g.,
	# WebworkWebservice.pm) need to replace the get_credentials() routine,
	# but only replace the one in the parent class (out of caution,
	# presumably).  Therefore, we end up here even when authenticating
	# for WebworkWebservice.pm.  This would cause authentication failures
	# when authenticating javascript web service requests (e.g., the
	# Library Browser).
	# Similar changes are needed in check_user() and verify_normal_user().

	if ($r->{xmlrpc}) {
		#debug("falling back to superclass get_credentials (xmlrpc call)");
		return $self->SUPER::get_credentials(@_);
	}

	# if at least the user ID is available in request parameters
	if (defined $r->param("user_id")) 
		{
		map {$self -> {$_ -> [0]} = $r -> param($_ -> [1]);} 
						(
						#['user_id', 'lis_person_sourcedid'],
						['role', 'roles'],
						['last_name' , 'lis_person_name_family'],
						['first_name', 'lis_person_name_given'],
						['context_id', 'context_id'],
						['oauth_consumer_key', 'oauth_consumer_key'],
						['oauth_signature', 'oauth_signature'],
						['oauth_nonce', 'oauth_nonce'],
						['oauth_timestamp', 'oauth_timestamp'],
						['semester', 'custom_semester'],
						['section', 'custom_section'],
						['recitation', 'custom_recitation'],
						);

		# The following lines were substituted for the commented out line above
		# because some LMS's misspell the lis_person_sourcedid parameter name
		if (defined($r -> param("lis_person_sourced_id"))) {
			$self -> {user_id} = $r -> param("lis_person_sourced_id"); 
		} elsif (defined($r -> param("lis_person_sourcedid"))) {
			$self -> {user_id} = $r -> param("lis_person_sourcedid"); 
		} elsif (defined($r -> param("lis_person_source_id"))) {
			$self -> {user_id} = $r -> param("lis_person_source_id"); 
		} elsif (defined($r -> param("lis_person_sourceid"))) {
			$self -> {user_id} = $r -> param("lis_person_sourceid"); 
		} else {
			undef($self ->{user_id});
		}
		###############
		# if get_username_from_email == 1 then replace user_id with the full email address if possible 
		# or if the user_id is still undefined try to set the user_id to full the email address
		
		$self -> {email} = uri_unescape($r -> param("lis_person_contact_email_primary"));
# 		if (!defined($self->{user_id})
# 		    or defined($self -> {email}) and $ce -> {get_username_from_email} )  {
# 		    $self->{user_id} = $self -> {email};
# 
# 		}
		
		#############
		# if preferred_source_of_username eq "lis_person_contact_email_primary"
		# then replace the user_id with the full email address. 
		
		# or if the user_id is still undefined try to set the user_id to full the email address
		
		# if strip_address_from_email ==1  strip off the part of the address after @
		#############
		if (!defined($self->{user_id})
			or (defined($self -> {email})  
				and defined($ce -> {preferred_source_of_username})
				and $ce -> {preferred_source_of_username} eq "lis_person_contact_email_primary")) {
			$self->{user_id} = $self -> {email};
			$self->{user_id} =~ s/@.*$// if
			    $ce->{strip_address_from_email};
		}
		# MEG debug code
		if ( $ce->{debug_lti_parameters} ) {
			warn "=========== summary ============";
			warn "User id is |$self->{user_id}|\n";
			warn "User mail address is |$self->{email}|\n";
			warn "strip_address_from_email is |", $ce->{strip_address_from_email}//0,"|\n";
			warn "preferred_source_of_username is |", $ce -> {preferred_source_of_username}//'undefined',"|\n";
			warn "================================\n";
		 }
		if (!defined($self->{user_id})) {
			croak "LTIBasic was unable to create a username from the user_id or from the mail address.
			       Set \$debug_lti_parameters=1 in authen_LTI.conf to debug";
		}
		if (defined $ce -> {analyze_context_id}) {
			$ce -> {analyze_context_id} ($self) ;
		}
		if (!defined($self -> {section})) {
			$self -> {section} = "unknown";
		}
		$self->{login_type} = "normal";
		$self -> {credential_source} = "LTIBasic";
		#debug("LTIBasic::get_credentials is returning a 1\n");
		return 1;
		}
	#debug("LTIBasic::get_credentials is returning a 0\n");
	return 0;
}

# minor modification of method in superclass
sub check_user {
	my $self = shift;
	my $r = $self->{r};
	my ($ce, $db, $authz) = map {$r -> $_ ;} ('ce', 'db', 'authz');
	
	my $user_id = $self->{user_id};

	#debug("LTIBasic::check_user has been called for user_id = |$user_id|");

	# See comment in get_credentials()
	if ($r->{xmlrpc}) {
		#debug("falling back to superclass check_user (xmlrpc call)");
		return $self->SUPER::check_user(@_);
	}

	if (!defined($user_id) or (defined $user_id and $user_id eq "")) {
		$self->{log_error} .= "no user id specified";
		$self->{error} = $r->maketext($GENERIC_MISSING_USER_ID_ERROR_MESSAGE);
		return 0;
	}
	
	my $User = $db->getUser($user_id);
	
	if (!$User) {
		if ( defined($r -> param("lis_person_sourcedid"))
			or defined($r -> param("lis_person_sourced_id"))
			or defined($r -> param("lis_person_source_id"))
			or defined($r -> param("lis_person_sourceid")) 
			or defined($r -> param("lis_person_contact_email_primary")) ) {
			#debug("User |$user_id| is unknown but may be an new user from an LSM via LTI.  About to return a 1");
			return 1;  #This may be a new user coming in from a LMS via LTI.
		} else {
		$self->{log_error} .= " $user_id - user unknown";
		$self->{error} = $r->maketext("Username presented:  [_1]",$user_id)."<br/>". $r->maketext($GENERIC_UNKNOWN_USER_ERROR_MESSAGE);
		return 0;
		}
	}

	unless ($ce->status_abbrev_has_behavior($User->status, "allow_course_access")) {
		$self->{log_error} .= "LOGIN FAILED $user_id - course access denied";
		$self->{error} = $r->maketext($GENERIC_DENIED_LOGIN_ERROR_MESSAGE);
		return 0;
	}
	
	unless ($authz->hasPermissions($user_id, "login")) {
		$self->{log_error} .= "LOGIN FAILED $user_id - no permission to login";
		$self->{error} = $r->maketext($GENERIC_DENIED_LOGIN_ERROR_MESSAGE);
		return 0;
	}
	#debug("LTIBasic::check_user is about to return a 1.");	
	return 1;
}

# disable practice users
sub verify_practice_user { return(0) ;}

sub verify_normal_user 
{
	my $self = shift;
	my ($r, $user_id, $session_key) 
			= map {$self -> {$_};} ('r', 'user_id', 'session_key');


	#debug("LTIBasic::verify_normal_user called for user |$user_id|");

	# See comment in get_credentials()
	if ($r->{xmlrpc}) {
		#debug("falling back to superclass verify_normal_user (xmlrpc call)");
		return $self->SUPER::verify_normal_user(@_);
	}

    # Call check_session in order to destroy any existing session cookies and Key table sessions
	my ($sessionExists, $keyMatches, $timestampValid) = $self->check_session($user_id, $session_key, 0);
	debug("sessionExists='", $sessionExists, "' keyMatches='", $keyMatches, "' timestampValid='", $timestampValid, "'");
	
	my $auth_result = $self->authenticate;

	#debug("auth_result=|${auth_result}|");	

	# Parameters CANNOT be modified until after LTIBasic authentication
	# has been done, because the parameters passed with the request

	# are used in computing the OAuth_signature.  If there

	# are any changes in $r -> {paramcache} (see Request.pm)
	# before authentication occurs, then authentication will FAIL
	# even if the consumer_secret is correct.

	$r -> param("user" => $user_id);

	if ($auth_result eq "1") 
		{
		#debug("About to call create_session.");
		$self->{session_key} = $self->create_session($user_id);
		#debug("session_key=|" . $self -> {session_key} . "|.");
		return 1;
		}
	else  
		{
		$self->{error} = $r->maketext($auth_result);
		$self-> {log_error} .= "$user_id - authentication failed: ". $self->{error};
		return 0;
		} 
}

sub authenticate
{
	my $self = shift;
	my ($r, $user ) = map {$self -> {$_};} ('r', 'user_id');
	
	# See comment in get_credentials()
	if ($r->{xmlrpc}) {
		#debug("falling back to superclass authenticate (xmlrpc call)");
		return $self->SUPER::authenticate(@_);
	}

	#debug("LTIBasic::authenticate called for user |$user|");
	#debug "ref(r) = |". ref($r) . "|";
	#debug "ref of r->{paramcache} = |" . ref($r -> {paramcache}) . "|";
	#debug "request_method = |" . $r -> request_method . "|";
	my $ce = $r -> ce;
	my $db = $r -> db;
	my $courseName = $r -> ce -> {'courseName'};
	my $webmaster= $ce ->{Local_Email_Addresses} -> {Webmaster};
	my $verify_code=0;
	my $timestamp=0;

	# Check nonce to see whether request is legitimate
	#debug("Nonce = |" . $self-> {oauth_nonce} . "|");
	my $nonce = WeBWorK::Authen::LTIBasic::Nonce -> new($r, $self -> {oauth_nonce}, $self -> {oauth_timestamp}); 
	if (!($nonce -> ok ) )
		{
		#debug( "eval failed: ", $@, "<br /><br />"; print_keys($r);); 
		$self -> {error} .= $r->maketext($GENERIC_ERROR_MESSAGE
				. ":  Something was wrong with your Nonce LTI parameters.  If this recurs, please speak with your instructor");
		return 0;
		}
	#debug( "r->param(oauth_signature) = |" . $r -> param("oauth_signature") . "|");
	my %request_hash;
	my @keys = keys %{$r-> {paramcache}};
	foreach my $key (@keys) {
		$request_hash{$key} =  $r -> param($key); 
		#debug("$key -> |" . $requestHash -> {$key} . "|");
	}	
	my $requestHash = \%request_hash;
	my $path = $ce->{server_root_url}.$ce->{webwork_url}.$r->urlpath()->path;
	$path = $ce->{LTIBasicToThisSiteURL} ? 
	    $ce->{LTIBasicToThisSiteURL} : $path;
	
	my $altpath = $path;
	$altpath =~ s/\/$//;

	my ($request, $altrequest);
	eval 
		{ 
		$request = Net::OAuth -> request("request token") -> from_hash($requestHash,
			request_url => $path,
									       
        		request_method => "POST",                                    
        		consumer_secret => $ce -> {LTIBasicConsumerSecret},
        	);

		$altrequest = Net::OAuth -> request("request token") -> from_hash($requestHash,
			request_url => $altpath,
									       
        		request_method => "POST",                                    
        		consumer_secret => $ce -> {LTIBasicConsumerSecret},
        	);
		};

	if ($@) 
		{
		#debug("construction of Net::OAuth object failed: $@");
		#debug( "eval failed: ", $@, "<br /><br />"; print_keys($r);); 
		$self -> {error} .= $r->maketext("Your authentication failed.  Please return to Oncourse and login again.");
		$self -> {error} .= $r->maketext("Something was wrong with your LTI parameters.  If this recurs, please speak with your instructor");
		$self -> {log_error} .= "Construction of OAuth request record failed";
		return 0;
		}
	else
		{
		if (! $request -> verify && ! $altrequest -> verify) 
			{
			#debug("LTIBasic::authenticate request-> verify failed");
			#debug("<h2> OAuth verification Failed</h2> "; print_keys($r));
			$self -> {error} .= $r->maketext("Your authentication failed.  Please return to Oncourse and login again.");
			$self -> {error} .= $r->maketext("Your LTI OAuth verification failed.  If this recurs, please speak with your instructor");
			$self -> {log_error} .= "OAuth verification failed.  Check the Consumer Secret.";
			return 0;
			}
		else
			{
			#debug("<h2> OAuth verification SUCCEEDED !! </h2>");
			############################################################
			# Determine the roles defined for this user by the LTI request
			# and assign a permission level on that basis.
			############################################################
			my $userID = $self->{user_id};
			my $LTIrolesString = $r -> param("roles");
			my @LTIroles = split /,/, $LTIrolesString;

			#remove the urn string if its present
			s/^urn:lti:.*:ims\/lis\/// for @LTIroles;
			if ( $ce->{debug_lti_parameters} ) {
				warn "The adjusted LTI roles defined for this user are: \n--",
				       join("\n--", @LTIroles), "\n",
				       "Any initial ^urn:lti:.*:ims/lis/ segments have been stripped off.\n",
				       "The user will be assigned the highest role defined for them\n",
				       "========================\n"		
			}
			
			my $nr = scalar(@LTIroles);
			if (! defined($ce -> {userRoles} -> {$ce -> {LMSrolesToWeBWorKroles} -> {$LTIroles[0]}})) {
				croak("Cannot find a WeBWorK role that corresponds to the LMS role of "
						. $LTIroles[0] .".");
			}
			my $LTI_webwork_permissionLevel 
				= $ce -> {userRoles} -> {$ce -> {LMSrolesToWeBWorKroles} -> {$LTIroles[0]}};
			if ($nr > 1) {
				for (my $j =1; $j < $nr; $j++) {
					my $wwRole = $ce -> {LMSrolesToWeBWorKroles} -> {$LTIroles[$j]};
					next unless defined $wwRole;
					if ($LTI_webwork_permissionLevel < $ce -> {userRoles} -> {$wwRole}) {
						$LTI_webwork_permissionLevel = $ce -> {userRoles} -> {$wwRole};
					}	
				}
			}
			####### End defining roles and $LTI_webwork_permissionLevel#######
			
			##################################################################
			# Determine the section name provided by lti
			# This may vary widely from LTI provider to LTI provider
			# If custom_section item is provided by the LTI then nothing needs to be done
			# The code works for the U. of Rochester Blackboard
			##################################################################
		
# 			my $LTI_section = $r->param("context_label");   #  for example: MTH208.2014FALL.54648
# 			my ($course_number, $semester, $CRN) = split(/\./, $LTI_section);
# 			if ($self->{section} eq "unknown" and $CRN ) {
# 			    $self->{section}= $CRN//"unknown"; # update unknown sections from CRN if possible
# 			}
# 			if ( $ce->{debug_lti_parameters} ) {
# 			    warn "LTI context_label is $LTI_section";
# 				warn "course number $course_number\n";
# 				warn "semester $semester\n";
# 				warn "CRN $CRN\n";
# 				warn "section $self->{section}";
# 			}
			########### end determine section name	
			if (! $db -> existsUser($userID) )
				{ # New User. Create User record 
				warn "New user: $userID -- requested permission level is $LTI_webwork_permissionLevel. 
				      Only new users with permission levels less than or equal to 'ta = 5' can be created." if ( $ce->{debug_lti_parameters} );
				if ($LTI_webwork_permissionLevel > $ce ->{userRoles} -> {"ta"}) {
				    $self->{log_error}.= "userID: $userID --".' '. $GENERIC_UNKNOWN_INSTRUCTOR_ERROR_MESSAGE;
					croak $r->maketext("userID: [_1] --", $userID).$r->maketext($GENERIC_UNKNOWN_INSTRUCTOR_ERROR_MESSAGE);
				}
				my $newUser = $db -> newUser();
					$newUser -> user_id($userID);
					$self -> {last_name} =~ s/\+/ /g;
					$newUser -> last_name($self -> {last_name});
					$self -> {first_name} =~ s/\+/ /g;
					$newUser -> first_name($self -> {first_name});
					$newUser -> email_address($self -> {email});
					$newUser -> status("C");
					$newUser ->  section(($LTI_webwork_permissionLevel > $ce -> {userRoles} -> {"student"}) ?
						"Admin" : (defined($self -> {section})) ? $self -> {section} : "");
					$newUser -> recitation($self -> {recitation});
					$newUser -> comment(formatDateTime(time, "local"));
				$db -> addUser($newUser);
				$self->write_log_entry("New user $userID added via LTIBasic login");
				  # Assign permssion level
				my $newPermissionLevel = $db -> newPermissionLevel();
					$newPermissionLevel -> user_id($userID);
					$newPermissionLevel -> permission($LTI_webwork_permissionLevel);
				$db -> addPermissionLevel($newPermissionLevel);
				$r -> authz -> {PermissionLevel} = $newPermissionLevel;  #cache the Permission Level Record.
				  # Assign existing sets
				  # This module is not a subclass of WeBWorK::ContentGenerator::Instuctor,
				  #  do the methods defined therein for assigning problem sets and problems
				  #  to users are not available for use here.  
				  #  Therefore, we have to resort to the lower level methods in WeBWorK::DB.
				my $numberOfProblemsAssigned = 0;
				my %globalProblemsBySet=();
				my @globalSetIDs = $db->listGlobalSets;
				my @GlobalSets = $db->getGlobalSets(@globalSetIDs);
				my $open_cut = time() + 24*3600;
				my $globalSet;
				foreach $globalSet (@GlobalSets) {
					if (defined($globalSet) and $globalSet -> open_date < $open_cut) {
					    my @GlobalProblems = grep { defined $_ } $db->getAllGlobalProblems($globalSet -> set_id);
						$globalProblemsBySet{$globalSet->set_id} = \@GlobalProblems;
						$numberOfProblemsAssigned += scalar(@GlobalProblems);
					}
				}
				my $reasonableNumberOfDays = int($numberOfProblemsAssigned / $ce->{reasonableProblemsPerDayMakeup}) +1;
				if ($reasonableNumberOfDays < 2) {$reasonableNumberOfDays = 2;}
				my ($sec, $min, $day, $monthDay, $month, $year, $weekDay, $yearDay, $isdst) = localtime();
				my $niceDueDay = $yearDay + 1 + $reasonableNumberOfDays;
				my $niceDueTime = Time::Local::timelocal_nocheck(0,30,8,$niceDueDay,0,$year);
				   ($sec, $min, $day, $monthDay, $month, $year, $weekDay, $yearDay, $isdst) = localtime($niceDueTime);
				if ($weekDay == 0) {$niceDueDay +=1;}
				elsif ($weekDay == 6) {$niceDueDay += 2;}
				my $niceAnswerTime = $niceDueTime + 600;
				my $due_cut = time() + 2*24*3600;
				my $userSet;
				my $userProblem;
				foreach $globalSet (@GlobalSets) 
					{
					if (defined($globalSet)) 
						{
						if (defined($ce -> {"adjustDueDatesForLateAdds"}) and $ce -> {"adjustDueDatesForLateAdds"}
							and $globalSet -> open_date < $open_cut and $globalSet -> due_date < $due_cut
							) 
							{
							if (not $db -> existsUserSet($userID, $globalSet -> set_id ) ) 
								{
								$userSet = $db -> newUserSet();
								$userSet -> user_id($userID);
								$userSet -> set_id($globalSet -> set_id);
								# $userSet -> psvn(int(10**12 * rand()));
								# $userSet -> open_date(0);
								$userSet -> due_date($niceDueTime);
								$userSet -> answer_date($niceAnswerTime);
								$db -> addUserSet($userSet);
								}
							}
						elsif ( $globalSet -> open_date < $open_cut )
							{
							if (not $db -> existsUserSet($userID, $globalSet -> set_id ) ) {
								$userSet = $db -> newUserSet();
								$userSet -> user_id($userID);
								$userSet -> set_id($globalSet -> set_id);
								# $userSet -> psvn(int(10**12 * rand()));
								# $userSet -> open_date(0);
								# $userSet -> due_date(0);
								# $userSet -> answer_date(0);
								$db -> addUserSet($userSet);
							}
						}
						foreach my $globalProblem (  @{$globalProblemsBySet{$globalSet -> set_id}} ) {
							if (defined($globalProblem)) {
								if (not $db -> existsUserProblem($userID, $globalSet -> set_id, $globalProblem -> problem_id)) {
									$userProblem = $db -> newUserProblem();
									$userProblem -> user_id($userID);
									$userProblem -> set_id($globalSet -> set_id);
									$userProblem -> problem_id($globalProblem -> problem_id);
									$userProblem -> problem_seed(int(10**4 * rand()));
									$userProblem -> {status} = 0;
									$userProblem -> {attempted} = 0;
									$userProblem -> {num_correct} = 0;
									$userProblem -> {num_incorrect} = 0;
									$userProblem -> {last_answer} = "";

									$db -> addUserProblem($userProblem);
								}
							}
						}
					}
				}
				$self -> {initial_login} = 1;
			}
		else 
			{ # Existing user.  Possibly modify demographic information and permission level.
			my $user = $db -> getUser($userID);
			my $permissionLevel = $db -> getPermissionLevel($userID);
			if (($user -> last_name() eq "Teacher" and $user -> first_name() eq "The")
					or (defined($permissionLevel -> permission) 
							and $permissionLevel -> permission > $ce -> {userRoles} -> {professor})) 
				{  #This is the instructor of record or an administrator.  No changes permitted via LTI.	
				}
			else 
				{
				my $change_made = 0;
				$self -> {last_name} =~ s/\+/ /g;
				if (defined($user -> last_name) and defined($self -> {last_name})
					and $user -> last_name ne $self -> {last_name}) 
					{
					$user -> last_name($self -> {last_name});
					$change_made = 1;
					}
				$self -> {first_name} =~ s/\+/ /g;
				if (defined($user -> first_name) and defined($self -> {first_name})
					and $user -> first_name ne $self -> {first_name}) 
					{
					$user -> first_name($self -> {first_name});
					$change_made = 1;
					}
				if (defined($user -> email_address) and defined($self -> {email})
					and $user -> email_address ne $self -> {email}) 
					{
					$user -> email_address($self -> {email});
					$change_made = 1;
					}
				if ($user -> status ne "C")
					{
					$user -> status("C");
					$change_made = 1;
					}
				if (defined($permissionLevel -> permission)
					and $permissionLevel -> permission > $ce ->{userRoles} -> {"student"})
						{if ($user -> section ne "Admin") 
							{
							$user -> section("Admin");
							$change_made = 1;
							}
						}
				elsif ($LTI_webwork_permissionLevel > $ce -> {userRoles}->{"student"} 
					and (!defined($user -> section) or $user -> section ne "Admin") )
						{
						$user -> section("Admin");
						$change_made = 1;
						}
				elsif (defined ($self -> {"section"}) 
					and (! defined($user -> section) 
						or ($user -> section ne $self -> {"section"}
							and $self -> {"section"} ne "" 
							and $user -> section ne "Admin"
							)
						)
					  )
						{
						$user -> section($self -> {"section"});
						$change_made = 1;
						}
				if (defined($self -> {"recitation"}) and defined($user -> recitation)
					and $user -> recitation ne $self -> {"recitation"})
					{$user -> recitation($self ->{"recitation"});
					$change_made = 1;
				}
				if ($change_made) 
					{
					$user -> comment(formatDateTime(time, "local"));
					$db -> putUser($user);
					$self->write_log_entry("Demographic data for user $userID modified via LTIBasic login");
				}
				  # Assign permission level
######## Changed due to Instructor roles passed from Sakai/Oncourse to LTIBasic ######
#				if (!defined($permissionLevel -> permission) or $permissionLevel -> permission != $LTI_webwork_permissionLevel)

# you seldom fine a defined user without a permissionLevel assigned
# I don'think the following if statement is ever run. 
				if (!defined($permissionLevel -> permission) )
#################################################################
					{
					$permissionLevel -> permission($LTI_webwork_permissionLevel);
					$db -> putPermissionLevel($permissionLevel);  # store in database
					$self->{PermissionLevel} = $permissionLevel;  #cache the revised Permission Level Record.
					$self->write_log_entry("\n\n\nPermission level for user $userID set to $LTI_webwork_permissionLevel via LTIBasic login");
					warn "Setting permission level for $userID to $LTI_webwork_permissionLevel" if ( $ce->{debug_lti_parameters} );
				}
				warn "Existing user: $userID updated.\n  LTIpermission level is $LTI_webwork_permissionLevel.
				      webwork level is ". $permissionLevel -> permission. ".\n". 
				      "User section is |".$user->{section}. "|\n recitation is |".$user->{recitation}."|\n" if ( $ce->{debug_lti_parameters} );
			}
			$self -> {initial_login} = 1;
			}
			return 1;
		}
	}
	#debug("LTIBasic is returning a failed authentication");
	$self -> {error} = $r->maketext($GENERIC_ERROR_MESSAGE);
	return(0);
}


################################################################################
################################################################################
# NONCE SUB-PACKAGE
################################################################################
################################################################################

package WeBWorK::Authen::LTIBasic::Nonce;

sub new {
	my ($invocant, $r, $nonce, $timestamp) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {
		r => $r,
		nonce => $nonce,
		timestamp => $timestamp,
	};
	bless $self, $class;
	return $self;
}

sub ok {
	my $self = shift;
	my $r = $self -> {r};
	my $ce = $r -> {ce};
	if ($self -> {timestamp} < time() - $ce->{NonceLifeTime}) {
		return 0;
	}
	my $db = $self -> {r} -> {db};
	my $Key = $db -> getKey($self -> {nonce});
	if (! defined($Key) ) {
		# nonce, timestamp are ok
		$Key = $db -> newKey(user_id=>$self->{nonce}, 
							key=>"nonce", 
							timestamp=>$self->{"timestamp"},
					);
		$db -> addKey($Key);
		return 1;
	}
	elsif ( $Key -> timestamp <  $self ->{"timestamp"} ) {
		# nonce, timestamp pair is OK
		$Key -> timestamp($self -> {"timestamp"});
		$db -> put($Key);
		return 1;
	}
	else {
		return 0;
	}
}

#sub ok { #### For Testing Purposes only
#	return 1;
#}

################################################################################
# END NONCE SUB-PACKAGE
################################################################################

sub print_keys {
	my ($self, $r) = @_;
	my @keys = keys %{$r-> {paramcache}};
	my %request_hash;
	my $key;
	foreach $key (@keys) {
		$request_hash{$key} =  $r -> param($key); 
		warn("$key -> |" . $request_hash{$key} . "|");
	}
	my $requestHash = \%request_hash;
}

1;

