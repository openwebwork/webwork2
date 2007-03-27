################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/ProblemSet.pm,v 1.87 2007/03/01 22:20:36 glarose Exp $
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
#use CGI qw(-nosticky *ul *li);
use WeBWorK::CGI;
use WeBWorK::PG;
use URI::Escape;
use WeBWorK::Debug;
use WeBWorK::Utils qw(sortByName path_is_subdir);

sub initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	my $authz = $r->authz;
	
	my $setName = $urlpath->arg("setID");
	my $userName = $r->param("user");
	my $effectiveUserName = $r->param("effectiveUser");
	$self->{displayMode}  = $r->param('displayMode') || $r->ce->{pg}->{options}->{displayMode};
	

	my $user            = $db->getUser($userName); # checked
	my $effectiveUser   = $db->getUser($effectiveUserName); # checked
	my $set             = $db->getMergedSet($effectiveUserName, $setName); # checked
	
	die "user $user (real user) not found."  unless $user;
	die "effective user $effectiveUserName  not found. One 'acts as' the effective user."  unless $effectiveUser;

	# FIXME: some day it would be nice to take out this code and consolidate the two checks
	
	# get result and send to message
	my $status_message = $r->param("status_message");
	$self->addmessage(CGI::p("$status_message")) if $status_message;

	# Database fix (in case of undefined published values)
	# this is only necessary because some people keep holding to ww1.9 which did not have a published field
	# make sure published is set to 0 or 1
	if ($set->published ne "0" and $set->published ne "1") {
		my $globalSet = $db->getGlobalSet($set->set_id);
		$globalSet->published("1");	# defaults to published
		$db->putGlobalSet($globalSet);
		$set = $db->getMergedSet($effectiveUserName, $set->set_id);
	}
	
	# $self->{invalidSet} is set by ContentGenerator.pm
	return if $self->{invalidSet};

	my $publishedText = ($set->published) ? "visible to students." : "hidden from students.";
	my $publishedClass = ($set->published) ? "Published" : "Unpublished";
	$self->addmessage(CGI::p("This set is " . CGI::font({class=>$publishedClass}, $publishedText))) if $authz->hasPermissions($userName, "view_unpublished_sets");

	$self->{userName}        = $userName;
	$self->{user}            = $user;
	$self->{effectiveUser}   = $effectiveUser;
	$self->{set}             = $set;
	
	##### permissions #####
	
	$self->{isOpen} = time >= $set->open_date || $authz->hasPermissions($userName, "view_unopened_sets");
}

sub nav {
	my ($self, $args) = @_;
	my $r = $self->r;
	my $urlpath = $r->urlpath;

	my $courseID = $urlpath->arg("courseID");
	#my $problemSetsPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", courseID => $courseID);
	my $problemSetsPage = $urlpath->parent;
	
	my @links = ("Homework Sets" , $r->location . $problemSetsPage->path, "navUp");
	# CRAP ALERT: this line relies on the hacky options() implementation in ContentGenerator.
	# we need to find a better way to do this -- long range dependencies like this are dangerous!
	#my $tail = "&displayMode=".$self->{displayMode}."&showOldAnswers=".$self->{will}->{showOldAnswers};
	# here is a hack to get some functionality back, but I don't even think it's that important to
	# have this, since there are SO MANY PLACES where we lose the displayMode, etc.
	# (oh boy, do we need a session table in the database!)
	my $displayMode = $r->param("displayMode") || "";
	my $showOldAnswers = $r->param("showOldAnswers") || "";
	my $tail = "&displayMode=$displayMode&showOldAnswers=$showOldAnswers";
	return $self->navMacro($args, $tail, @links);
}

