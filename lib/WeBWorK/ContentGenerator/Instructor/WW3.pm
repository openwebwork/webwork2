################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: 
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

package WeBWorK::ContentGenerator::Instructor::WW3;
use base qw(WeBWorK);
use base qw(WeBWorK::ContentGenerator::Instructor);
use JSON qw(to_json);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::WW3 - provides redirect to WW3 tools

=cut




use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI qw/redirect/;
use WeBWorK::Debug;

sub footer(){
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $ww_version = $ce->{WW_VERSION}||"unknown -- set ww version VERSION";
	my $pg_version = $ce->{PG_VERSION}||"unknown -- set pg version PG_VERSION link to ../pg/VERSION";
	my $theme = $ce->{defaultTheme}||"unknown -- set defaultTheme in localOverides.conf";
	my $copyright_years = $ce->{WW_COPYRIGHT_YEARS}||"1996-2011";
	# print CGI::div({-id=>"last-modified"}, $r->maketext("Page generated at [_1]", timestamp($self)));
	print CGI::div({-id=>"copyright",class=>"nav navbar-text"}, "WeBWorK &#169; $copyright_years", "| theme: $theme | ww_version: $ww_version | pg_version: $pg_version|", CGI::a({-href=>"http://webwork.maa.org/"}, $r->maketext("The WeBWorK Project"), ));
	return ""
}


sub pre_header_initialize {
	my $self          = shift;
	my $r             = $self->r;
	my $urlpath       = $r->urlpath;
	print redirect("/webwork3/courses/". $urlpath->arg("courseID") . "/manager?user=" . $r->param("user"));

}



1;
=head1 AUTHOR

Written by Peter Staab at (pstaab  at  fitchburgstate.edu)

=cut
