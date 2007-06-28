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
$WebworkSOAP::SeedCE{soap_authen_key} = "123456789123456789";
$WebworkSOAP::SeedCE{webwork_dir} = "/home/mleventi/webwork_projects/webwork/webwork2/";

sub new {
    my($self,$authenKey,$courseName) = @_;
    $self = {};
    #Construct Course
    my $ce = eval { new WeBWorK::CourseEnvironment({%SeedCE, courseName => $courseName }) };
    $@ and soap_fault_major("Course Environment cannot be constructed.");
    #Authentication Check
    if($ce->{soap_authen_key} != $authenKey) {
        soap_fault_authen();
    }
    #Construct DB handle
    my $db = eval { new WeBWorK::DB($ce->{dbLayout}); };
    $@ and soap_fault_major("Failed to initialize database handle.");
    $self->{db} = $db;
    $self->{ce} = $ce;
    bless $self;
    return $self;
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

=pod
=begin WSDL
_RETURN $string Hello World!
=cut
sub hello {
    return "Hello world!";
}

#################################################
#Course
#################################################

=pod
=begin WSDL
_IN authenKey $string
_RETURN @string
=end WSDL
=cut
sub list_courses {
    my ($self,$authenKey) = @_;
    my $ce = eval { new WeBWorK::CourseEnvironment({%WeBWorK::SeedCE })};
    $@ and soap_fault_major("Internal Course Environment cannot be constructed.");
    if($authenKey != $WebworkSOAP::SeedCE{soap_authen_key}) {
        soap_fault_authen;
    }
    return $WebworkSOAP::SeedCE{soap_authen_key};
    $@ and soap_fault_major("Course Environment cannot be constructed.");
    my @test = listCourses($ce);
    return \@test;
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userID $string
_RETURN $string
=end WSDL
=cut
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
    return $newKey;
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userID $string
_IN setID $string
_RETURN $string
=end WSDL
=cut
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
    return @results;
}


####################################################################
##FUNCTIONS DIRECTLY MAPPED TO FUNCTIONS IN DB.pm
####################################################################
###############################################
##Password
###############################################

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::Password
_RETURN $integer
=end WSDL
=cut
sub add_password {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newPassword = $soapEnv->{db}->newPassword;
    %$newPassword = %$record;
    return $soapEnv->{db}->addPassword($newPassword);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::Password
_RETURN $integer
=end WSDL
=cut
sub put_password {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return $soapEnv->{db}->putPassword($record);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_RETURN @string
=end WSDL
=cut
sub list_password {
    my ($self,$authenKey,$courseName) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listPasswords;
    return \@tempArray;
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userIDs @string
_RETURN @WebworkSOAP::Classes::Password Array of user objects
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userID $string
_RETURN $WebworkSOAP::Classes::Password of names objects.
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::Permission
_RETURN $integer
=end WSDL
=cut
sub add_permission {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newPermissionLevel = $soapEnv->{db}->newPermissionLevel;
    %$newPermissionLevel = %$record;
    return $soapEnv->{db}->addPermissionLevel($newPermissionLevel);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::Permission
_RETURN $integer
=end WSDL
=cut
sub put_permission {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return $soapEnv->{db}->putPermissionLevel($record);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_RETURN @string
=end WSDL
=cut
sub list_permissions {
    my ($self,$authenKey,$courseName) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listPermissionLevels;
    return \@tempArray;
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userIDs @string
_RETURN @WebworkSOAP::Classes::Permission Array of user objects
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userID $string
_RETURN $WebworkSOAP::Classes::Permission of names objects.
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::Key
_RETURN $integer
=end WSDL
=cut
sub add_key {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newKey = $soapEnv->{db}->newKey;
    %$newKey = %$record;
    return $soapEnv->{db}->addKey($newKey);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::Key
_RETURN $integer
=end WSDL
=cut
sub put_key {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return $soapEnv->{db}->putKey($record);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_RETURN @string
=end WSDL
=cut
sub list_keys {
    my ($self,$authenKey,$courseName) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listKeys;
    return \@tempArray;
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userIDs @string
_RETURN @WebworkSOAP::Classes::Key Array of user objects
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userID $string
_RETURN $WebworkSOAP::Classes::Key of names objects.
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::User
_RETURN $integer
=end WSDL
=cut
sub add_user {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newUser = $soapEnv->{db}->newUser;
    %$newUser = %$record;
    return $soapEnv->{db}->addUser($newUser);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::User
_RETURN $integer
=end WSDL
=cut
sub put_user {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return $soapEnv->{db}->putUser($record);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_RETURN @string of names objects.
=end WSDL
=cut
sub list_users {
    my ($self,$authenKey,$courseName) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listUsers;
    return \@tempArray;
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userID $string
_RETURN $WebworkSOAP::Classes::User of names objects.
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userIDs @string
_RETURN @WebworkSOAP::Classes::User Array of user objects
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userID $string
_RETURN $integer
=end WSDL
=cut
sub delete_user {
    my ($self,$authenKey,$courseName,$userID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return $soapEnv->{db}->deleteUser($userID);
}

##################################################
##Global Sets
##################################################

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::GlobalSet
_RETURN $integer
=end WSDL
=cut
sub add_global_set {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newGlobalSet = $soapEnv->{db}->newGlobalSet;
    %$newGlobalSet = %$record;
    return $soapEnv->{db}->addGlobalSet($newGlobalSet);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::GlobalSet
_RETURN $integer
=end WSDL
=cut
sub put_global_set {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return $soapEnv->{db}->putGlobalSet($record);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_RETURN @string of names objects.
=end WSDL
=cut
sub list_global_sets {
    my ($self,$authenKey,$courseName) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listGlobalSets;
    return \@tempArray;
}


=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_RETURN @WebworkSOAP::Classes::GlobalSet Array of user objects
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN setIDs @string
_RETURN @WebworkSOAP::Classes::GlobalSet Array of user objects
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN setID $string
_RETURN $WebworkSOAP::Classes::GlobalSet
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN setID $string
_RETURN $integer
=end WSDL
=cut
sub delete_global_set {
    my ($self,$authenKey,$courseName,$setID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return $soapEnv->{db}->deleteGlobalSet($setID);
}

##################################################
##Global Problems
##################################################

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::GlobalProblem
_RETURN $integer
=end WSDL
=cut
sub add_global_problem {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newGlobalProblem = $soapEnv->{db}->newGlobalProblem;
    %$newGlobalProblem = %$record;
    return $soapEnv->{db}->addGlobalProblem($newGlobalProblem);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::GlobalProblem
_RETURN $integer
=end WSDL
=cut
sub put_global_problem {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return $soapEnv->{db}->putGlobalProblem($record);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN setID $string
_RETURN @string of names objects.
=end WSDL
=cut
sub list_global_problems {
    my ($self,$authenKey,$courseName,$setID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listGlobalProblems($setID);
    return \@tempArray;
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN setID $string
_RETURN @WebworkSOAP::Classes::GlobalProblem Array of user objects
=end WSDL
=cut
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

=pod
=begin
_IN authenKey $string
_IN courseName $string
_IN problemIDs @string
_RETURN @WebworkSOAP::Classes::GlobalProblem Array of user objects
=end WSDL
=cut
sub get_global_problems {
    my ($self,$authenKey,$courseName,$problemIDs) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @problemData = $soapEnv->{db}->getGlobalProblems(@$problemIDs);
    my @problems;
    for(my $i=0;$i<@problemData;$i++) {
        push(@problems,new WebworkSOAP::Classes::GlobalProblem(@problemData[$i]));
    }
    return \@problems;
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN setID $string
_IN problemID $string
_RETURN $WebworkSOAP::Classes::GlobalProblem of names objects.
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN setID $string
_IN problemID $string
_RETURN $integer
=end WSDL
=cut
sub delete_global_problem {
    my ($self,$authenKey,$courseName,$setID,$problemID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return $soapEnv->{db}->deleteGlobalProblem($setID,$problemID);
}

##################################################
##USER PROBLEM
##################################################

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::UserProblem
_RETURN $integer
=end WSDL
=cut
sub add_user_problem {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newUserProblem = $soapEnv->{db}->newUserProblem;
    %$newUserProblem = %$record;
    return $soapEnv->{db}->addUserProblem($newUserProblem);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::UserProblem
_RETURN $integer
=end WSDL
=cut
sub put_user_problem {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return $soapEnv->{db}->putUserProblem($record);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userID $string
_RETURN @string of names objects.
=end WSDL
=cut
sub list_user_problems {
    my ($self,$authenKey,$courseName,$userID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listUserProblems($userID);
    return \@tempArray;
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userID $string
_IN setID $string
_RETURN @WebworkSOAP::Classes::UserProblem of names objects.
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userProblemIDs @string
_RETURN @WebworkSOAP::Classes::UserProblem of names objects.
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userID $string
_IN setID $string
_IN problemID $string
_RETURN $WebworkSOAP::Classes::UserProblem of names objects.
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userID $string
_IN setID $string
_IN problemID $string
_RETURN $integer
=end WSDL
=cut
sub delete_user_problem {
    my ($self,$authenKey,$courseName,$userID,$setID,$problemID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return $soapEnv->{db}->deleteUserProblem($userID,$setID,$problemID);
}

##################################################
##USER SET
##################################################

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::UserSet
_RETURN $integer
=end WSDL
=cut
sub add_user_set {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my $newUserSet = $soapEnv->{db}->newUserSet;
    %$newUserSet = %$record;
    return $soapEnv->{db}->addUserSet($newUserSet);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN record $WebworkSOAP::Classes::UserSet
_RETURN $integer
=end WSDL
=cut
sub put_user_set {
    my ($self,$authenKey,$courseName,$record) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return $soapEnv->{db}->addUserSet($record);
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userID $string
_RETURN @string of names objects.
=end WSDL
=cut
sub list_user_sets {
    my ($self,$authenKey,$courseName,$userID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    my @tempArray = $soapEnv->{db}->listUserSets($userID);
    return \@tempArray;
}

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_RETURN @WebworkSOAP::Classes::UserSet of names objects.
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userSetIDs $string
_RETURN @WebworkSOAP::Classes::UserSet of names objects.
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userID $string
_IN setID $string
_RETURN $WebworkSOAP::Classes::UserSet of names objects.
=end WSDL
=cut
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

=pod
=begin WSDL
_IN authenKey $string
_IN courseName $string
_IN userID $string
_IN setID $string
_RETURN $integer
=end WSDL
=cut
sub delete_user_set {
    my ($self,$authenKey,$courseName,$userID,$setID) = @_;
    my $soapEnv = new WebworkSOAP($authenKey,$courseName);
    return $soapEnv->{db}->deleteUserSet($userID,$setID);
}


1;
