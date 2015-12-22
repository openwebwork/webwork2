#!/usr/local/bin/perl -w 
use strict;
use warnings;

# Course manipulation functions for webwork webservices

package WebworkWebservice::CourseActions;

use WebworkWebservice;

use base qw(WebworkWebservice); 
use WeBWorK::DB;
use WeBWorK::DB::Utils qw(initializeUserProblem);
use WeBWorK::Utils qw(runtime_use cryptPassword formatDateTime parseDateTime);
use WeBWorK::Utils::CourseManagement qw(addCourse);
use WeBWorK::Debug;
use WeBWorK::ContentGenerator::Instructor::SendMail;
use JSON;
use MIME::Base64 qw( encode_base64 decode_base64);

use Time::HiRes qw/gettimeofday/; # for log timestamp
use Date::Format; # for log timestamp

use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

sub create {
	my ($self, $params) = @_;
	my $newcourse = $params->{'name'};
	# note this ce is different from $self->{ce}!
	my $ce = WeBWorK::CourseEnvironment->new({
			webwork_dir => $self->{ce}->{webwork_dir},
			courseName => $newcourse
		});
	my $db = $self->{db};
	my $authz = $self->{authz};
	my $out = {};

	debug("Webservices course creation request.");
	# make sure course actions are enabled
	if (!$ce->{webservices}{enableCourseActions}) {
		debug("Course actions disabled by configuration.");
		$out->{status} = "failure";
		$out->{message} = "Course actions disabled by configuration.";
		return $out
	}
	# only users from the admin course with appropriate permissions allowed
	if (!($self->{ce}->{courseName} eq 'admin')) {
		debug("Course creation attempt when not logged into admin course.");
		$out->{status} = "failure";
		$out->{message} = "Course creation allowed only for admin course users.";
		return $out
	}
	# prof check is actually done when initiating session, this is just in case
	if (!$self->{authz}->hasPermissions($params->{'userID'}, 
			'create_and_delete_courses')) {
		debug("Course creation attempt with insufficient permission level.");
		$out->{status} = "failure";
		$out->{message} = "Insufficient permission level.";
		return $out
	}
	
	# declare params
	my @professors = ();
	my $dbLayout = $ce->{dbLayoutName};
	my %courseOptions = ( dbLayoutName => $dbLayout );
	my %dbOptions;
	my @users;
	my %optional_arguments;

	my $userClass = $ce->{dbLayouts}->{$dbLayout}->{user}->{record};
	my $passwordClass = $ce->{dbLayouts}->{$dbLayout}->{password}->{record};
	my $permissionClass = $ce->{dbLayouts}->{$dbLayout}->{permission}->{record};

	# copy instructors from admin course
	# modified from do_add_course in WeBWorK::ContentGenerator::CourseAdmin
	foreach my $userID ($db->listUsers) {
		my $User            = $db->getUser($userID);
		my $Password        = $db->getPassword($userID);
		my $PermissionLevel = $db->getPermissionLevel($userID);
		push @users, [ $User, $Password, $PermissionLevel ] 
			if $authz->hasPermissions($userID,"create_and_delete_courses");  
	}

	# all data prepped, try to actually add the course
	eval {
		addCourse(
			courseID => $newcourse,
			ce => $ce,
			courseOptions => \%courseOptions,
			dbOptions => \%dbOptions,
			users => \@users,
			%optional_arguments,
		);
		addLog($ce, "New course created: " . $newcourse);
		$out->{status} = "success";
	} or do {
		$out->{status} = "failure";
		$out->{message} = $@;
	};
	
	return $out;
}

sub listUsers {
    my ($self, $params) = @_;
    my $out = {};
    my $db = $self->{db};
    my $ce = $self->{ce};
    

    # make sure course actions are enabled
    #if (!$ce->{webservices}{enableCourseActions}) {
    #	$out->{status} = "failure";
    #	$out->{message} = "Course actions disabled by configuration.";
    #	return $out
    #}

    my @tempArray = $db->listUsers;
    my @userInfo = $db->getUsers(@tempArray);
    my $numGlobalSets = $db->countGlobalSets;
    
    #%permissionsHash = reverse %permissionsHash;
    #for(@userInfo){
    #    @userInfo[i]->{'permission'} = $db->getPermissionLevel(@userInfo[i]->{'user_id'});
    #}
    my %permissionsHash = reverse %{$ce->{userRoles}};
    foreach my $u (@userInfo)
    {
        my $PermissionLevel = $db->getPermissionLevel($u->{'user_id'});
        $u->{'permission'} = $PermissionLevel->{'permission'};
        #$u->{'permission'}{'name'} = $permissionsHash{$PermissionLevel->{'permission'}};


		my $studid= $u->{'student_id'};
		$u->{'student_id'} = "$studid";  # make sure that the student_id is returned as a string. 
        $u->{'num_user_sets'} = $db->listUserSets($studid) . "/" . $numGlobalSets;
	
		my $Key = $db->getKey($u->{'user_id'});
		$u->{'login_status'} =  ($Key and time <= $Key->timestamp()+$ce->{sessionKeyTimeout}); # cribbed from check_session
		
    }


    $out->{ra_out} = \@userInfo;
    $out->{text} = encode_base64("Users for course: ".$self->{courseName});
    return $out;
}

