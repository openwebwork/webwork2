################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/ProblemSets.pm,v 1.39 2004/01/25 15:53:07 gage Exp $
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
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::ProblemSets - Display a list of built problem sets.

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(readFile formatDateTime sortByName);

sub path {
	my ($self, $args) = @_;
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home" => "$root",
		$courseName => "",
	);
}

sub title {
	my $self        = shift;
	my $r           = $self ->{r};
	my $db          = $self ->{db};
	my $user        = $r    -> param("user");
	my $courseName  = $self ->{ce} -> {courseName};
	
	return "WeBWorK welcomes user $user to $courseName" ;
}

sub body {
	my $self            = shift;
	my $r               = $self->{r};
	my $ce              = $self->{ce};
	my $db              = $self->{db};
	my $user            = $r->param("user");
	my $effectiveUser   = $r->param("effectiveUser");
	my $sort            = $r->param("sort") || "status";
	my $permissionLevel = $db->getPermissionLevel($user)->permission(); # checked???
	$permissionLevel    = 0 unless defined $permissionLevel;
	my $root            = $ce->{webworkURLs}->{root};
	my $courseName      = $ce->{courseName};
	
	# Print link to instructor page for instructors
	if ($permissionLevel >= 10 ) {

		my $instructorLink = "$root/$courseName/instructor/?" . $self->url_authen_args();
		print CGI::p({-align=>'center'},CGI::a({-href=>$instructorLink},'Instructor Tools'));
	}
	# Print message of the day (motd)
	if (defined $ce->{courseFiles}->{motd}
		and $ce->{courseFiles}->{motd}) {
		my $motd = eval { readFile($ce->{courseFiles}->{motd}) };
		$@ or print $motd;
	}
	
	$sort = "status" unless $sort eq "status" or $sort eq "name";
	my $baseURL = $r->uri . "?" . $self->url_authen_args();
	my $nameHeader = ($sort eq "name") ? CGI::u("Name") : CGI::a({-href=>"$baseURL&sort=name"}, "Name");
	my $statusHeader = ($sort eq "status") ? CGI::u("Status") : CGI::a({-href=>"$baseURL&sort=status"}, "Status");
	
	print CGI::startform(-method=>"POST", -action=>$r->uri."hardcopy/");
	print $self->hidden_authen_fields;
	print CGI::start_table();
	print CGI::Tr(
		CGI::th("Sel."),
		CGI::th($nameHeader),
		CGI::th($statusHeader),
		#CGI::th("Hardcopy"),
	);
	
	my @setIDs = $db->listUserSets($effectiveUser);
	
	my @userSetIDs = map {[$effectiveUser, $_]} @setIDs;
	$WeBWorK::timer->continue("Begin collecting merged sets") if defined($WeBWorK::timer);
	my @sets = $db->getMergedSets( @userSetIDs );
	$WeBWorK::timer->continue("Begin sorting merged sets") if defined($WeBWorK::timer);
	
	@sets = sortByName("set_id", @sets) if $sort eq "name";
	@sets = sort byduedate @sets if $sort eq "status";
	$WeBWorK::timer->continue("End preparing merged sets") if defined($WeBWorK::timer);
	
	foreach my $set (@sets) {
		die "set $set not defined" unless $set;
		print $self->setListRow($set, ($permissionLevel > 0),
			($permissionLevel > 0));
	}
	
	print CGI::end_table();
	my $pl = ($permissionLevel > 0 ? "s" : "");
	print CGI::p(CGI::submit("hardcopy", "Download Hardcopy for Selected Set$pl"));
	print CGI::endform();
	
	# feedback form url
	my $feedbackURL = "$root/$courseName/feedback/";
	
	#print feedback form
	print
		CGI::start_form(-method=>"POST", -action=>$feedbackURL),"\n",
		$self->hidden_authen_fields,"\n",
		CGI::hidden("module",             __PACKAGE__),"\n",
		CGI::hidden("set",                ''),"\n",
		CGI::hidden("problem",            ''),"\n",
		CGI::hidden("displayMode",        $self->{displayMode}),"\n",
		CGI::hidden("showOldAnswers",     ''),"\n",
		CGI::hidden("showCorrectAnswers", ''),"\n",
		CGI::hidden("showHints",          ''),"\n",
		CGI::hidden("showSolutions",      ''),"\n",
		CGI::p({-align=>"left"},
			CGI::submit(-name=>"feedbackForm", -label=>"Email instructor")
		),
		CGI::endform(),"\n";
	
	return "";
}

