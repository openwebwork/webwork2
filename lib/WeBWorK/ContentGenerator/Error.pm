################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Error.pm,v 1.5 2004/06/30 15:18:49 toenail Exp $
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

package WeBWorK::ContentGenerator::Error;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Error - handles invalid course requests

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Form;
use WeBWorK::Utils qw(ref2string);
use Apache::Constants qw(:http :common);

#sub loginstatus { "" }
#sub links { "" }

sub header {
	my $self = shift;
	my $r = $self->r;
	
	$r->status(HTTP_NOT_FOUND);
	$r->content_type("text/html");
	$r->send_http_header();
	
	# normally header() would return the proper status
	# but returning a status of HTTP_NOT_FOUND appends
	# a 404 Not Found body as well as just a header, which we don't want
	return;
}

sub title {
	my $self = shift;
	my $r = $self->r;
	
	return "404 Not Found";
}

sub body {
	my $self = shift;
	my $r = $self->r;
	my $urlpath = $r->urlpath;
	
	my $courseID = $urlpath->arg('courseID');
	
	print CGI::div({class=>"ResultsWithError"}, "The requested course \"$courseID\" does not exist or is not valid.");
	print CGI::p("Click " . CGI::a({href => "/webwork2/"}, "here") . " for a list of valid course names.");
	return "";
}
1;
