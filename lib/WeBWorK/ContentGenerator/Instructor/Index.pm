################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Instructor::Index;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Index - Menu interface to the Instructor pages

=cut

use strict;
use warnings;
use CGI qw();

sub path {
	my $self          = shift;
	my $args          = $_[-1];
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home"          => "$root",
		$courseName     => "$root/$courseName",
		'instructor'    => '',
	);
}

sub title {
	my $self = shift;
	return "Instructor tools for ".$self->{ce}->{courseName};
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $db = $self->{db};
	my $authz = $self->{authz};
	my $courseName = $ce->{courseName};
	my $authen_args = $self->url_authen_args();
	my $user = $r->param('user');
	my $prof_url = $ce->{webworkURLs}->{oldProf};
	my $full_url = "$prof_url?course=$courseName&$authen_args";
	my $userEditorURL = "users/?" . $self->url_args;
	my $problemSetEditorURL = "sets/?" . $self->url_args;
	my $statsURL       = "stats/?" . $self->url_args;
	my $emailURL       = "send_mail/?" . $self->url_args;
	################### debug code
#     my $permissonLevel =  $self->{db}->getPermissionLevel($user)->permission();
#     
#     my $courseEnvironmentLevels = $self->{ce}->{permissionLevels};
#     return CGI::em(" user $permissonLevel permlevels ".join("<>",%$courseEnvironmentLevels));
    ################### debug code
	return CGI::em('You are not authorized to access the Instructor tools.') unless $authz->hasPermissions($user, 'access_instructor_tools');

	return join("", 
		CGI::start_table({-border=>2,-cellpadding=>10}),
		CGI::Tr({-align=>'center'},
			CGI::td(
				CGI::a({href=>$userEditorURL}, "Edit $courseName class list")  ,
			),
			CGI::td(
				CGI::a({href=>$problemSetEditorURL}, "Edit $courseName problem sets"),
					
			),"\n",
		),
		CGI::Tr({ -align=>'center'},
			CGI::td([
				CGI::a({-href=>$emailURL}, "Send e-mail to $courseName"),
				CGI::a({-href=>$statsURL}, "Statistics for $courseName"),
			]),
			"\n",
		),
		CGI::Tr({ -align=>'center'},
			CGI::td([
				'WeBWorK 1.9 Instructor '.CGI::a({-href=>$full_url}, 'Tools'),
				'Open WeBWorK 1.0 Instructor '.CGI::a({-href=>$full_url, -target=>'_new'}, 'Tools').' in new window',
			]),
			"\n",
		),
		
		CGI::end_table(),
	);
}

1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu

=cut
