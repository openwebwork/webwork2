################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/Assigner.pm,v 1.13 2004/01/21 20:53:32 sh002i Exp $
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

package WeBWorK::ContentGenerator::Instructor::Assigner;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Assigner - Assign problem sets to users.

=cut

use strict;
use warnings;
use CGI qw();

sub initialize {
	my ($self, $setID) = @_;
}

sub path {
	my $self          = shift;
    my @components    = @_;
	my $args          = $_[-1];
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home"             => "$root",
		$courseName        => "$root/$courseName",
		"Instructor Tools" => "$root/$courseName/instructor",
		"Set Assigner"     => ""
	);
}

sub title {
	my ($self, @components) = @_;
	return "Set Assigner"
}

sub body {
	my ($self, $setID) = @_;
	
	print CGI::p("This module will allow the assignment of multiple sets to"
		. "multiple users, all in one shot. First, we write it.");
	
	return "";
}

1;