sub addUser {
	my ($self, $params) = @_;
	my $out = {};
	$out->{text} = encode_base64("");
	my $db = $self->{db};
	my $ce = $self->{ce};

	# make sure course actions are enabled
	#if (!$ce->{webservices}{enableCourseActions}) {
	#	$out->{status} = "failure";
	#	$out->{message} = "Course actions disabled by configuration.";
	#	return $out
	#}

	# Two scenarios
	# 1. New user
	# 2. Dropped user deciding to re-enrol

	my $olduser = $db->getUser($params->{id});
	my $id = $params->{'id'};
	my $permission; # stores user's permission level
	if ($olduser) { 
		# a dropped user decided to re-enrol
		my $enrolled = $self->{ce}->{statuses}->{Enrolled}->{abbrevs}->[0];
		$olduser->status($enrolled);
		$db->putUser($olduser);
		addLog($ce, "User ". $id . " re-enrolled in " . 
			$ce->{courseName});
		$out->{status} = 'success';
		$permission = $db->getPermissionLevel($id);
	}
	else {
		# a new user showed up
		my $ce = $self->{ce};
		
		# student record
		my $enrolled = $ce->{statuses}->{Enrolled}->{abbrevs}->[0];
		my $new_student = $db->{user}->{record}->new();
		$new_student->user_id($id);
		$new_student->first_name($params->{'first_name'});
		$new_student->last_name($params->{'last_name'});
		$new_student->status($enrolled);
		$new_student->student_id($params->{'student_id'});
		$new_student->email_address($params->{'email_address'});
		$new_student->recitation($params->{'recitation'});
		$new_student->section($params->{'section'});
		$new_student->comment($params->{'comment'});
		
		# password record
		my $cryptedpassword = "";
		if ($params->{'password'}) {
			$cryptedpassword = cryptPassword($params->{'password'});
		}
		elsif ($new_student->student_id()) {
			$cryptedpassword = cryptPassword($new_student->student_id());
		}
		my $password = $db->newPassword(user_id => $id);
		$password->password($cryptedpassword);
		
		# permission record
		$permission = $params->{'permission'};
		if (defined($ce->{userRoles}{$permission})) {
			$permission = $db->newPermissionLevel(
				user_id => $id, 
				permission => $ce->{userRoles}{$permission});
		}
		else {
			$permission = $db->newPermissionLevel(user_id => $id, 
				permission => $ce->{userRoles}{student});
		}

		# commit changes to db
		$out->{status} = 'success';
		eval{ $db->addUser($new_student); };
		if ($@) {
			$out->{status} = 'failure';
			$out->{message} = "Add user for $id failed!\n";
		}
		eval { $db->addPassword($password); };
		if ($@) {
			$out->{status} = 'failure';
			$out->{message} = "Add password for $id failed!\n";
		}
		eval { $db->addPermissionLevel($permission); };
		if ($@) {
			$out->{status} = 'failure';
			$out->{message} = "Add permission for $id failed!\n";
		}

		addLog($ce, "User ". $id . " newly added in " . 
			$ce->{courseName});
	}

	# only students are assigned homework
	if ($ce->{webservices}{courseActionsAssignHomework} &&
		$permission->{permission} == $ce->{userRoles}{student}) {
		debug("Assigning homework.");
		my $ret = assignVisibleSets($db, $id);
		if ($ret) {
			$out->{status} = 'failure';
			$out->{message} = "User created but unable to assign sets. $ret";
		}
	}

	return $out;
}

sub dropUser {
	my ($self, $params) = @_;
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $out = {};
	debug("Webservices drop user request.");

	# make sure course actions are enabled
	if (!$ce->{webservices}{enableCourseActions}) {
		$out->{status} = "failure";
		$out->{message} = "Course actions disabled by configuration.";
		return $out
	}

	# Mark user as dropped
	my $drop = $self->{ce}->{statuses}->{Drop}->{abbrevs}->[0];
	my $person = $db->getUser($params->{'id'});
	if ($person) {
		$person->status($drop);
		$db->putUser($person);
		addLog($ce, "User ". $person->user_id() . " dropped from " . 
			$ce->{courseName});
		$out->{status} = 'success';
	}
	else {
		$out->{status} = 'failure';
		$out->{message} = 'Could not find user';
	}

	return $out;
}

