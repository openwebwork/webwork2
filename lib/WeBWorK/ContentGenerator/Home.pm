################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Home.pm,v 1.11 2005/12/02 23:35:15 sh002i Exp $
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

package WeBWorK::ContentGenerator::Home;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Home - display a list of courses.

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(readFile readDirectory);
use WeBWorK::Utils::CourseManagement qw/listCourses/;

#sub loginstatus { "" }
#sub links { "" }
#sub options { "" };
sub info {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;

	my $site_info = $ce->{webworkFiles}->{site_info};
	
	if (defined $site_info and $site_info) {
		my $site_info_path = $site_info;
		
		# deal with previewing a temporary file
		if (defined $r->param("editMode") and $r->param("editMode") eq "temporaryFile"
				and defined $r->param("editFileSuffix")) {
			$site_info_path .= $r->param("editFileSuffix");
		}
		
		if (-f $site_info_path) {
			my $text = eval { readFile($site_info_path) };
			if ($@) {
				print CGI::div({class=>"ResultsWithError"},
					CGI::p("$@"),
				);
			} elsif ($text) {
				print CGI::p(CGI::b("Important Message")), $text,CGI::hr();
			}
		}
		
		
	}
	return "";

}
sub body {
	my ($self) = @_;
	my $r = $self->r;
	
	my $coursesDir = $r->ce->{webworkDirs}->{courses};
	my $coursesURL = $r->ce->{webworkURLs}->{root};
	
	my @courseIDs = listCourses($r->ce);
	
	my $haveAdminCourse = 0;
	foreach my $courseID (@courseIDs) {
		if ($courseID eq "admin") {
			$haveAdminCourse = 1;
			last;
		}
	}
	
	print CGI::p("Welcome to WeBWorK!");
	
	if ($haveAdminCourse and !(-f "$coursesDir/admin/hide_directory")) {
		my $urlpath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", courseID => "admin");
		print CGI::p(CGI::a({href=>$self->systemLink($urlpath, authen => 0)}, "Course Administration"));
	}
	
	print CGI::h2("Courses");
	
	print CGI::start_ul();
	
	foreach my $courseID (sort {lc($a) cmp lc($b) } @courseIDs) {
		next if $courseID eq "admin"; # done already above
		next if -f "$coursesDir/$courseID/hide_directory";
		my $urlpath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", courseID => $courseID);
		print CGI::li(CGI::a({href=>$self->systemLink($urlpath, authen => 0)}, $courseID));
	}
	
	print CGI::end_ul();
	
	return "";
}

1;
