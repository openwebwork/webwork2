################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/Assigner.pm,v 1.17 2004/03/06 21:49:48 sh002i Exp $
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
use WeBWorK::HTML::ScrollingRecordList qw/scrollingRecordList/;

#sub path {
#	my $self          = shift;
#	my $args          = $_[-1];
#	
#	my $ce = $self->{ce};
#	my $root = $ce->{webworkURLs}->{root};
#	my $courseName = $ce->{courseName};
#	
#	return $self->pathMacro($args,
#		"Home"             => "$root",
#		$courseName        => "$root/$courseName",
#		"Instructor Tools" => "$root/$courseName/instructor",
#		"Set Assigner"     => ""
#	);
#}

#sub title {
#	my ($self) = @_;
#	return "Set Assigner"
#}

sub body {
	my ($self) = @_;
	my $r = $self->{r};
	my $db = $self->{db};
	
	print CGI::p("Select one or more sets and one or more users below to assign"
		. "each selected set to all selected users.");
	
	my @userIDs = $db->listUsers;
	my @Users = $db->getUsers(@userIDs);
	
	my @globalSetIDs = $db->listGlobalSets;
	my @GlobalSets = $db->getGlobalSets(@globalSetIDs);
	
	my @selected_users = $r->param("selected_users");
	my @selected_sets = $r->param("selected_sets");
	
	if (defined $r->param("assign")) {
		if  (@selected_users && @selected_sets) {
			my @results = $self->assignSetsToUsers(\@selected_sets, \@selected_users);
			
			if (@results) {
				print CGI::div({class=>"ResultsWithError"},
					CGI::p("The following error(s) occured while assigning:"),
					CGI::ul(CGI::li(\@results)),
				);
			} else {
				print CGI::div({class=>"ResultsWithoutError"},
					CGI::p("All assignments were made successfully."),
				);
			}
		} else {
			print CGI::div({class=>"ResultsWithError"},
				@selected_users ? () : CGI::p("You must select one or more users below."),
				@selected_sets ? () : CGI::p("You must select one or more sets below."),
			);
		}
	}
	
	my $scrolling_user_list = scrollingRecordList({
			name => "selected_users",
			request => $r,
			default_sort => "lnfn",
			default_format => "lnfn_uid",
			size => 20,
			multiple => 1,
		}, @Users);
	
	my $scrolling_set_list = scrollingRecordList({
		name => "selected_sets",
		request => $r,
		default_sort => "set_id",
		default_format => "set_id",
		size => 20,
		multiple => 1,
	}, @GlobalSets);
	
	print CGI::start_form({method=>"post", action=>$r->uri()});
	print $self->hidden_authen_fields();
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr(
			CGI::th("Users"),
			CGI::th("Sets"),
		),
		CGI::Tr(
			CGI::td($scrolling_user_list),
			CGI::td($scrolling_set_list),
		),
		CGI::Tr(
			CGI::td({colspan=>2, align=>"center"},
				CGI::submit(
					-name => "assign",
					-value => "Assign selected sets to selected users",
				),
			),
		),
	);
	
	print CGI::end_form();
	
	return "";
}

1;