sub deleteUser {
	my ($self, $params) = @_;
	my $out = {};
	my $db = $self->{db};
	my $ce = $self->{ce};
	$out->{text} = encode_base64("");
	
	my $user = $params->{'id'};
	
	
	debug("Webservices delete user request.");
        debug("Attempting to delete user: " . $user );
	
	
	my $User = $db->getUser($params->{'id'}); # checked
	die ("record for visible user [_1] not found" . $params->{'id'}) unless $User;

	
	# Why is the following commented out? 
	
	# make sure course actions are enabled
	
	#if (!$ce->{webservices}{enableCourseActions}) {
	#	$out->{status} = "failure";
	#	$out->{message} = "Course actions disabled by configuration.";
	#	$out->{text} = encode_base64("Course actions disabled by configuration");
	#	return $out
	#}
	
	if ($params->{'id'} eq $params->{'user'} )
	{
		$out->{status} = "failure";
		$out->{message} = "You can't delete yourself from the course.";
	} else {
		my $del = $db->deleteUser($user);
		
		if($del)
		{
			my $result;
			$result->{delete} = "success";
			$out->{text} .=encode_base64("User " . $user . " successfully deleted");
			$out->{ra_out} .= "delete: success";
		}
		else 
		{
			$out->{text}=encode_base64("User " . $user . " could not be deleted");
			$out->{ra_out} .= "delete : failed";
		}

	}
	
	return $out;
	
}


sub editUser {
	my ($self, $params) = @_;
    my $db = $self->{db};
    my $ce = $self->{ce};
    my $out = {};
    debug("Webservices edit user request.");
    $out->{text} = encode_base64("");
    # make sure course actions are enabled
    #if (!$ce->{webservices}{enableCourseActions}) {
    #	$out->{status} = "failure";
    #	$out->{message} = "Course actions disabled by configuration.";
    #	return $out
    #}

	my $User = $db->getUser($params->{'id'}); # checked
    die ("record for visible user [_1] not found" . $params->{'id'}) unless $User;
    my $PermissionLevel = $db->getPermissionLevel($params->{'id'}); # checked
    die "permissions for [_1] not defined". $params->{'id'} unless defined $PermissionLevel;
    foreach my $field ($User->NONKEYFIELDS()) {
    	my $param = "${field}";
    	if (defined $params->{$param}) {
    		$User->$field($params->{$param});
    	}
    }
    if($params->{'id'} eq $params->{'user'}){
        $out->{text} .= encode_base64("You cannot change your own permissions.");
    } else {
        foreach my $field ($PermissionLevel->NONKEYFIELDS()) {
    	    my $param = "${field}";
    	    if (defined $params->{$param}) {
   	    	    $PermissionLevel->$field($params->{$param});
    	    }
        }
    }

    $db->putUser($User);
    $db->putPermissionLevel($PermissionLevel);
    $User = $db->getUser($params->{'id'}); # checked

    my %permissionsHash = reverse %{$ce->{userRoles}};
    $PermissionLevel = $db->getPermissionLevel($User->{'user_id'});
    $User->{'permission'} = $PermissionLevel->{'permission'};
    #$User->{'permission'}{'name'} = $permissionsHash{$PermissionLevel->{'permission'}};
    
    
    # If the new_password param is set and not equal to the empty string, change the password.
    
    if((defined $params->{new_password}) and ($params->{new_password} ne "" ) ) {
	return changeUserPassword($self,$params);
    }
    

    $out->{ra_out} = $User;
    $out->{text} .= encode_base64("Changes saved");

	return $out;
}

#  id :  is the user_id of the user to be changed.
#  new_password : the 


