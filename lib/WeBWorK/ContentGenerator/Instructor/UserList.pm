package WeBWorK::ContentGenerator::Instructor::UserList;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::UserList - Entry point for User-specific data editing

=cut

use strict;
use warnings;
use CGI qw();

sub initialize {
}

sub body {
	my ($self, $setID) = @_;
	my $r = $self->{r};
	my $authz = $self->{authz};
	my $user = $r->param('user');
	my $db = $self->{db};
	
        return CGI::em("You are not authorized to access the Instructor tools.") unless $authz->hasPermissions($user, "access_instructor_tools");

	my @users = $db->listUsers;
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
				(map {CGI::input({type=>"text", size=>"8", value=>$userRecord->$_})} $userRecord->FIELDS()), 
				(map {CGI::input({type=>"text", size=>"8", value=>$permissionLevel->$_})} grep {! m/^user_id$/} $permissionLevel->FIELDS()),
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
	
	return "";
}

1;
