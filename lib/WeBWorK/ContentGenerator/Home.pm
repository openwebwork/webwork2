################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Test.pm,v 1.13 2003/12/09 01:12:31 sh002i Exp $
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

WeBWorK::ContentGenerator::Home - display debugging information.

=cut

use strict;
use warnings;
use CGI ();
use WeBWorK::Utils qw/readDirectory/;

sub loginstatus { "" }
sub links { "" }

sub path {
	my $self = shift;
	my $args = $_[-1];
	return $self->pathMacro($args, Home => "");
}

#sub siblings {
#	my $self = shift;
#	return $self->siblingsMacro(Test2 => "blah/", "Test Three" => "spoo");
#}

#sub nav {
#	my $self = shift;
#	my $args = $_[-1];
#	return $self->navMacro($args, "", TestMinus1 => "-1/", TestPlusOne => "+1/");
#}

sub title {
	return "WeBWorK";
}

sub body {
	my $self = shift;
	my $ce = $self->{ce};
	my $coursesDir = $ce->{webworkDirs}->{courses};
	my $coursesURL = $ce->{webworkURLs}->{root};
	
	my @courseIDs = grep { $_ ne "." and $_ ne ".." and -d "$coursesDir/$_" } readDirectory($coursesDir);
	
	print CGI::p("Welcome to WeBWorK!");
	
	print CGI::h2("Courses");
	
	print CGI::start_ul();
	
	foreach my $courseID (@courseIDs) {
		print CGI::li(CGI::a({href=>"$coursesURL/$courseID/"}, $courseID));
	}
	
	print CGI::end_ul();
	
	return "";
}

1;