sub changeUserPassword {

	my ($self, $params) = @_;
	my $out = {};
	my $db = $self->{db};
	my $ce = $self->{ce};
	$out->{text} = encode_base64("");
	
	my $userid = $params->{'id'};
	
	# check to see if you have sufficient privileges. 
	# Note: this is not implemented.  It seems like we should verify that the user has appropriate privileges to change
	# a password or that the user sending the request is the same as the person whose password is being changed.  
	#  my $PermissionLevel = $db->getPermissionLevel($params->{'user'}); # checked
    
	
	debug("Webservices change user password request.");
        debug("Attempting to change the password of user: " . $userid );
	debug("The new password:" . $params->{new_password});
	
	
	my $User = $db->getUser($userid); # checked
	die ("record for visible user [_1] not found" . $params->{'id'}) unless $User;


    # make sure course actions are enabled
   #     if (!$ce->{webservices}{enableCourseActions}) {
    #    	$out->{text} = "failure";
     #   	$out->{ra_out} = "Course actions disabled by configuration.";
     #   	return $out
     #   }

    #my $User = $db->getUser($params->{'id'}); # checked
    if(!(defined $User)){
	$out->{text}=encode_base64("No record found for user: ". $params->{'id'});
	return $out;
    }
    
    # In the next few lines I (pls) changed $params->{$param}->[0] to $params->{$param} to fix a bug.  Not sure why ->[0] was there. 
	my $param = "new_password";
	if ((defined $params->{$param}) and ($params->{$param})) {
		my $newP = $params->{$param};
		my $Password = eval {$db->getPassword($User->user_id)}; # checked
		my $cryptPassword = cryptPassword($newP);
		$Password->password(cryptPassword($newP));
		eval { $db->putPassword($Password) };
	}

	$self->{passwordMode} = 0;
	$out->{text} = encode_base64("New passwords saved");
	$out->{ra_out}= "password_change: success";
	return $out;
}

sub addLog {
	my ($ce, $msg) = @_;
	if (!$ce->{webservices}{enableCourseActionsLog}) {
		return;
	}
	my ($sec, $msec) = gettimeofday;
	my $date = time2str("%a %b %d %H:%M:%S.$msec %Y", $sec);

	$msg = "[$date] $msg\n";

	my $logfile = $ce->{webservices}{courseActionsLogfile};
	if (open my $f, ">>", $logfile) {
		print $f $msg;
		close $f;
	}
	else {
		debug("Error, unable to open student updates log file '$logfile' in".
			"append mode: $!");
	}
	return;
}

sub assignVisibleSets {
	my ($db, $userID) = @_;
	my @globalSetIDs = $db->listGlobalSets;
	my @GlobalSets = $db->getGlobalSets(@globalSetIDs);

	my $i = -1;
	foreach my $GlobalSet (@GlobalSets) {
		$i++;
		if (not defined $GlobalSet) {
			debug("Record not found for global set $globalSetIDs[$i]");
			next;
		} 
		if (!$GlobalSet->visible) {
			next;
		}

		# assign set to user
		my $setID = $GlobalSet->set_id;
		my $UserSet = $db->newUserSet;
		$UserSet->user_id($userID);
		$UserSet->set_id($setID);
		my @results;
		my $set_assigned = 0;
		eval { $db->addUserSet($UserSet) }; 
		if ( $@ && !($@ =~ m/user set exists/)) {
			return "Failed to assign set to user $userID";
		}

		# assign problem
		my @GlobalProblems = grep { defined $_ } $db->getAllGlobalProblems($setID);
		foreach my $GlobalProblem (@GlobalProblems) {
			my $seed = int( rand( 2423) ) + 36;
			my $UserProblem = $db->newUserProblem;
			$UserProblem->user_id($userID);
			$UserProblem->set_id($GlobalProblem->set_id);
			$UserProblem->problem_id($GlobalProblem->problem_id);
			initializeUserProblem($UserProblem, $seed);
			eval { $db->addUserProblem($UserProblem) };
			if ($@ && !($@ =~ m/user problem exists/)) {
				return "Failed to assign problems to user $userID";
			}
		}
	}

	return 0;
}



sub getConfigValues {
	my $ce = shift;
	my $ConfigValues = $ce->{ConfigValues};

	foreach my $oneConfig (@$ConfigValues) {
		foreach my $hash (@$oneConfig) {
			if (ref($hash) eq "HASH"){
				my $str = '$ce->' . $hash->{hashVar};
				$hash->{value} = eval($str);
			} else {
				debug($hash);
			}
		}
	}

	# get the list of theme folders in the theme directory and remove . and ..
	my $themeDir = $ce->{webworkDirs}{themes};
	opendir(my $dh, $themeDir) || die "can't opendir $themeDir: $!";
	my $themes =[grep {!/^\.{1,2}$/} sort readdir($dh)];
	
	# insert the anonymous array of theme folder names into ConfigValues
	my $modifyThemes = sub { my $item=shift; if (ref($item)=~/HASH/ and $item->{var} eq 'defaultTheme' ) { $item->{values} =$themes } };

	foreach my $oneConfig (@$ConfigValues) {
		foreach my $hash (@$oneConfig) {
			&$modifyThemes($hash);
		}
	}
	
	$ConfigValues;
}

