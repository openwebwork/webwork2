################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Home.pm,v 1.4 2004/05/07 13:47:59 gage Exp $
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
use CGI::Pretty qw();
use WeBWorK::Utils qw/readDirectory/;
use WeBWorK::Utils::CourseManagement qw/listCourses/;

sub loginstatus { "" }
sub links { "" }

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
	
	if ($haveAdminCourse) {
		my $urlpath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", courseID => "admin");
		print CGI::p(CGI::a({href=>$self->systemLink($urlpath, authen => 0)}, "Course Administration"));
	}
	
	print CGI::h2("Courses");
	
	print CGI::start_ul();
	
	foreach my $courseID (sort @courseIDs) {
		my $urlpath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", courseID => $courseID);
		print CGI::li(CGI::a({href=>$self->systemLink($urlpath, authen => 0)}, $courseID));
	}
	
	print CGI::end_ul();
	
	return "";
}

1;