sub setListRow($$$) {
	my ($self, $set, $multiSet, $preOpenSets) = @_;
	
	my $name = $set->set_id;
	
	my $interactiveURL = "$name/?" . $self->url_authen_args;
	#my $hardcopyURL = "hardcopy/$name/?" . $self->url_authen_args;
	
	my $openDate = formatDateTime($set->open_date);
	my $dueDate = formatDateTime($set->due_date);
	my $answerDate = formatDateTime($set->answer_date);
	
	#my $checkbox = CGI::checkbox(-name=>"hcSet", -value=>$set->set_id, -label=>"");
	
	my $control = "";
	if ($multiSet) {
		$control = CGI::checkbox(
			-name=>"hcSet",
			-value=>$name,
			-label=>"",
		);
	} else {
		$control = CGI::radio_group(
			-name=>"hcSet",
			-values=>[$name],
			-default=>"-",
			-labels=>{$name => ""},
		);
	}
	
	my $interactive = CGI::a({-href=>$interactiveURL}, "set $name");
	
	my $status;
	if (time < $set->open_date) {
		$status = "opens at $openDate";
		$control = "" unless $preOpenSets;
		$interactive = $name unless $preOpenSets;
	} elsif (time < $set->due_date) {
		$status = "open, due $dueDate";
	} elsif (time < $set->answer_date) {
		$status = "closed, answers at $answerDate";
	} else {
		$status = "closed, answers available";
	}
	
	return CGI::Tr(CGI::td([
		$control,
		$interactive,
		$status,
	]));
}
sub info {
	my $self       = shift;
	my $r          = $self->{r};
	my $ce         = $self->{ce};
	my $db         = $self->{db};
	my $user       = $r->param("user");
	my $root       = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	###########################################################
	# The course information and problems are located in the course templates directory.
	# Course information has the name  defined by courseFiles->{course_info}
	# 
	# Only files under the template directory ( or linked to this location) can be edited.
	#
	# editMode = temporaryFile    (view the temp file defined by course_info.txt.user_name.tmp
	#                              instead of the file course_info.txt)
	# The editFileSuffix is "user_name.tmp" by default.  It's definition should be moved to Instructor.pm #FIXME                              
	###########################################################
	if (defined $ce->{courseFiles}->{course_info}
		and $ce->{courseFiles}->{course_info})     {
		my $course_info_path  = $ce->{courseDirs}->{templates}
		                     .'/'. $ce->{courseFiles}->{course_info};
		my $editFileSuffix			=	$user.'.tmp';  #FIXME -- this could be moved to Instructor.pm
		$course_info_path    .= ".$editFileSuffix" if defined($r->param("editMode")) and $r->param("editMode") eq 'temporaryFile';
		
		my $course_info = eval { readFile($course_info_path) };
		$@ or print $course_info;
		my $user            = $r->param("user");
		my $permissionLevel = $db->getPermissionLevel($user)->permission(); # checked???
		$permissionLevel    = 0 unless defined $permissionLevel;
 	    if ($permissionLevel>=10) {
			my $editURL = "$root/$courseName/instructor/pgProblemEditor/?"
						  .$self->url_authen_args
						  ."&file_type=course_info"
			;
			my $editText      = "Edit message file";
			$editText         = "Edit temporary message file" if $r->param("editMode") eq 'temporaryFile';
			print CGI::br(), CGI::a({-href=>$editURL}, $editText);
	    }
	    
	}
	
	
	'';
}
sub byname { $a->set_id cmp $b->set_id; }
sub byduedate { $a->due_date <=> $b->due_date; }

1;