sub getCourseSettings {
	my ($self, $params) = @_;
	my $ce = $self->ce;		# course environment
	my $db = $self->db;		# database
	my $ConfigValues = getConfigValues($ce);

	my $tz = DateTime::TimeZone->new( name => $ce->{siteDefaults}->{timezone}); 
	my $dt = DateTime->now();

	my @tzabbr = ("tz_abbr", $tz->short_name_for_datetime( $dt ));


	#debug($tz->short_name_for_datetime($dt));

	push(@$ConfigValues, \@tzabbr);
  	
	my $out = {};
	$out->{ra_out} = $ConfigValues;
	$out->{text} = encode_base64("Successfully found the course settings");
    return $out;

}

sub updateSetting {
	my ($self, $params) = @_;
	my $ce = $self->ce;		# course environment
	my $db = $self->db;		# database

	my $setVar = $params->{var};
	my $setValue = $params->{value};

	# this shouldn't be needed, but it seems like it's not get parsed correctly. 
	#if($params->{sendViaJSON}){
	#	$setValue = decode_json($setValue);
	#}
	debug("in updateSetting");
	debug("var:  " . $setVar);
	debug("value: " . $setValue);

	my $filename = $ce->{courseDirs}->{root} . "/simple.conf";
	debug("Write to file: " . $filename);

		my $fileoutput = "#!perl
# This file is automatically generated by WeBWorK's web-based
# configuration module.  Do not make changes directly to this
# file.  It will be overwritten the next time configuration
# changes are saved.\n\n";


	# read in the file 

	open(DAT, $filename) || die("Could not open file!");
	my @raw_data=<DAT>;
	close(DAT);




	my $var;
	my $line;
	my $value;
	my $varFound = 0; 

	foreach $line (@raw_data)
	{
		chomp $line;
	 	if ($line =~ /^\$/) {
	 		my @tmp = split(/\$/,$line);
	 		($var,$value) = split(/\s+=\s+/,$tmp[1]);
	 		if ($var eq $setVar){ 
	 			$fileoutput .= "\$" . $var . " = " . $setValue . "\n";
	 			$varFound = 1; 
	 		} else {
	 			$fileoutput .= "\$" . $var . " = " . $value . "\n";
	 		}
		}
	}

	if (! $varFound) {
		$fileoutput .= "\$" . $setVar . " = " . $setValue . ";\n";
	}

	debug ($fileoutput);


	my $writeFileErrors;
	eval {                                                          
		local *OUTPUTFILE;
		if( open OUTPUTFILE, ">", $filename) {
			print OUTPUTFILE $fileoutput;
			close OUTPUTFILE;
		} else {
			$writeFileErrors = "I could not open $fileoutput".
				"We will not be able to make configuration changes unless the permissions are set so that the web server can write to this file.";
		}
	};  # any errors are caught in the next block

	$writeFileErrors = $@ if $@;

	debug("errors: ". $writeFileErrors);


	my $out = {};
	$out->{ra_out} = "";
	$out->{text} = encode_base64("Successfully updated the course settings");
    return $out;
}


##  pstaabp: This is currently not working.  We need to look into a nice robust way to send email.  It looks like the current
## way that WW sends mail is a bit archaic.  The MIME::Lite looks fairly straightforward, but we may need to look into smtp settings a
## bit more.  


sub sendEmail {
	my ($self, $params) = @_;
	my $ce = $self->{ce};

# Should we build in the merge_file?  
#  get merge file
#		my $merge_file      = ( defined($self->{merge_file}) ) ? $self->{merge_file} : 'None';
#		my $delimiter       = ',';
#		my $rh_merge_data   = $self->read_scoring_file("$merge_file", "$delimiter");
#		unless (ref($rh_merge_data) ) {
#			$self->addbadmessage(CGI::p("No merge data file"));
#			$self->addbadmessage(CGI::p("Can't read merge file $merge_file. No message sent"));
#			return;
#		} ;
#		$self->{rh_merge_data} = $rh_merge_data;
		
		# we don't set the response until we're sure that email can be sent
#		$self->{response}         = 'send_email';
		
	my $smtpServer = $ce->{mail}->{smtpServer};
		
	debug("smtpServer: " . $smtpServer);
	
	
	my $mailer = Mail::Sender->new({
				tls_allowed => $ce->{tls_allowed}//1, # the default for this for  Mail::Sender is 1
				from      => $smtpServer,
				fake_from => "pstaab\@fitchburgstate.edu",
				to        => "pstaab\@fitchburgstate.edu",
				smtp      => $smtpServer,
				subject   => "Test"
			});
}

1;
