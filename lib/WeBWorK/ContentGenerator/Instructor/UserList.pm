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
		warn "processing form.\n";
		my @userList = $db->listUsers;
		foreach my $user (@userList) {
			warn "processing user $user\n";
			my $userRecord = $db->getUser($user);
			my $permissionLevelRecord = $db->getPermissionLevel($user);
			foreach my $field ($userRecord->NONKEYFIELDS()) {
				warn "processing user field $field\n";
				my $paramName = "user.${user}.${field}";
				if (defined($r->param($paramName))) {
					warn "processing parameter $paramName\n";
					$userRecord->$field($r->param($paramName));
				}
			}
			foreach my $field ($permissionLevelRecord->NONKEYFIELDS()) {
				warn "processing permission field $field\n";
				my $paramName = "permission.${user}.${field}";
				if (defined($r->param($paramName))) {
					warn "processing parameter $paramName\n";
					$permissionLevelRecord->$field($r->param($paramName));
				}
			}
			warn "saving changes\n";
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

	my @users = $db->listUsers;
	print CGI::start_form({method=>"post", action=>$r->uri()});
	print CGI::start_table({});
	print CGI::Tr({},
		CGI::td({}, [
			$db->{user}->{record}->FIELDS(),
			grep {! m/^user_id$/} $db->{permission}->{record}->FIELDS(),
		])
	);
	
	foreach my $currentUser (@users) {
		my $userRecord = $db->getUser($currentUser);
		my $permissionLevel = $db->getPermissionLevel($currentUser);
		
		print CGI::Tr({},
			CGI::td({}, [
				(map {CGI::input({type=>"text", size=>"8", name=> "user.".$userRecord->user_id().".".$_, value=>$userRecord->$_})} $userRecord->FIELDS()), 
				(map {CGI::input({type=>"text", size=>"8", name => "permission.".$permissionLevel->user_id().".".$_, value=>$permissionLevel->$_})} grep {! m/^user_id$/} $permissionLevel->FIELDS()),
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
