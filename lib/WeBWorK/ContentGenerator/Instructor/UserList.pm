package WeBWorK::ContentGenerator::Instructor::UserList;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::UserList - Entry point for User-specific data editing

=cut

use strict;
use warnings;
use CGI qw();

sub initialize {
	my ($self) = @_;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
	my $user = $r->param('user');

	unless ($authz->hasPermissions($user, "modify_student_data")) {
		$self->{submitError} = "You are not authorized to modify student data";
		return;
	}
	
	if (defined($r->param('save_classlist'))) {
		my @userList = $db->listUsers;
		foreach my $user (@userList) {
			my $userRecord = $db->getUser($user);
			my $permissionLevelRecord = $db->getPermissionLevel($user);
			foreach my $field ($userRecord->NONKEYFIELDS()) {
				my $paramName = "user.${user}.${field}";
				if (defined($r->param($paramName))) {
					$userRecord->$field($r->param($paramName));
				}
			}
			foreach my $field ($permissionLevelRecord->NONKEYFIELDS()) {
				my $paramName = "permission.${user}.${field}";
				if (defined($r->param($paramName))) {
					$permissionLevelRecord->$field($r->param($paramName));
				}
			}
			$db->putUser($userRecord);
			$db->putPermissionLevel($permissionLevelRecord);
		}
	} elsif (defined($r->param('addStudent'))) {
		my $newUser = $db->newUser;
		my $newPermissionLevel = $db->newPermissionLevel;
		my $newPassword = $db->newPassword;
		$newUser->user_id($r->param('newUserID'));
		$newPermissionLevel->user_id($r->param('newUserID'));
		$newPassword->user_id($r->param('newUserID'));
		$newUser->status('C');
		$newPermissionLevel->permission(0);
		$db->addUser($newUser);
		$db->addPermissionLevel($newPermissionLevel);
		$db->addPassword($newPassword);
	}
}

sub body {
	my ($self, $setID) = @_;
	my $r = $self->{r};
	my $authz = $self->{authz};
	my $user = $r->param('user');
	my $db = $self->{db};
	my $userTemplate = $db->newUser;
	my $permissionLevelTemplate = $db->newPermissionLevel;
	
        return CGI::em("You are not authorized to access the Instructor tools.") unless $authz->hasPermissions($user, "access_instructor_tools");

	# This code will require changing if the permission and user tables ever have different keys.
	my @users = $db->listUsers;

	# This table can be consulted when display-ready forms of field names are needed.
	my %prettyFieldNames = map {$_ => $_} ($userTemplate->FIELDS(), $permissionLevelTemplate->FIELDS());
	@prettyFieldNames{qw(
		user_id 
		first_name 
		last_name 
		email_address 
		student_id 
		status 
		section 
		recitation 
		comment 
		permission
	)} = (
		"User ID", 
		"First Name", 
		"Last Name", 
		"E-mail", 
		"Student ID", 
		"Status", 
		"Section", 
		"Recitation", 
		"Comment", 
		"Perm. Level"
	);

	print CGI::start_form({method=>"post", action=>$r->uri()});
	print CGI::start_table({});
	
	# Table headings, prettied-up
	print CGI::Tr({},
		CGI::th({}, [
			map {$prettyFieldNames{$_}} (
				$userTemplate->KEYFIELDS(),
				$userTemplate->NONKEYFIELDS(),
				$permissionLevelTemplate->NONKEYFIELDS(),
			)
		])
	);
	
	foreach my $currentUser (@users) {
		my $userRecord = $db->getUser($currentUser);
		my $permissionLevel = $db->getPermissionLevel($currentUser);
		
		# A concise way of printing a row containing a cell for each field, editable unless it's a key
		print CGI::Tr({},
			CGI::td({}, [
				(map {$userRecord->$_} $userRecord->KEYFIELDS),
				(map {CGI::input({type=>"text", size=>"8", name=> "user.".$userRecord->user_id().".".$_, value=>$userRecord->$_})} $userRecord->NONKEYFIELDS()), 
				(map {CGI::input({type=>"text", size=>"8", name => "permission.".$permissionLevel->user_id().".".$_, value=>$permissionLevel->$_})} $permissionLevel->NONKEYFIELDS()),
			])
		);
	}
	
	print CGI::end_table();
	print $self->hidden_authen_fields();
	print CGI::submit({name=>"save_classlist", value=>"Save Changes to Users"});
	print CGI::end_form();
	
	# Add a student form
	print CGI::start_form({method=>"post", action=>$r->uri()});
	print $self->hidden_authen_fields();
	print "User ID:";
	print CGI::input({type=>"text", name=>"newUserID", value=>"", size=>"20"});
	print CGI::submit({name=>"addStudent", value=>"Add Student"});
	print CGI::end_form();
	
	return "";
}

1;
