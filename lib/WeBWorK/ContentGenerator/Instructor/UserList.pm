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
	}
}

sub body {
	my ($self, $setID) = @_;
	my $r = $self->{r};
	my $authz = $self->{authz};
	my $user = $r->param('user');
	my $db = $self->{db};
	
        return CGI::em("You are not authorized to access the Instructor tools.") unless $authz->hasPermissions($user, "access_instructor_tools");

	# This code will require changing if the permission and user tables ever have different keys.
	my @users = $db->listUsers;
	print CGI::start_form({method=>"post", action=>$r->uri()});
	print CGI::start_table({});
	print CGI::Tr({},
		CGI::th({}, [
			$db->{user}->{record}->KEYFIELDS(),
			$db->{user}->{record}->NONKEYFIELDS(),
			$db->{permission}->{record}->NONKEYFIELDS(),
		])
	);
	
	foreach my $currentUser (@users) {
		my $userRecord = $db->getUser($currentUser);
		my $permissionLevel = $db->getPermissionLevel($currentUser);
		
		print CGI::Tr({},
			CGI::td({}, [
				(map {$userRecord->$_} $userRecord->KEYFIELDS),
				(map {CGI::input({type=>"text", size=>"8", name=> "user.".$userRecord->user_id().".".$_, value=>$userRecord->$_})} $userRecord->NONKEYFIELDS()), 
				(map {CGI::input({type=>"text", size=>"8", name => "permission.".$permissionLevel->user_id().".".$_, value=>$permissionLevel->$_})} $permissionLevel->NONKEYFIELDS()),
			])
		);
		
#		foreach my $key ($userRecord->FIELDS) {
#			print "$key: ", $userRecord->$key, CGI::br();
#		}
#		foreach my $key ($permissionLevel->FIELDS) {
#			print "$key: ", $permissionLevel->$key, CGI::br();
#		}
#		print CGI::p();
	}
	print CGI::end_table();
	print $self->hidden_authen_fields();
	print CGI::submit({name=>"save_classlist", value=>"Save Changes to Users"});
	print CGI::end_form();
	
	return "";
}

1;
