################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/ProblemSet.pm,v 1.49 2004/05/13 18:38:19 toenail Exp $
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

package WeBWorK::ContentGenerator::ProblemSet;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::ProblemSet - display an index of the problems in a 
problem set.

=cut

use strict;
use warnings;
use CGI qw(*ul *li);
use WeBWorK::PG;
use WeBWorK::Timing;
use WeBWorK::Utils qw(sortByName);

sub initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	
	my $setName = $urlpath->arg("setID");
	my $userName = $r->param("user");
	my $effectiveUserName = $r->param("effectiveUser");
	
	my $user            = $db->getUser($userName); # checked
	my $effectiveUser   = $db->getUser($effectiveUserName); # checked
	my $set             = $db->getMergedSet($effectiveUserName, $setName); # checked
	my $permissionLevel = $db->getPermissionLevel($userName); # checked
	
	die "user $user (real user) not found."  unless $user;
	die "effective user $effectiveUserName  not found. One 'acts as' the effective user."  unless $effectiveUser;
	die "permisson level for user $userName  not found."  unless $permissionLevel;
	
	# FIXME: This is a temporary fix to fill in the database
	#	 We want the published field to contain either 1 or 0 so if it has not been set to 0, default to 1
	#	this will fill in all the empty fields but not change anything that has been specifically set to 1 or 0
	my $globalSet = $db->getGlobalSet($setName);
	$globalSet->published("1") unless defined($globalSet->published) && $globalSet->published eq "0";
	$set->published("1") unless defined($set->published) && $set->published eq "0";
	$db->putGlobalSet($globalSet);

	my $published = ($set->published) ? "visable to students." : "hidden from students.";
	$self->addmessage(CGI::p("This set is " . CGI::font({class=>$published}, $published))) if $permissionLevel->permission > 0;
	
	# A set is valid if it is defined and if it is either published or the user is privileged.
	$self->{invalidSet} = !(defined $set && ($set->published || $permissionLevel->permission > 0));
	return if $self->{invalidSet};


	$self->{userName}        = $userName;
	$self->{user}            = $user;
	$self->{effectiveUser}   = $effectiveUser;
	$self->{set}             = $set;
	$self->{permissionLevel} = $permissionLevel->permission;
	
	##### permissions #####
	
	$self->{isOpen} = time >= $set->open_date || $permissionLevel->permission > 0;
}

sub nav {
	my ($self, $args) = @_;
	my $r = $self->r;
	my $urlpath = $r->urlpath;

	my $courseID = $urlpath->arg("courseID");
	#my $problemSetsPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", courseID => $courseID);
	my $problemSetsPage = $urlpath->parent;
	
	my @links = ("Problem Sets" , $r->location . $problemSetsPage->path, "navUp");
	return $self->navMacro($args, "", @links);
}

sub siblings {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	
	my $courseID = $urlpath->arg("courseID");
	my $eUserID = $r->param("effectiveUser");
	my @setIDs = sortByName(undef, $db->listUserSets($eUserID));
	
	print CGI::start_ul({class=>"LinksMenu"});
	print CGI::start_li();
	print CGI::span({style=>"font-size:larger"}, "Problem Sets");
	print CGI::start_ul();

	# FIXME: setIDs contain no info on published/unpublished so unpublished sets are still printed
	$WeBWorK::timer->continue("Begin printing sets from listUserSets()") if defined $WeBWorK::timer;
	foreach my $setID (@setIDs) {
		my $setPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",
			courseID => $courseID, setID => $setID);
		print CGI::li(CGI::a({href=>$self->systemLink($setPage)}, $setID));
	}
	$WeBWorK::timer->continue("End printing sets from listUserSets()") if defined $WeBWorK::timer;

	# FIXME: when database calls are faster, this will get rid of unpublished sibling links
	#$WeBWorK::timer->continue("Begin printing sets from getMergedSets()") if defined $WeBWorK::timer;	
	#my @userSetIDs = map {[$eUserID, $_]} @setIDs;
	#my @sets = $db->getMergedSets(@userSetIDs);
	#foreach my $set (@sets) {
	#	my $setPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet", courseID => $courseID, setID => $set->set_id);
	#	print CGI::li(CGI::a({href=>$self->systemLink($setPage)}, $set->set_id)) unless !(defined $set && ($set->published || $self->{permissionLevel} > 0));
	#}
	#$WeBWorK::timer->continue("Begin printing sets from getMergedSets()") if defined $WeBWorK::timer;
	
	print CGI::end_ul();
	print CGI::end_li();
	print CGI::end_ul();
	
	return "";
}