sub siblings {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	
	my $courseID = $urlpath->arg("courseID");
	my $user = $r->param('user');
	my $eUserID = $r->param("effectiveUser");

# note that listUserSets does not list versioned sets
	# DBFIXME do filtering in WHERE clause, use iterator for results :)
	my @setIDs = sortByName(undef, $db->listUserSets($eUserID));

	# do not show unpublished siblings unless user is allowed to view unpublished sets, and 
        # exclude gateway tests in all cases
	if ( $authz->hasPermissions($user, "view_unpublished_sets") ) {
		@setIDs    = grep {my $gs = $db->getGlobalSet( $_ ); 
				   $gs->assignment_type() !~ /gateway/} @setIDs;

	} else {
#		@setIDs    = grep {my $visible = $db->getGlobalSet( $_)->published; (defined($visible))? $visible : 1}
		@setIDs    = grep {my $gs = $db->getGlobalSet( $_ ); 
				   $gs->assignment_type() !~ /gateway/ && 
				       ( defined($gs->published()) ? $gs->published() : 1 )}
	                     @setIDs;
	}

	print CGI::start_div({class=>"info-box", id=>"fisheye"});
	print CGI::h2("Sets");
	#print CGI::start_ul({class=>"LinksMenu"});
	#print CGI::start_li();
	#print CGI::span({style=>"font-size:larger"}, "Homework Sets");
	print CGI::start_ul();

	# FIXME: setIDs contain no info on published/unpublished so unpublished sets are still printed
	debug("Begin printing sets from listUserSets()");
	foreach my $setID (@setIDs) {
		my $setPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",
			courseID => $courseID, setID => $setID);
		my $pretty_set_id = $setID;
		$pretty_set_id =~ s/_/ /g;
		print CGI::li(CGI::a({title=>$pretty_set_id, href=>$self->systemLink($setPage),
		                            params=>{  displayMode => $self->{displayMode}, 
									    showOldAnswers => $self->{will}->{showOldAnswers}
									}}, $pretty_set_id)
	    ) ;
	}
	debug("End printing sets from listUserSets()");

	# FIXME: when database calls are faster, this will get rid of unpublished sibling links
	#debug("Begin printing sets from getMergedSets()");	
	#my @userSetIDs = map {[$eUserID, $_]} @setIDs;
	#my @sets = $db->getMergedSets(@userSetIDs);
	#foreach my $set (@sets) {
	#	my $setPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet", courseID => $courseID, setID => $set->set_id);
	#	print CGI::li(CGI::a({href=>$self->systemLink($setPage)}, $set->set_id)) unless !(defined $set && ($set->published || $authz->hasPermissions($user, "view_unpublished_sets"));
	#}
	#debug("Begin printing sets from getMergedSets()");
	
	print CGI::end_ul();
	#print CGI::end_li();
	#print CGI::end_ul();
	print CGI::end_div();
	
	return "";
}

sub info {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;

	return "" if ( $self->{invalidSet} );
	
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
	my $displayMode     = $r->param("displayMode") || $ce->{pg}->{options}->{displayMode};
	
	if ($authz->hasPermissions($userID, "modify_problem_sets")) {
		if (defined $r->param("editMode") and $r->param("editMode") eq "temporaryFile") {
			$screenSetHeader = $r->param('sourceFilePath');
			$screenSetHeader = $ce->{courseDirs}{templates}.'/'.$screenSetHeader unless $screenSetHeader =~ m!^/!;
			die "sourceFilePath is unsafe!" unless path_is_subdir($screenSetHeader, $ce->{courseDirs}->{templates});
			$self->addmessage(CGI::div({class=>'temporaryFile'}, "Viewing temporary file: ",
			            $screenSetHeader));
			$displayMode = $r->param("displayMode") if $r->param("displayMode");
		}
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
	
	my $editorURL;
	if (defined($set) and $authz->hasPermissions($userID, "modify_problem_sets")) {  
		my $editorPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor",
			courseID => $courseID, setID => $set->set_id, problemID => 0);
		$editorURL = $self->systemLink($editorPage, params => { file_type => 'set_header'});
	}
	
	print CGI::start_div({class=>"info-box", id=>"InfoPanel"});
	
	if ($editorURL) {
		print CGI::h2({},"Set Info", CGI::a({href=>$editorURL, target=>"WW_Editor"}, "[edit]"));
	} else {
		print CGI::h2("Set Info");
	}
	
	if ($pg->{flags}->{error_flag}) {
		print CGI::div({class=>"ResultsWithError"}, $self->errorOutput($pg->{errors}, $pg->{body_text}));
	} else {
		print $pg->{body_text};
	}
	
	print CGI::end_div();
	
	return "";
}

