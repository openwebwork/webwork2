package WebworkSOAP;

use strict;

use WeBWorK::Utils qw(pretty_print_rh);
use WeBWorK::Utils::CourseManagement qw(addCourse renameCourse deleteCourse listCourses archiveCourse listArchivedCourses unarchiveCourse);
use WeBWorK::DB;
use WeBWorK::DB::Utils qw(initializeUserProblem);
use WeBWorK::CourseEnvironment;
use WeBWorK::ContentGenerator::Instructor;

use WebworkSOAP::Classes::GlobalSet;
use WebworkSOAP::Classes::UserSet;
use WebworkSOAP::Classes::GlobalProblem;
use WebworkSOAP::Classes::UserProblem;
use WebworkSOAP::Classes::User;
use WebworkSOAP::Classes::Key;
use WebworkSOAP::Classes::Password;
use WebworkSOAP::Classes::Permission;

#init

use constant {
        SOAPERROR_MAJOR             => 1,
        SOAPERROR_MINOR             => 2,
        SOAPERROR_CLASS_NOT_FOUND   => 3,
        SOAPERROR_USER_NOT_FOUND    => 4,
        SOAPERROR_SET_NOT_FOUND     => 5,
        SOAPERROR_PROBLEM_NOT_FOUND => 6,
        SOAPERROR_KEY_NOT_FOUND     => 7,
        SOAPERROR_AUTHEN_FAILED     => 8
};

our %SeedCE;
%WebworkSOAP::SeedCE = %WeBWorK::SeedCE;

$WebworkSOAP::SeedCE{soap_authen_key} = "123456789123456789";
#$WebworkSOAP::SeedCE{webwork_dir} = $ENV{WEBWORK_ROOT}|| warn "\$ENV{WEBWORK_ROOT} is undefined -- check your httpd configuration. Error caught ";


sub new {
    my($self,$authenKey,$courseName) = @_;
    $self = {};
    #Construct Course
    my $ce = eval { new WeBWorK::CourseEnvironment({%SeedCE, courseName => $courseName }) };
    $@ and soap_fault_major("Course Environment cannot be constructed.<br>$@");
    #Authentication Check
    if($ce->{soap_authen_key} != $authenKey) {
        soap_fault_authen();
    }
    #Construct DB handle
    my $db = eval { new WeBWorK::DB($ce->{dbLayout}); };
    $@ and soap_fault_major("Failed to initialize database handle.<br>$@");
    $self->{db} = $db;
    $self->{ce} = $ce;
    bless $self;
    return $self;
}

sub array_to_soap_string {
	my @array = @_;
	@array = map { SOAP::Data->type( 'string', $_ ) } @array;
	return \@array;
}

sub soap_fault_authen {
    die SOAP::Fault->faultcode(SOAPERROR_AUTHEN_FAILED)
                    ->faultstring("SOAP Webservice Authentication Failed!");
}

sub soap_fault {
    my ($errorCode,$errorMsg) = @_;
    die SOAP::Fault->faultcode($errorCode)
                   ->faultstring($errorMsg);
}

sub soap_fault_major {
    my ($errorMsg) = @_;
    soap_fault(SOAPERROR_MAJOR,$errorMsg);
}
####################################################################################
#SOAP CALLABLE FUNCTIONS
####################################################################################

# RETURN $string Hello World!
sub hello {
    return "Hello world!";
}

#################################################
#Course
#################################################

# IN authenKey $string
# RETURN @string
sub list_courses {
    my ($self,$authenKey) = @_;
    my $ce = eval { new WeBWorK::CourseEnvironment({%WeBWorK::SeedCE })};
    $@ and soap_fault_major("Internal Course Environment cannot be constructed.");
    if($authenKey != $WebworkSOAP::SeedCE{soap_authen_key}) {
        soap_fault_authen;
    }
    $@ and soap_fault_major("Course Environment cannot be constructed.");
    my @test = listCourses($ce);
    return array_to_soap_string( @test );
}

