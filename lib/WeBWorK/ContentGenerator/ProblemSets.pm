################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/ProblemSets.pm,v 1.49 2004/05/23 18:51:47 gage Exp $
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

sub info {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	
	my $courseID = $urlpath->arg("courseID");
	my $userID = $r->param("user");
	
	my $course_info = $ce->{courseFiles}->{course_info};
	
	if (defined $course_info and $course_info) {
		my $course_info_path = $ce->{courseDirs}->{templates} . "/$course_info";
		
		my $PermissionLevel = $db->getPermissionLevel($userID);
		my $level = $PermissionLevel ? $PermissionLevel->permission() : 0;
		
		# deal with instructor crap
		if ($level > 0) {
			if (defined $r->param("editMode") and $r->param("editMode") eq "temporaryFile") {
				$course_info_path .= ".$userID.tmp"; # this gets a big FIXME for obvious reasons
			}
			
			my $editorPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor", courseID => $courseID);
			my $editorURL = $self->systemLink($editorPage, params => { file_type => "course_info" });
			
			print CGI::p(CGI::b("Course Info"), " ",
				CGI::a({href=>$editorURL}, "[edit]"));
		} else {
			print CGI::p(CGI::b("Course Info"));
		}
		
		if (-f $course_info_path) {
			my $text = eval { readFile($course_info_path) };
			if ($@) {
				print CGI::div({class=>"ResultsWithError"},
					CGI::p("$@"),
				);
			} else {
				print $text;
			}
		}
		
		return "";
	}
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	
	my $user            = $r->param("user");
	my $effectiveUser   = $r->param("effectiveUser");
	my $sort            = $r->param("sort") || "status";
	
	my $permissionLevel = $db->getPermissionLevel($user)->permission(); # checked
	$permissionLevel    = 0 unless defined $permissionLevel;
	
	my $courseName      = $urlpath->arg("courseID");
	
	# Print link to instructor page for instructors
	if ($permissionLevel >= 10) {
		my $instructorPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::Index", courseID => $courseName);
		my $instructorLink = $self->systemLink($instructorPage);
		print CGI::p({-align=>'center'},CGI::a({-href=>$instructorLink},'Instructor Tools'));
	}
	
	# I think this is deprecated!
	# Print message of the day (motd)
	#if (defined $ce->{courseFiles}->{motd}
	#	and $ce->{courseFiles}->{motd}) {
	#	my $motd = eval { readFile($ce->{courseFiles}->{motd}) };
	#	$@ or print $motd;
	#}
	
	$sort = "status" unless $sort eq "status" or $sort eq "name";
	my $nameHeader = $sort eq "name"
		? CGI::a({href=>$self->systemLink($urlpath, params=>{sort=>"name"})}, "Name")
		: CGI::u("Name");
	my $statusHeader = $sort eq "status"
		? CGI::a({href=>$self->systemLink($urlpath, params=>{sort=>"status"})}, "Status")
		: CGI::u("Status");
	my $hardcopyPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Hardcopy", courseID => $courseName);
	my $actionURL = $self->systemLink($hardcopyPage, authen => 0); # no authen info for form action
	
	print CGI::startform(-method=>"POST", -action=>$actionURL);
	print $self->hidden_authen_fields;
	print CGI::start_table();
	print CGI::Tr(
		CGI::th("Sel."),
		CGI::th($nameHeader),
		CGI::th($statusHeader),
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
		
		# FIXME: This is a temporary fix to fill in the database
		#	 We want the published field to contain either 1 or 0 so if it has not been set to 0, default to 1
		#	this will fill in all the empty fields but not change anything that has been specifically set to 1 or 0
	    # $set->published("1") unless $set->published("1") eq "0";
	    # don't show unpublished sets to students
	    unless ( defined($set->published) and $set->published ne "") {
	    	my $globalSet = $db->getGlobalSet($set->set_id);
		if ($globalSet) {
		    	$globalSet->published("1") unless defined ($globalSet->published) and $globalSet->published eq "0";
			$db->putGlobalSet($globalSet);
			$set->published("1");  # refresh
		}
	    }
	    warn "undefined published button".$set->set_id unless defined($set->published);
		if ($set->published || $permissionLevel == 10) {
			print $self->setListRow($set, ($permissionLevel > 0),
				($permissionLevel > 0));
		}
	}
	
	print CGI::end_table();
	my $pl = ($permissionLevel > 0 ? "s" : "");
	print CGI::p(CGI::submit("hardcopy", "Download Hardcopy for Selected Set$pl"));
	print CGI::endform();
	
	# feedback form url
	my $feedbackPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Feedback", courseID => $courseName);
	my $feedbackURL = $self->systemLink($feedbackPage, authen => 0); # no authen info for form action
	
	#print feedback form
	print
		CGI::start_form(-method=>"POST", -action=>$feedbackURL),"\n",
		$self->hidden_authen_fields,"\n",
		CGI::hidden("module",             __PACKAGE__),"\n",
		CGI::hidden("set",                ''),"\n",
		CGI::hidden("problem",            ''),"\n",
		CGI::hidden("displayMode",        ''),"\n",
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

sub setListRow {
	my ($self, $set, $multiSet, $preOpenSets) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $urlpath = $r->urlpath;
	
	my $name = $set->set_id;
	my $courseName      = $urlpath->arg("courseID");
	
	my $problemSetPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",
		courseID => $courseName, setID => $name);
	my $interactiveURL = $self->systemLink($problemSetPage);
	
	my $openDate = formatDateTime($set->open_date);
	my $dueDate = formatDateTime($set->due_date);
	my $answerDate = formatDateTime($set->answer_date);
	
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
		$status = "will open on $openDate";
		$control = "" unless $preOpenSets;
		$interactive = $name unless $preOpenSets;
	} elsif (time < $set->due_date) {
		$status = "now open, due $dueDate";
	} elsif (time < $set->answer_date) {
		$status = "closed, answers on $answerDate";
	} else {
		$status = "closed, answers available";
	}
	
	my $publishedClass = ($set->published) ? "Published" : "Unpublished";

	$status = CGI::font({class=>$publishedClass}, $status) if $preOpenSets;
	
	return CGI::Tr(CGI::td([
		$control,
		$interactive,
		$status,
	]));
}

sub byname { $a->set_id cmp $b->set_id; }
sub byduedate { $a->due_date <=> $b->due_date; }

1;