sub info {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	
	return "" unless $self->{isOpen};
	
	my $courseID = $urlpath->arg("courseID");
	my $setID = $r->urlpath->arg("setID");

	my $userID = $r->param("user");
	my $eUserID = $r->param("effectiveUser");
	
	my $effectiveUser = $db->getUser($eUserID); # checked 
	my $set  = $db->getMergedSet($eUserID, $setID); # checked
	
	die "effective user $eUserID not found. One 'acts as' the effective user." unless $effectiveUser;
	# FIXME: this was already caught in initialize()
	die "set $setID for effectiveUser $eUserID not found." unless $set;
	
	my $psvn = $set->psvn();
	
	my $screenSetHeader = $set->set_header || $ce->{webworkFiles}->{screenSnippets}->{setHeader};
	my $displayMode     = $ce->{pg}->{options}->{displayMode};
	
	if (defined $r->param("editMode") and $r->param("editMode") eq "temporaryFile") {
		$screenSetHeader = "$screenSetHeader.$userID.tmp";
		$displayMode = $r->param("displayMode") if $r->param("displayMode");
	}
	
	return "" unless defined $screenSetHeader and $screenSetHeader;
	
	# decide what to do about problem number
	my $problem = WeBWorK::DB::Record::UserProblem->new(
		problem_id => 0,
		set_id => $set->set_id,
		login_id => $effectiveUser->user_id,
		source_file => $screenSetHeader,
		# the rest of Problem's fields are not needed, i think
	);
	
	my $pg = WeBWorK::PG->new(
		$ce,
		$effectiveUser,
		$r->param('key'),
		$set,
		$problem,
		$psvn,
		{}, # no form fields!
		{ # translation options
			displayMode     => $displayMode,
			showHints       => 0,
			showSolutions   => 0,
			processAnswers  => 0,
		},
	);
	
	if (defined($set) and $set->set_header and $self->{permissionLevel} >= $ce->{permissionLevels}->{modify_problem_sets}) {  
		#FIXME ?  can't edit the default set header this way
		my $editorPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor",
			courseID => $courseID, setID => $set->set_id, problemID => 0);
		my $editorURL = $self->systemLink($editorPage);
		
		print CGI::p(CGI::b("Set Info"), " ",
			CGI::a({href=>$editorURL}, "[edit]"));
	} else {
		print CGI::p(CGI::b("Set Info"));
	}
	
	if ($pg->{flags}->{error_flag}) {
		print CGI::div({class=>"ResultsWithError"}, $self->errorOutput($pg->{errors}, $pg->{body_text}));
	} else {
		print $pg->{body_text};
	}
	
	return "";
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;

	my $courseID = $urlpath->arg("courseID");
	my $setName = $urlpath->arg("setID");
	my $effectiveUser = $r->param('effectiveUser');

	my $set = $db->getMergedSet($effectiveUser, $setName);  # checked
	# FIXME: this was already caught in initialize()
	# die "set $setName for user $effectiveUser not found" unless $set;

	if ($self->{invalidSet}) {
		return CGI::div({class=>"ResultsWithError"},
			CGI::p("The selected problem set ($setName) is not a valid set for $effectiveUser."));
	}
	
	unless ($self->{isOpen}) {
		return CGI::div({class=>"ResultsWithError"},
			CGI::p("This problem set is not available because it is not yet open."));
	}
	
	#my $hardcopyURL =
	#	$ce->{webworkURLs}->{root} . "/"
	#	. $ce->{courseName} . "/"
	#	. "hardcopy/$setName/?" . $self->url_authen_args;
	
	my $hardcopyPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Hardcopy",
		courseID => $courseID, setID => $setName);
	my $hardcopyURL = $self->systemLink($hardcopyPage);
	
	print CGI::p(CGI::a({href=>$hardcopyURL}, "Download a hardcopy of this problem set."));
	
	print CGI::start_table();
	print CGI::Tr(
		CGI::th("Name"),
		CGI::th("Attempts"),
		CGI::th("Remaining"),
		CGI::th("Status"),
	);
	
	my @problemNumbers = $db->listUserProblems($effectiveUser, $setName);
	foreach my $problemNumber (sort { $a <=> $b } @problemNumbers) {
		my $problem = $db->getMergedProblem($effectiveUser, $setName, $problemNumber); # checked
		die "problem $problemNumber in set $setName for user $effectiveUser not found." unless $problem;
		print $self->problemListRow($set, $problem);
	}
	
	print CGI::end_table();
	
	## feedback form
	#my $ce = $self->{ce};
	#my $root = $ce->{webworkURLs}->{root};
	#my $courseName = $ce->{courseName};
	#my $feedbackURL = "$root/$courseName/feedback/";
	#print
	#	CGI::start_form(-method=>"POST", -action=>$feedbackURL),"\n",
	#	$self->hidden_authen_fields,"\n",
	#	CGI::hidden("module",             __PACKAGE__),"\n",
	#	CGI::hidden("set",                $self->{set}->set_id),"\n",
	#	CGI::hidden("problem",            ""),"\n",
	#	CGI::hidden("displayMode",        $self->{displayMode}),"\n",
	#	CGI::hidden("showOldAnswers",     ''),"\n",
	#	CGI::hidden("showCorrectAnswers", ''),"\n",
	#	CGI::hidden("showHints",          ''),"\n",
	#	CGI::hidden("showSolutions",      ''),"\n",
	#	CGI::p({-align=>"left"},
	#		CGI::submit(-name=>"feedbackForm", -label=>"Email instructor")
	#	),
	#	CGI::endform(),"\n";
	
	# feedback form url
	my $feedbackPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Feedback",
		courseID => $courseID);
	my $feedbackURL = $self->systemLink($feedbackPage, authen => 0); # no authen info for form action
	
	#print feedback form
	print
		CGI::start_form(-method=>"POST", -action=>$feedbackURL),"\n",
		$self->hidden_authen_fields,"\n",
		CGI::hidden("module",             __PACKAGE__),"\n",
		CGI::hidden("set",                $self->{set}->set_id),"\n",
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

