package WeBWorK::ContentGenerator::Instructor;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Instructor - Abstract superclass for the Instructor pages

=cut

use strict;
use warnings;
use CGI qw();

 sub links {
 	my $self 		= shift;
 	
 	# keep the links from the parent
 	my $pathString 	= "";
 	
	
	my $ce = $self->{ce};
	my $db = $self->{db};
	my $userName = $self->{r}->param("user");
	my $courseName = $ce->{courseName};
	my $root = $ce->{webworkURLs}->{root};
	my $permLevel = $db->getPermissionLevel($userName)->permission();
	my $key = $db->getKey($userName)->key();
	return "" unless defined $key;
	
	# new URLS
	my $classList	= "$root/$courseName/instructor/userList/?". $self->url_authen_args();
	my $addStudent  = "$root/$courseName/instructor/addStudent/?". $self->url_authen_args();
	my $problemSetList = "$root/$courseName/instructor/problemSetList/?". $self->url_authen_args();
	
	if ($permLevel > 0 ) {
		$pathString .="<hr>";
		$pathString .=  CGI::a({-href=>$classList}, "Class&nbsp;editor") . CGI::br();
		$pathString .=  '&nbsp;&nbsp;'.CGI::a({-href=>$addStudent}, "Add&nbsp;Student") . CGI::br();
		$pathString .= CGI::a({-href=>$problemSetList}, "ProbSet&nbsp;list") . CGI::br();
	}
	return $self->SUPER::links() . $pathString;
}

1;
