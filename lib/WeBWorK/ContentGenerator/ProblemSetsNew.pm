################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/ProblemSets.pm,v 1.94 2010/01/31 02:31:04 apizer Exp $
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

package WeBWorK::ContentGenerator::ProblemSets;
use base qw(WeBWorK);
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::ProblemSets - Display a list of built problem sets.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::Utils qw(readFile sortByName path_is_subdir);
use WeBWorK::Localize;
# what do we consider a "recent" problem set?
use constant RECENT => 2*7*24*60*60 ; # Two-Weeks in seconds

# template method
sub templateName {
	return "lbtwo";
}

sub initialize {



# get result and send to message
	my ($self) = @_;
	my $r = $self->r;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $user               = $r->param("user");
	my $effectiveUser      = $r->param("effectiveUser");
	if ($authz->hasPermissions($user, "access_instructor_tools")) {
		# get result and send to message
		my $status_message = $r->param("status_message");
		$self->addmessage(CGI::p("$status_message")) if $status_message;
	

	}
}

sub head{
	my $self = shift;
	my $r = $self->r;
    	my $ce = $r->ce;

	my $site_url = $ce->{webworkURLs}->{htdocs};
    	print "<link rel='stylesheet' href='$site_url/js/lib/vendor/editablegrid-2.0.1/editablegrid-2.0.1.css' type='text/css' media='screen'>";
        print "<link rel='stylesheet' type='text/css' href='$site_url/css/problemsetlist.css' > </style>";
	#print "<link rel='stylesheet' type='text/css' href='$site_url/js/lib/vendor/jquery-ui-for-classlist3/css/ui-lightness/jquery-ui-1.8.21.custom.css' > </style>";
	return "";
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	my $courseName   = $urlpath->arg("courseID");
	my $setID        = $urlpath->arg("setID");       
	my $user         = $r->param('user');
	
	my $root = $ce->{webworkURLs}->{root};

	
my $template = HTML::Template->new(filename => $WeBWorK::Constants::WEBWORK_DIRECTORY . '/htdocs/html-templates/frontpage.html');  
	print $template->output();

	print $self->hidden_authen_fields;
	print CGI::hidden({id=>'hidden_courseID',name=>'courseID',default=>$courseName });



	return "";
}

# prints out the necessary JS for this page

sub output_JS{
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my $site_url = $ce->{webworkURLs}->{htdocs};
	print qq!<script data-main="$site_url/js/apps/FrontPage/FrontPage" src="$site_url/js/lib/vendor/requirejs/require.js"></script>!;


	
	return "";
}


1;