sub problemListRow($$$) {
	my ($self, $set, $problem) = @_;
	my $r = $self->r;
	my $urlpath = $r->urlpath;
	
	my $courseID = $urlpath->arg("courseID");
	my $setID = $set->set_id;
	my $problemID = $problem->problem_id;
	
	my $interactiveURL = $self->systemLink(
		$urlpath->newFromModule("WeBWorK::ContentGenerator::Problem",
			courseID => $courseID, setID => $setID, problemID => $problemID)
	);
	
	my $interactive = CGI::a({-href=>$interactiveURL}, "Problem $problemID");
	my $attempts = $problem->num_correct + $problem->num_incorrect;
	my $remaining = $problem->max_attempts < 0
		? "unlimited"
		: $problem->max_attempts - $attempts;
	my $status;
	$status = eval{ sprintf("%.0f%%", $problem->status * 100)}; # round to whole number
	$status = 'unknown(FIXME)' if $@;                           # use a blank if problem status was not defined or not numeric.
	                                                            # FIXME  -- this may not cover all cases.
	
	my $msg = ($problem->value) ? "" : "(This problem will not count towards your grade.)";
	
	return CGI::Tr(CGI::td({-nowrap=>1}, [
		$interactive,
		$attempts,
		$remaining,
		$status . " " . $msg,
	]));
}

1;
