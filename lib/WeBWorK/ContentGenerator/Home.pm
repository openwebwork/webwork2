################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Home.pm,v 1.1 2004/02/14 00:54:53 sh002i Exp $
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

sub loginstatus { "" }
sub links { "" }

sub body {
	my ($self) = @_;
	my $r = $self->r;
	
	my $coursesDir = $r->ce->{webworkDirs}->{courses};
	my $coursesURL = $r->ce->{webworkURLs}->{root};
	
	my @courseIDs = grep { $_ ne "." and $_ ne ".." and -d "$coursesDir/$_" } readDirectory($coursesDir);
	
	print CGI::p("Welcome to WeBWorK!");
	
	print CGI::h2("Courses");
	
	print CGI::start_ul();
	
	foreach my $courseID (@courseIDs) {
		my $urlpath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", courseID => $courseID);
		print CGI::li(CGI::a({href=>$self->systemLink($urlpath, authen => 0)}, $courseID));
	}
	
	print CGI::end_ul();
	
	return "";
}

1;