sub options { shift->optionsMacro }

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

	if ( $self->{invalidSet} ) { 
		return CGI::div({class=>"ResultsWithError"},
				CGI::p("The selected problem set ($setName) " .
				       "is not a valid set for $effectiveUser:"),
				CGI::p($self->{invalidSet}));
	}
	
	#my $hardcopyURL =
	#	$ce->{webworkURLs}->{root} . "/"
	#	. $ce->{courseName} . "/"
	#	. "hardcopy/$setName/?" . $self->url_authen_args;
	
	my $hardcopyPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Hardcopy",
		courseID => $courseID, setID => $setName);
	my $hardcopyURL = $self->systemLink($hardcopyPage);
	
	print CGI::p(CGI::a({href=>$hardcopyURL}, "Download a hardcopy of this homework set."));
	
	# DBFIXME use iterator
	my @problemNumbers = $db->listUserProblems($effectiveUser, $setName);
	
	if (@problemNumbers) {
		print CGI::start_table();
		print CGI::Tr({},
			CGI::th("Name"),
			CGI::th("Attempts"),
			CGI::th("Remaining"),
			CGI::th("Worth"),
			CGI::th("Status"),
		);
		
		foreach my $problemNumber (sort { $a <=> $b } @problemNumbers) {
			my $problem = $db->getMergedProblem($effectiveUser, $setName, $problemNumber); # checked
			die "problem $problemNumber in set $setName for user $effectiveUser not found." unless $problem;
			print $self->problemListRow($set, $problem);
		}
		
		print CGI::end_table();
	} else {
		print CGI::p("This homework set contains no problems.");
	}
	
	## feedback form url
	#my $feedbackPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Feedback",
	#	courseID => $courseID);
	#my $feedbackURL = $self->systemLink($feedbackPage, authen => 0); # no authen info for form action
	#
	##print feedback form
	#print
	#	CGI::start_form(-method=>"POST", -action=>$feedbackURL),"\n",
	#	$self->hidden_authen_fields,"\n",
	#	CGI::hidden("module",             __PACKAGE__),"\n",
	#	CGI::hidden("set",                $self->{set}->set_id),"\n",
	#	CGI::hidden("problem",            ''),"\n",
	#	CGI::hidden("displayMode",        $self->{displayMode}),"\n",
	#	CGI::hidden("showOldAnswers",     ''),"\n",
	#	CGI::hidden("showCorrectAnswers", ''),"\n",
	#	CGI::hidden("showHints",          ''),"\n",
	#	CGI::hidden("showSolutions",      ''),"\n",
	#	CGI::p({-align=>"left"},
	#		CGI::submit(-name=>"feedbackForm", -label=>"Email instructor")
	#	),
	#	CGI::endform(),"\n";
	
	print $self->feedbackMacro(
		module => __PACKAGE__,
		set => $self->{set}->set_id,
		problem => "",
		displayMode => $self->{displayMode},
		showOldAnswers => "",
		showCorrectAnswers => "",
		showHints => "",
		showSolutions => "",
	);
	
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
			courseID => $courseID, setID => $setID, problemID => $problemID
		),
		params=>{  displayMode => $self->{displayMode}, 
			       showOldAnswers => $self->{will}->{showOldAnswers}
		}
	);
	
	my $interactive = CGI::a({-href=>$interactiveURL}, "Problem $problemID");
	my $attempts = $problem->num_correct + $problem->num_incorrect;
	my $remaining = $problem->max_attempts < 0
		? "unlimited"
		: $problem->max_attempts - $attempts;
	my $rawStatus = $problem->status || 0;
	my $status;
	$status = eval{ sprintf("%.0f%%", $rawStatus * 100)}; # round to whole number
	$status = 'unknown(FIXME)' if $@; # use a blank if problem status was not defined or not numeric.
	                                  # FIXME  -- this may not cover all cases.
	
#	my $msg = ($problem->value) ? "" : "(This problem will not count towards your grade.)";
	
	return CGI::Tr({},
		CGI::td({-nowrap=>1, -align=>"left"},$interactive),
		CGI::td({-nowrap=>1, -align=>"center"},
	 		[
				$attempts,
				$remaining,
				$problem->value,
				$status,
			]));
}

1;