# IN authenKey $string
# IN courseName $string
# IN userID $string
# RETURN $string
sub login_user {
    my ($self,$authenKey,$courseName,$userID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newKey;
    my $timestamp = time;
    my @chars = @{ $soapEnv->{ce}->{sessionKeyChars} };
    my $length = $soapEnv->{ce}->{sessionKeyLength};
    srand;
    $newKey = join ("", @chars[map rand(@chars), 1 .. $length]);
    my $Key = $soapEnv->{db}->newKey(user_id=>$userID, key=>$newKey, timestamp=>$timestamp);
    eval { $soapEnv->{db}->deleteKey($userID) };
    eval { $soapEnv->{db}->addKey($Key) };
    $@ and soap_fault(SOAPERROR_USER_NOT_FOUND,"User not found.");
    return SOAP::Data->type( 'string', $newKey );
}

# IN authenKey $string
# IN courseName $string
# IN userID $string
# IN setID $string
# RETURN $string
sub assign_set_to_user {
    my ($self,$authenKey,$courseName,$userID,$setID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $GlobalSet = eval {$soapEnv->{db}->getGlobalSet($setID)};
    $@ and soap_fault(SOAPERROR_SET_NOT_FOUND,"Set not found.");
    my $setID = $GlobalSet->set_id;
    my $db = $soapEnv->{db};
    my $UserSet = $db->newUserSet;
    $UserSet->user_id($userID);
    $UserSet->set_id($setID);
    my @results;
    my $set_assigned = 0;
    eval { $db->addUserSet($UserSet) };
    if ($@) {
    	if ($@ =~ m/user set exists/) {
	    	push @results, "set $setID is already assigned to user $userID.";
	    	$set_assigned = 1;
    	} else {
        	die $@;
        }
    }

    my @GlobalProblems = grep { defined $_ } $db->getAllGlobalProblems($setID);
    foreach my $GlobalProblem (@GlobalProblems) {
        my $seed = int( rand( 2423) ) + 36;
        my $UserProblem = $db->newUserProblem;
	$UserProblem->user_id($userID);
	$UserProblem->set_id($GlobalProblem->set_id);
	$UserProblem->problem_id($GlobalProblem->problem_id);
	initializeUserProblem($UserProblem, $seed);
	eval { $db->addUserProblem($UserProblem) };
    }
    return array_to_soap_string( @results ); #FIXME WSDL says $string, not @string?
}

# IN authenKey $string
# IN courseName $string
# IN userIDs @string
# IN setID $string
# RETURN @string
sub grade_users_sets {
    my ($self,$authenKey,$courseName,$userIDs,$setID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @grades;
    #open (LOG, ">>/opt/webwork/tmp_log") or die "Can't open log file";
    #print LOG "\n\nhi there\n\n";

    my $db = $soapEnv->{db};
    foreach my $userID (@{$userIDs}) {
#         my @problemData = $soapEnv->{db}->getAllMergedUserProblems($userID,$setID);
#         
#         my $grade = 0;
#         for(my $i=0;$i<@problemData;$i++) {
#                 #print LOG "$userID problem Data",join(" ", %{$problemData[$i]}),"\n\n";
#                 $grade += ($problemData[$i]->status)*($problemData[$i]->value);
#                 #print LOG "grade is $grade\n";
#         }
            #print LOG "grade_users_sets: get user $userID set $setID\n";
         	my $grade = get_wwassignment_grade_for_one_user($db, $userID,$setID );
         	#print LOG " grade is $grade \n\n";
        push(@grades,$grade);
    }
    #close(LOG);
    return array_to_soap_string( @grades );
}

# IN authenKey $string
# IN courseName $string
# IN setID $string
# RETURN $WebworkSOAP::Classes::GlobalSet
sub get_set_data {
    my ($self,$authenKey,$courseName,$setID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $setData = $soapEnv->{db}->getGlobalSet($setID);
    if(not defined $setData) {
        return -1;
    }
    my $set = new WebworkSOAP::Classes::GlobalSet($setData);
    return $set;
}

####################################################################
##FUNCTIONS DIRECTLY MAPPED TO FUNCTIONS IN DB.pm
####################################################################
###############################################
##Password
###############################################

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::Password
# RETURN $string
sub add_password {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newPassword = $soapEnv->{db}->newPassword;
    %$newPassword = %$record;
    return SOAP::Data->type( 'string', $soapEnv->{db}->addPassword($newPassword) );
}

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::Password
# RETURN $string
sub put_password {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return SOAP::Data->type( 'string', $soapEnv->{db}->putPassword($record) );
}

# IN authenKey $string
# IN courseName $string
# RETURN @string
sub list_password {
    my ($self,$authenKey,$courseName) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listPasswords;
    return array_to_soap_string( @tempArray );
}

# IN authenKey $string
# IN courseName $string
# IN userIDs @string
# RETURN @WebworkSOAP::Classes::Password Array of user objects
sub get_passwords {
    my ($self,$authenKey,$courseName,$userIDs) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @passwordData = $soapEnv->{db}->getPasswords(@$userIDs);
    my @passwords;
    for(my $i=0;$i<@passwordData;$i++) {
        push(@passwords,new WebworkSOAP::Classes::Password(@passwordData[$i]));
    }
    return \@passwords;
}

# IN authenKey $string
# IN courseName $string
# IN userID $string
# RETURN $WebworkSOAP::Classes::Password of names objects.
sub get_password {
    my ($self,$authenKey,$courseName,$userID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $passwordData = $soapEnv->{db}->getPassword($userID);
    if(not defined $passwordData) {
        return -1;
    }
    my $password = new WebworkSOAP::Classes::Password($passwordData);
    return ($password);
}

##################################################
##Permission
##################################################

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::Permission
# RETURN $string
sub add_permission {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newPermissionLevel = $soapEnv->{db}->newPermissionLevel;
    %$newPermissionLevel = %$record;
    return SOAP::Data->type( 'string', $soapEnv->{db}->addPermissionLevel($newPermissionLevel) );
}

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::Permission
# RETURN $string
sub put_permission {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newPermissionLevel = $soapEnv->{db}->newPermissionLevel;
    %$newPermissionLevel = %$record;
    return SOAP::Data->type( 'string',
        $soapEnv->{db}->putPermissionLevel($newPermissionLevel) );
}

# IN authenKey $string
# IN courseName $string
# RETURN @string
sub list_permissions {
    my ($self,$authenKey,$courseName) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listPermissionLevels;
    return array_to_soap_string( @tempArray );
}

# IN authenKey $string
# IN courseName $string
# IN userIDs @string
# RETURN @WebworkSOAP::Classes::Permission Array of user objects
sub get_permissions {
    my ($self,$authenKey,$courseName,$userIDs) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @permissionData = $soapEnv->{db}->getPermissionLevels(@$userIDs);
    my @permissions;
    for(my $i=0;$i<@permissionData;$i++) {
        push(@permissions,new WebworkSOAP::Classes::Permission(@permissionData[$i]));
    }
    return \@permissions;
}

# IN authenKey $string
# IN courseName $string
# IN userID $string
# RETURN $WebworkSOAP::Classes::Permission of names objects.
sub get_permission {
    my ($self,$authenKey,$courseName,$userID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $permissionData = $soapEnv->{db}->getPermissionLevel($userID);
    if(not defined $permissionData) {
        return -1;
    }
    my $permission = new WebworkSOAP::Classes::Permission($permissionData);
    return ($permission);
}

##################################################
##Key
##################################################

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::Key
# RETURN $string
sub add_key {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newKey = $soapEnv->{db}->newKey;
    %$newKey = %$record;
    return SOAP::Data->type( 'string', $soapEnv->{db}->addKey($newKey) );
}

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::Key
# RETURN $string
sub put_key {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return SOAP::Data->type( 'string', $soapEnv->{db}->putKey($record) );
}

# IN authenKey $string
# IN courseName $string
# RETURN @string
sub list_keys {
    my ($self,$authenKey,$courseName) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listKeys;
    return array_to_soap_string( @tempArray );
}

# IN authenKey $string
# IN courseName $string
# IN userIDs @string
# RETURN @WebworkSOAP::Classes::Key Array of user objects
sub get_keys {
    my ($self,$authenKey,$courseName,$userIDs) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @keyData = $soapEnv->{db}->getKeys(@$userIDs);
    my @keys;
    for(my $i=0;$i<@keyData;$i++) {
        push(@keys,new WebworkSOAP::Classes::Key(@keyData[$i]));
    }
    return \@keys;
}

# IN authenKey $string
# IN courseName $string
# IN userID $string
# RETURN $WebworkSOAP::Classes::Key of names objects.
sub get_key {
    my ($self,$authenKey,$courseName,$userID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $keyData = $soapEnv->{db}->getKey($userID);
    if(not defined $keyData) {
        return -1;
    }
    my $key = new WebworkSOAP::Classes::Key($keyData);
    return ($key);
}

##################################################
##User
##################################################

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::User
# RETURN $string
sub add_user {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newUser = $soapEnv->{db}->newUser;
    %$newUser = %$record;
    return SOAP::Data->type( 'string', $soapEnv->{db}->addUser($newUser) );
}

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::User
# RETURN $string
sub put_user {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return SOAP::Data->type( 'string', $soapEnv->{db}->putUser($record) );
}

# IN authenKey $string
# IN courseName $string
# RETURN @string of names objects.
sub list_users {
    my ($self,$authenKey,$courseName) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listUsers;
    return array_to_soap_string( @tempArray );
}

# IN authenKey $string
# IN courseName $string
# IN userID $string
# RETURN $WebworkSOAP::Classes::User of names objects.
sub get_user {
    my ($self,$authenKey,$courseName,$userID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $userData = $soapEnv->{db}->getUser($userID);
    if(not defined $userData) {
        return -1;
    }
    my $user = new WebworkSOAP::Classes::User($userData);
    return ($user);
}

# IN authenKey $string
# IN courseName $string
# IN userIDs @string
# RETURN @WebworkSOAP::Classes::User Array of user objects
sub get_users {
    my ($self,$authenKey,$courseName,$userIDs) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @userData = $soapEnv->{db}->getUsers(@$userIDs);
    my @users;
    for(my $i=0;$i<@userData;$i++) {
        push(@users,new WebworkSOAP::Classes::User(@userData[$i]));
    }
    return \@users;
}

# IN authenKey $string
# IN courseName $string
# IN userID $string
# RETURN $string
sub delete_user {
    my ($self,$authenKey,$courseName,$userID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return SOAP::Data->type( 'string', $soapEnv->{db}->deleteUser($userID) );
}

##################################################
##Global Sets
##################################################

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::GlobalSet
# RETURN $string
sub add_global_set {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newGlobalSet = $soapEnv->{db}->newGlobalSet;
    %$newGlobalSet = %$record;
    return SOAP::Data->type( 'string', $soapEnv->{db}->addGlobalSet($newGlobalSet) );
}

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::GlobalSet
# RETURN $string
sub put_global_set {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return SOAP::Data->type( 'string', $soapEnv->{db}->putGlobalSet($record) );
}

# IN authenKey $string
# IN courseName $string
# RETURN @string of names objects.
sub list_global_sets {
    my ($self,$authenKey,$courseName) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listGlobalSets;
    return array_to_soap_string( @tempArray );
}

# IN authenKey $string
# IN courseName $string
# RETURN @WebworkSOAP::Classes::GlobalSet Array of user objects
sub get_all_global_sets {
    my ($self,$authenKey,$courseName) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listGlobalSets;
    my @setData = $soapEnv->{db}->getGlobalSets(@tempArray);
    my @sets;
    for(my $i=0;$i<@setData;$i++) {
        push(@sets,new WebworkSOAP::Classes::GlobalSet(@setData[$i]));
    }
    return \@sets;
}

# IN authenKey $string
# IN courseName $string
# IN setIDs @string
# RETURN @WebworkSOAP::Classes::GlobalSet Array of user objects
sub get_global_sets {
    my ($self,$authenKey,$courseName,$setIDs) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @setData = $soapEnv->{db}->getGlobalSets(@$setIDs);
    my @sets;
    for(my $i=0;$i<@setData;$i++) {
        push(@sets,new WebworkSOAP::Classes::GlobalSet(@setData[$i]));
    }
    return \@sets;
}

# IN authenKey $string
# IN courseName $string
# IN setID $string
# RETURN $WebworkSOAP::Classes::GlobalSet
sub get_global_set {
    my ($self,$authenKey,$courseName,$setID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $setData = $soapEnv->{db}->getGlobalSet($setID);
    if(not defined $setData) {
        return -1;
    }
    my $set = new WebworkSOAP::Classes::GlobalSet($setData);
    return ($set);
}

# IN authenKey $string
# IN courseName $string
# IN setID $string
# RETURN $string
sub delete_global_set {
    my ($self,$authenKey,$courseName,$setID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return SOAP::Data->type( 'string', $soapEnv->{db}->deleteGlobalSet($setID) );
}

##################################################
##Global Problems
##################################################

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::GlobalProblem
# RETURN $string
sub add_global_problem {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newGlobalProblem = $soapEnv->{db}->newGlobalProblem;
    %$newGlobalProblem = %$record;
    return SOAP::Data->type( 'string', $soapEnv->{db}->addGlobalProblem($newGlobalProblem) );
}

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::GlobalProblem
# RETURN $string
sub put_global_problem {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return SOAP::Data->type( 'string', $soapEnv->{db}->putGlobalProblem($record) );
}

# IN authenKey $string
# IN courseName $string
# IN setID $string
# RETURN @string of names objects.
sub list_global_problems {
    my ($self,$authenKey,$courseName,$setID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listGlobalProblems($setID);
    return array_to_soap_string( @tempArray );
}

# IN authenKey $string
# IN courseName $string
# IN setID $string
# RETURN @WebworkSOAP::Classes::GlobalProblem Array of user objects
sub get_all_global_problems {
    my ($self,$authenKey,$courseName,$setID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @problemData = $soapEnv->{db}->getAllGlobalProblems($setID);
    my @problems;
    for(my $i=0;$i<@problemData;$i++) {
        push(@problems,new WebworkSOAP::Classes::GlobalProblem(@problemData[$i]));
    }
    return \@problems;
}

# IN authenKey $string
# IN courseName $string
# IN problemIDs @string An array reference: [userID setID problemID]
# RETURN @WebworkSOAP::Classes::GlobalProblem Array of user objects
sub get_global_problems {
    my ($self,$authenKey,$courseName,$problemIDs) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @problemData = $soapEnv->{db}->getGlobalProblems(@$problemIDs);
    my @problems;
    for(my $i=0;$i<@problemData;$i++) {
        push(@problems,new WebworkSOAP::Classes::GlobalProblem(@problemData[$i])); #FIXME $problemData[$i]? 
    }
    return \@problems;
}

# IN authenKey $string
# IN courseName $string
# IN setID $string
# IN problemID $string
# RETURN $WebworkSOAP::Classes::GlobalProblem of names objects.
sub get_global_problem {
    my ($self,$authenKey,$courseName,$setID,$problemID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $problemData = $soapEnv->{db}->getGlobalProblem($setID,$problemID);
    if(not defined $problemData) {
        return -1;
    }
    my $problem = new WebworkSOAP::Classes::GlobalProblem($problemData);
    return ($problem);
}

# IN authenKey $string
# IN courseName $string
# IN setID $string
# IN problemID $string
# RETURN $string
sub delete_global_problem {
    my ($self,$authenKey,$courseName,$setID,$problemID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return SOAP::Data->type( 'string', $soapEnv->{db}->deleteGlobalProblem($setID,$problemID) );
}

##################################################
##USER PROBLEM
##################################################

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::UserProblem
# RETURN $string
sub add_user_problem {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newUserProblem = $soapEnv->{db}->newUserProblem;
    %$newUserProblem = %$record;
    return SOAP::Data->type( 'string', $soapEnv->{db}->addUserProblem($newUserProblem) );
}

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::UserProblem
# RETURN $string
sub put_user_problem {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return SOAP::Data->type( 'string', $soapEnv->{db}->putUserProblem($record) );
}

# IN authenKey $string
# IN courseName $string
# IN userID $string
# IN setID $string
# RETURN @string of names objects.
sub list_user_problems {
    my ($self,$authenKey,$courseName,$userID,$setID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listUserProblems($userID,$setID);
    return array_to_soap_string( @tempArray );
}

# IN authenKey $string
# IN courseName $string
# IN userID $string
# IN setID $string
# RETURN @WebworkSOAP::Classes::UserProblem of names objects.
sub get_all_user_problems {
    my ($self,$authenKey,$courseName,$userID,$setID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @problemData = $soapEnv->{db}->getAllUserProblems($userID,$setID);
    my @problems;
    for(my $i=0;$i<@problemData;$i++) {
        push(@problems,new WebworkSOAP::Classes::UserProblem(@problemData[$i]));
    }
    return \@problems;
}

# IN authenKey $string
# IN courseName $string
# IN userProblemIDs @string A 3 element array: { user_ID, setID, problemID }
# RETURN @WebworkSOAP::Classes::UserProblem of names objects.
sub get_user_problems {
    my ($self,$authenKey,$courseName,$userProblemIDs) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @problemData = $soapEnv->{db}->getUserProblems(@$userProblemIDs);
    my @problems;
    for(my $i=0;$i<@problemData;$i++) {
        push(@problems,new WebworkSOAP::Classes::UserProblem(@problemData[$i]));
    }
    return \@problems;
}

# IN authenKey $string
# IN courseName $string
# IN userID $string
# IN setID $string
# IN problemID $string
# RETURN $WebworkSOAP::Classes::UserProblem of names objects.
sub get_user_problem {
    my ($self,$authenKey,$courseName,$userID,$setID,$problemID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $problemData = $soapEnv->{db}->getUserProblem($userID,$setID,$problemID);
    if(not defined $problemData) {
        return -1;
    }
    my $problem = new WebworkSOAP::Classes::UserProblem($problemData);
    return ($problem);
}

# IN authenKey $string
# IN courseName $string
# IN userID $string
# IN setID $string
# IN problemID $string
# RETURN $string
sub delete_user_problem {
    my ($self,$authenKey,$courseName,$userID,$setID,$problemID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return SOAP::Data->type( 'string', $soapEnv->{db}->deleteUserProblem($userID,$setID,$problemID) );
}

##################################################
##USER SET
##################################################

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::UserSet
# RETURN $string
sub add_user_set {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newUserSet = $soapEnv->{db}->newUserSet;
    %$newUserSet = %$record;
    return SOAP::Data->type( 'string', $soapEnv->{db}->addUserSet($newUserSet) );
}

# IN authenKey $string
# IN courseName $string
# IN record $WebworkSOAP::Classes::UserSet
# RETURN $string
sub put_user_set {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return SOAP::Data->type( 'string', $soapEnv->{db}->addUserSet($record) );
}

# IN authenKey $string
# IN courseName $string
# IN userID $string
# RETURN @string of names objects.
sub list_user_sets {
    my ($self,$authenKey,$courseName,$userID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listUserSets($userID);
    return array_to_soap_string( @tempArray );
}

# IN authenKey $string
# IN courseName $string
# RETURN @WebworkSOAP::Classes::UserSet of names objects.
sub get_all_user_sets {
    my ($self,$authenKey,$courseName) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @setData = $soapEnv->{db}->getAllUserSets();
    my @sets;
    for(my $i=0;$i<@setData;$i++) {
        push(@sets,new WebworkSOAP::Classes::UserSet(@setData[$i]));
    }
    return \@sets;
}

# IN authenKey $string
# IN courseName $string
# IN userSetIDs $string
# RETURN @WebworkSOAP::Classes::UserSet of names objects.
sub get_user_sets {
    my ($self,$authenKey,$courseName,$userSetIDs) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @setData = $soapEnv->{db}->getUserSets(@$userSetIDs);
    my @sets;
    for(my $i=0;$i<@setData;$i++) {
        push(@sets,new WebworkSOAP::Classes::UserSet(@setData[$i]));
    }
    return \@sets;
}

# IN authenKey $string
# IN courseName $string
# IN userID $string
# IN setID $string
# RETURN $WebworkSOAP::Classes::UserSet of names objects.
sub get_user_set {
    my ($self,$authenKey,$courseName,$userID,$setID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $setData = $soapEnv->{db}->getUserSet($userID,$setID);
    if(not defined $setData) {
        return -1;
    }
    my $set = new WebworkSOAP::Classes::UserSet($setData);
    return $set;
}

# IN authenKey $string
# IN courseName $string
# IN userID $string
# IN setID $string
# RETURN $string
sub delete_user_set {
    my ($self,$authenKey,$courseName,$userID,$setID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return SOAP::Data->type( 'string', $soapEnv->{db}->deleteUserSet($userID,$setID) );
}


###########################################
# grading utilties -- to be moved to Utils::Grades
############################################

############################################
# get_wwassignment_grade_for_one ($db $userID $setID);
#input  $userID, $setID (or a UserSet record)?
#output set grade for a homework problem or maximum grade for a gateway problem with several set versions
############################################
sub get_wwassignment_grade_for_one_user{
	my($db, $userID, $setID) = @_;
	my $user_set = $db->getMergedSet($userID,$setID);
	print LOG "user $userID set $setID user_set ".ref($user_set)."\n";
	return " " unless ref($user_set);  # return a blank grade if there is no user_set
	warn " user $userID $setID ".ref($user_set)."\n";
	my $setIsVersioned = ( defined($user_set->assignment_type) && $user_set->assignment_type =~ /gateway/)?1:0;
	my @setVersions=();
	if ( $setIsVersioned ) { 
		my @vList = $db->listSetVersions($userID,$setID);
		# we have to have the merged set versions to 
		#    know what each of their assignment types 
		#    are (because proctoring can change)
		@setVersions = $db->getMergedSetVersions( map {[$userID, $setID, $_]} @vList );

		# add the set versions to our list of sets
# 		foreach ( @setVersions ) { 
# 			$setsByID{$_->set_id . ",v" . $_->version_id} = $_; 
# 		}
# 		# flag the existence of set versions for this set
# 		$setVersionsByID{$setName} = [ @vList ];
# 		# and save the set names for display
# 		push( @allSetIDs, $setName );
# 		push( @allSetIDs, map { "$setName,v$_" } @vList );

	} else {
# 		push( @allSetIDs, $setName );
# 		$setVersionsByID{$setName} = "None";
	}
	my $grade;
	if ($setIsVersioned) {
		if (@setVersions) {
		    $grade =0;
		    foreach my $setVersion (@setVersions) {  # get highest grade among versions
				#print LOG "getting set $userID $setID version:".ref($setVersion)."\n";
				my $current_grade = get_set_grade_for_UserSet($db, $setVersion);
				$grade = $current_grade if $current_grade > $grade;
				
			}
				
		} else {
			$grade = " ";
		}
	} else {  # not versioned
	    $grade = get_set_grade_for_UserSet($db, $user_set);	
	}
	$grade;   # return grade
}
	
############################################
# get_set_grade_for_UserSet ($db, $user_set);
#input  $userID, $setID (UserSet record);
#output set grade for a homework problem or a single  set version of a gateway quiz
############################################

sub get_set_grade_for_UserSet{
	my $db = shift;
	my $user_set = shift;
	warn "get_set_grade_for_UserSet(db, user_set); an argument is missing db: $db user_set $user_set" 
	    unless ref($db) =~ /DB/  and ref($user_set) =~/Set/;
	my $setIsVersioned = ( defined( $user_set->assignment_type() ) 
	     && $user_set->assignment_type() =~ /gateway/ )? 1:0;
	my @problemData=();
	print LOG "get_set_grade_for_UserSet: getting set ".$user_set->set_id." "." for ".$user_set->user_id."\n";
	if ($setIsVersioned) {	
		@problemData = $db->getAllMergedProblemVersions( $user_set->user_id, $user_set->set_id, $user_set->version_id ) if $user_set->can('version_id');
	} else {
		@problemData = $db->getAllMergedUserProblems($user_set->user_id, $user_set->set_id);
	}
        
        my $grade = 0;
        for(my $i=0;$i<@problemData;$i++) {
                #print LOG "$userID problem Data",join(" ", %{$problemData[$i]}),"\n\n";
                $grade += ($problemData[$i]->status)*($problemData[$i]->value);
                #print LOG "grade is $grade\n";
        }
	return $grade;
}
1;
