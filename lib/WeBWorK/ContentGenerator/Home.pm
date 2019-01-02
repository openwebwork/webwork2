################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Home.pm,v 1.19 2006/07/12 01:23:54 gage Exp $
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
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Utils qw(readFile readDirectory);
use WeBWorK::Utils::CourseManagement qw/listCourses/;
use WeBWorK::Localize;
sub info {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;

	my $result;
	
	# This section should be kept in sync with the Login.pm version
	my $site_info = $ce->{webworkFiles}->{site_info};
	if (defined $site_info and $site_info) {
		# deal with previewing a temporary file
		# FIXME: DANGER: this code allows viewing of any file
		# FIXME: this code is disabled because PGProblemEditor no longer uses editFileSuffix
		#if (defined $r->param("editMode") and $r->param("editMode") eq "temporaryFile"
		#		and defined $r->param("editFileSuffix")) {
		#	$site_info .= $r->param("editFileSuffix");
		#}
		
		if (-f $site_info) {
			my $text = eval { readFile($site_info) };
			if ($@) {
				$result = CGI::div({class=>"ResultsWithError"}, $@);
			} elsif ($text =~ /\S/) {
				$result = $text;
			}
		}
	}
	
	if (defined $result and $result ne "") {
#		return CGI::div({-class=>"info-wrapper"},CGI::div({class=>"info-box", id=>"InfoPanel"},
#			CGI::h2("Site Information"), $result));
	    return CGI::h2($r->maketext("Site Information")). $result;
	} else {
		return "";
	}
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	
	my $coursesDir = $r->ce->{webworkDirs}->{courses};
	my $coursesURL = $r->ce->{webworkURLs}->{root};
	
	my @courseIDs = listCourses($r->ce);
	#filter underscores here!
	
	my $haveAdminCourse = 0;
	foreach my $courseID (@courseIDs) {
		if ($courseID eq "admin") {
			$haveAdminCourse = 1;
			last;
		}
	}
	
	print CGI::p($r->maketext("Welcome to WeBWorK!"));
	
	if ($haveAdminCourse and !(-f "$coursesDir/admin/hide_directory")) {
		my $urlpath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r, courseID => "admin");
		print CGI::p(CGI::a({href=>$self->systemLink($urlpath, authen => 0)}, $r->maketext("Course Administration")));
	}
	
	print CGI::h2($r->maketext("Courses"));
	
	print CGI::start_ul({class => "courses-list"});
	
	foreach my $courseID (sort {lc($a) cmp lc($b) } @courseIDs) {
		next if $courseID eq "admin"; # done already above
		next if -f "$coursesDir/$courseID/hide_directory";
		my $urlpath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r, courseID => $courseID);
		print CGI::li(CGI::a({href=>$self->systemLink($urlpath, authen => 0)}, $courseID));
	}###place to use underscore sub
	
	print CGI::end_ul();
	
	return "";
}

1;
