################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/ProblemSets.pm,v 1.94 2010/01/31 02:31:04 apizer Exp $
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
use base qw(WeBWorK);
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::ProblemSets - Display a list of built problem sets.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::Utils qw(after readFile sortByName path_is_subdir is_restricted wwRound);
use WeBWorK::Localize;
# what do we consider a "recent" problem set?
use constant RECENT => 2*7*24*60*60 ; # Two-Weeks in seconds
# the "default" data in the course_info.txt file
use constant DEFAULT_COURSE_INFO_TXT => "Put information about your course here.  Click the edit button above to add your own message.\n";


sub if_can {
  my ($self, $arg) = @_;

  if ($arg ne 'info') {
    return $self->can($arg) ? 1 : 0;
  } else {
    my $r = $self->r;
    my $ce = $r->ce;
    my $urlpath = $r->urlpath;
    my $authz = $r->authz;
    my $user = $r->param("user");

    # we only print the info box if the viewer has permission
    # to edit it or if its not the standard template box.
    
    my $course_info_path = $ce->{courseDirs}->{templates} . "/"
      . $ce->{courseFiles}->{course_info};
    my $text = DEFAULT_COURSE_INFO_TXT;

    if (-f $course_info_path) { #check that it's a plain  file
      $text = eval { readFile($course_info_path) };
    }
    return $authz->hasPermissions($user, "access_instructor_tools") ||
	  $text ne DEFAULT_COURSE_INFO_TXT;
    
  }
}

sub info {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	my $authz = $r->authz;
	
	my $courseID = $urlpath->arg("courseID");
	my $user = $r->param("user");
	
	my $course_info = $ce->{courseFiles}->{course_info};
	
	if (defined $course_info and $course_info) {
		my $course_info_path = $ce->{courseDirs}->{templates} . "/$course_info";
			
		# deal with instructor crap
		my $editorURL;
		if ($authz->hasPermissions($user, "access_instructor_tools")) {
			if (defined $r->param("editMode") and $r->param("editMode") eq "temporaryFile") {
				$course_info_path = $r->param("sourceFilePath");
				$course_info_path = $ce->{courseDirs}{templates}.'/'.$course_info_path unless $course_info_path =~ m!^/!;
				die "sourceFilePath is unsafe!" unless path_is_subdir($course_info_path, $ce->{courseDirs}->{templates});
				$self->addmessage(CGI::div({class=>'temporaryFile'}, $r->maketext("Viewing temporary file:").' ', $course_info_path));
			}
			
			my $editorPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor",  $r, courseID => $courseID);
			$editorURL = $self->systemLink($editorPage, params => { file_type => "course_info" });
		}
		
		if ($editorURL) {
			print CGI::h2($r->maketext("Course Info"), CGI::a({href=>$editorURL, target=>"WW_Editor"}, $r->maketext("~[Edit~]")));
		} else {
			print CGI::h2($r->maketext("Course Info"));
		}
		die "course info path is unsafe!" unless path_is_subdir($course_info_path, $ce->{courseDirs}->{templates}, 1); 
		if (-f $course_info_path) { #check that it's a plain  file
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
sub help {   # non-standard help, since the file path includes the course name
	my $self = shift;
	my $args = shift;
	my $name = $args->{name};
	$name = lc('course home') unless defined($name);
	$name =~ s/\s/_/g;
	$self->helpMacro($name);
}
sub templateName {
	my $self = shift;
	my $r = $self->r;
	my $templateName = $r->param('templateName')//'system';
	$self->{templateName}= $templateName;
	$templateName;
}
sub initialize {



# get result and send to message
	my ($self) = @_;
	my $r = $self->r;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $user               = $r->param("user");
	my $effectiveUser      = $r->param("effectiveUser");
	if ($authz->hasPermissions($user, "access_instructor_tools")) {
		# get result and send to message
		my $status_message = $r->param("status_message");
		$self->addmessage(CGI::p("$status_message")) if $status_message;
	

	}
}
sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $user            = $r->param("user");
	my $effectiveUser   = $r->param("effectiveUser");
	my $sort            = $r->param("sort") || "status";
	
	my $courseName      = $urlpath->arg("courseID");
	
	my $hardcopyPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Hardcopy",  $r, courseID => $courseName);
	my $actionURL = $self->systemLink($hardcopyPage, authen => 0); # no authen info for form action
	
# we have to get sets and versioned sets separately
	# DBFIXME don't get ID lists, use WHERE clauses and iterators
	my @setIDs = $db->listUserSets($effectiveUser);
	my @userSetIDs = map {[$effectiveUser, $_]} @setIDs;

	debug("Begin collecting merged sets");
	my @sets = $db->getMergedSets( @userSetIDs );

	debug("Begin fixing merged sets");
	
	# Database fix (in case of undefined visible values)
	# this may take some extra time the first time but should NEVER need to be run twice
	# this is only necessary because some people keep holding to ww1.9 which did not have a visible field
	# DBFIXME this should be in the database layer (along with other "fixes" of its ilk)
	foreach my $set (@sets) {
		# make sure visible is set to 0 or 1
		if ( $set and $set->visible ne "0" and $set->visible ne "1") {
			my $globalSet = $db->getGlobalSet($set->set_id);
			$globalSet->visible("1");	# defaults to visible
			$db->putGlobalSet($globalSet);
			$set = $db->getMergedSet($effectiveUser, $set->set_id);
		} else {
			die "set $set not defined" unless $set;
		}
	}
	foreach my $set (@sets) {
		# make sure enable_reduced_scoring is set to 0 or 1
		if ( $set and $set->enable_reduced_scoring ne "0" and $set->enable_reduced_scoring ne "1") {
			my $globalSet = $db->getGlobalSet($set->set_id);
			$globalSet->enable_reduced_scoring("0");	# defaults to disabled
			$db->putGlobalSet($globalSet);
			$set = $db->getMergedSet($effectiveUser, $set->set_id);
		} else {
			die "set $set not defined" unless $set;
		}
	}

# gateways/versioned sets require dealing with output data slightly 
# differently, so check for those here	
	debug("Begin set-type check");
	my $existVersions = 0;
	my @gwSets = ();
	my @nonGWsets = ();
	my %gwSetNames = ();  # this is necessary because we get a setname
	                      #    for all versions of g/w tests
	foreach ( @sets ) {
	    if ( defined( $_->assignment_type() ) && 
		 $_->assignment_type() =~ /gateway/ ) {
		$existVersions = 1; 

		push( @gwSets, $_ ) if ( ! defined($gwSetNames{$_->set_id}) );
		$gwSetNames{$_->set_id} = 1;
	    } else {
		push( @nonGWsets, $_ );
	    }
	}
# now get all user set versions that we need
	my @vSets = ();
# we need the template sets below, so also make an indexed list of those
	my %gwSetsBySetID = ();
	foreach my $set ( @gwSets ) {
		$gwSetsBySetID{$set->set_id} = $set;

		my @setVer = $db->listSetVersions( $effectiveUser, $set->set_id );
		my @setVerIDs = map { [ $effectiveUser, $set->set_id, $_ ] } @setVer;
		push( @vSets, $db->getMergedSetVersions( @setVerIDs ) );
	}

# set sort method
	$sort = "status" unless $sort eq "status" or $sort eq "name";

# now set the headers for the table
	my $nameHeader = $sort eq "name"
		? CGI::span($r->maketext("Name"))
		: CGI::a({href=>$self->systemLink($urlpath, params=>{sort=>"name"})}, $r->maketext("Name"));
	my $statusHeader = $sort eq "status"
		? CGI::span($r->maketext("Status"))
		: CGI::a({href=>$self->systemLink($urlpath, params=>{sort=>"status"})}, $r->maketext("Status"));
# print the start of the form
	if ($authz->hasPermissions($user, "view_multiple_sets")) { 
	    print CGI::start_form(-name=>"problem-sets-form", -id=>"problem-sets-form", -method=>"POST",-action=>$actionURL),
	    $self->hidden_authen_fields;
	}
	
# and send the start of the table
# UPDATE - ghe3
# This table now contains a summary and a caption, scope attributes for the column headers, and no longer prints a column for 'Sel.' (due to it having been merged with the second column for accessibility purposes).
	print CGI::start_table({ -class=>"problem_set_table", -summary=>$r->maketext("This table lists out the available homework sets for this class, along with its current status. Click on the link on the name of the homework set to take you to the problems in that homework set. You can also select sets for download to PDF or TeX format using the checkboxes next to the problem set names, and then clicking on the 'Generate Hardcopy for Select Sets' button at the end of the table. There is also a clear button and an Email Instructor button at the end of the table.")});
	print CGI::caption($r->maketext("Homework Sets"));
	if ( ! $existVersions ) {
		print CGI::Tr(
			CGI::th({-scope=>"col"},$nameHeader),
			CGI::th({-scope=>"col"},$statusHeader),
			CGI::th({-scope=>"col", class=>"hardcopy"},CGI::i({
				class => "icon far fa-arrow-alt-circle-down",
				aria_hidden => "true",
				title => $r->maketext("Generate Hardcopy"),
				data_alt => $r->maketext("Generate Hardcopy")
			}, '')),
		);
	} else {
		print CGI::Tr(
			CGI::th({-scope=>"col"},$nameHeader),
			CGI::th({-scope=>"col"},$statusHeader),
			CGI::th({-scope=>"col"},$r->maketext("Score")),
			CGI::th({-scope=>"col"},$r->maketext("Start Date")),
			CGI::th({-scope=>"col", class=>"hardcopy"},CGI::i({
				class => "icon far fa-arrow-alt-circle-down",
				aria_hidden => "true",
				title => $r->maketext("Generate Hardcopy"),
				data_alt => $r->maketext("Generate Hardcopy")
			}, '')),
		);
	}

	debug("Begin sorting merged sets");

# before building final set lists, exclude proctored gateway sets 
#    for users without permission to view them
	my $viewPr = $authz->hasPermissions( $user, "view_proctored_tests" );
	@gwSets = grep {$_->assignment_type !~ /proctored/ || $viewPr} @gwSets;
	
	if ( $sort eq 'name' ) {
		@sets = sortByName("set_id", @nonGWsets, @gwSets);
	} elsif ( $sort eq 'status' ) {
		@sets = sort byUrgency (@nonGWsets, @gwSets );
	}
	# build a tree for set versions
	# first sort set versions by parent set name, then by version
	@vSets = sortByName(["set_id", "version_id"], @vSets);
	my %vSetTree = ();
	# initialize keys as the parent GW set ids
	for my $vset (@vSets) {
		$vSetTree{$vset->set_id} = [];
	}
	#push in versioned sets as values
	for my $vset (@vSets) {
		push(@{$vSetTree{$vset->set_id}},$vset);
	}

	debug("End preparing merged sets");

	# Regular sets and gateway template sets are merged, but sorted either by name or urgency.
	# Immediately following a gateway template set comes its set versions.
	# Note: this assumes that the set_id of a versioned GW set cannot differ from all of the corresponding GW versions.
	foreach my $set (@sets) {
		die "set $set not defined" unless $set;

		# Generate the versioned quiz rows, but delay printing them until after the template is printed.  On this pass
		# the gw_quiz_version_in_progress flag will be set if a quiz is currently in progress, in which case the quiz
		# begin dialog is disabled for the template.
		my @versions;
		if (defined($gwSetNames{$set->set_id})) {
			foreach my $vset (@{$vSetTree{$set->set_id}}) {
				die "set $vset not defined" unless $vset;
				if (($set->set_id eq $vset->set_id) && ($vset->visible || $authz->hasPermissions($user, "view_hidden_sets"))) {
					push(@versions, $self->setListRow($vset, $authz->hasPermissions($user, "view_multiple_sets"),
							$authz->hasPermissions($user, "view_unopened_sets"), $existVersions, $db, 1,
							$gwSetsBySetID{$vset->{set_id}})); # 1 = gateway, versioned set
				}
			}
		}
		if ($set->visible || $authz->hasPermissions($user, "view_hidden_sets")) {
			print $self->setListRow($set, $authz->hasPermissions($user, "view_multiple_sets"),
				$authz->hasPermissions($user, "view_unopened_sets"), $existVersions, $db);
		}
		print $_ for @versions;
		delete $self->{gw_quiz_version_in_progress};
	}
	
	print CGI::end_table();
	my $pl = ($authz->hasPermissions($user, "view_multiple_sets") ? "s" : "");
# 	print CGI::p(CGI::submit(-name=>"hardcopy", -label=>$r->maketext("Download Hardcopy for Selected [plural,_1,Set,Sets]",$pl)));

	# UPDATE - ghe3
	# Added reset button to form.

	if ($authz->hasPermissions($user, "view_multiple_sets")) {
	    print CGI::start_div({-class=>"problem_set_options"});
	    print CGI::start_p().WeBWorK::CGI_labeled_input(-type=>"reset", -id=>"clear", -input_attr=>{ -value=>$r->maketext("Clear")}).CGI::end_p();
	    print CGI::start_p().WeBWorK::CGI_labeled_input(-type=>"submit", -id=>"hardcopy",-input_attr=>{-name=>"hardcopy", -value=>$r->maketext("Generate Hardcopy for Select Sets")}).CGI::end_p();
	    print CGI::end_div();
	    print CGI::end_form();
	}
	
	## feedback form url
	#my $feedbackPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Feedback",  $r, courseID => $courseName);
	#my $feedbackURL = $self->systemLink($feedbackPage, authen => 0); # no authen info for form action
	#
	##print feedback form
	#print
	#	CGI::start_form(-method=>"POST", -action=>$feedbackURL),"\n",
	#	$self->hidden_authen_fields,"\n",
	#	CGI::hidden("module",             __PACKAGE__),"\n",
	#	CGI::hidden("set",                ''),"\n",
	#	CGI::hidden("problem",            ''),"\n",
	#	CGI::hidden("displayMode",        ''),"\n",
	#	CGI::hidden("showOldAnswers",     ''),"\n",
	#	CGI::hidden("showCorrectAnswers", ''),"\n",
	#	CGI::hidden("showHints",          ''),"\n",
	#	CGI::hidden("showSolutions",      ''),"\n",
	#	CGI::p({-align=>"left"},
	#		CGI::submit(-name=>"feedbackForm", -label=>"Email instructor")
	#	),
	#	CGI::end_form(),"\n";
	
	print $self->feedbackMacro(
		module => __PACKAGE__,
		set => "",
		problem => "",
		displayMode => "",
		showOldAnswers => "",
		showCorrectAnswers => "",
		showHints => "",
		showSolutions => "",
	);
	
	return "";
}

# UPDATE - ghe3
# this subroutine now combines the $control and $interactive elements, by using the $interactive element as the $control element's label.

sub setListRow {
	my ($self, $set, $multiSet, $preOpenSets, $existVersions, $db,
	    $gwtype, $tmplSet) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $authz = $r->authz;
	my $user = $r->param("user");
	my $effectiveUser = $r->param("effectiveUser") || $user;
	my $urlpath = $r->urlpath;
	my $globalSet = $db->getGlobalSet($set->set_id);
	$gwtype = 0 if ( ! defined( $gwtype ) );
	$tmplSet = $set if ( ! defined( $tmplSet ) );
	
	my $name = $set->set_id;
	my @restricted = $ce->{options}{enableConditionalRelease} ?  
	  is_restricted($db, $set, $effectiveUser) : ();
	# The set shouldn't be shown if the LTI grade mode is set to homework and we dont
	# have a source did to use to send back grades.  
	my $LTIRestricted = defined($ce->{LTIGradeMode}) && $ce->{LTIGradeMode} eq 'homework'
	  && !$set->lis_source_did;

	
	my $urlname = ( $gwtype == 1 ) ? "$name,v" . $set->version_id : $name;

	my $courseName      = $urlpath->arg("courseID");
	
	my $problemSetPage;

	if ( ! defined( $set->assignment_type() ) || 
	     $set->assignment_type() !~ /gateway/ ) {
	    $problemSetPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet", $r, 
				      courseID => $courseName, setID => $urlname);
	} elsif( $set->assignment_type() !~ /proctored/ ) {

	    $problemSetPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::GatewayQuiz", $r, 
				      courseID => $courseName, setID => $urlname);
	} else {

	    $problemSetPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProctoredGatewayQuiz", $r, 
				      courseID => $courseName, setID => $urlname);
	}

	my $interactiveURL = $self->systemLink($problemSetPage);

  # check to see if this is a template gateway assignment
	$gwtype = 2 if ( defined( $set->assignment_type() ) && 
			 $set->assignment_type() =~ /gateway/ && ! $gwtype );
  # and get problemRecords if we're dealing with a versioned set, so that
  #    we can test status and scores
  # FIXME: should we really have to get the merged 
  # problem_versions here?  it looks that way, because
  # otherwise we don't inherit things like the problem
  # value properly.
	my @problemRecords;
	@problemRecords = 
		$db->getAllProblemVersions($set->user_id(), $set->set_id(),
					   $set->version_id()) 
		if ( $gwtype == 1 );

  # the conditional here should be redundant.  ah well.
#	$interactiveURL =~ s|/quiz_mode/|/proctored_quiz_mode/| if 
#	    ( defined( $set->assignment_type() ) && 
#	      $set->assignment_type() eq 'proctored_gateway' );
	my $display_name = $name;
	$display_name =~ s/_/ /g;
# this is the link to the homework assignment, it has tooltip with the hw description 
	my $interactive = CGI::a({class=>"set-id-tooltip", "data-toggle"=>"tooltip", "data-placement"=>"right", title=>"", "data-original-title"=>$globalSet->description(),href=>$interactiveURL}, "$display_name");
	my $control = "";
	
	my $setIsOpen = 0;
	my $status = '';
	if ( $gwtype ) {
		if ( $gwtype == 1 ) {
			unless (ref($problemRecords[0]) ) {warn "Error: problem not defined in set $display_name"; return()}
			if ($set->attempts_per_version() && $problemRecords[0]->num_correct() + $problemRecords[0]->num_incorrect() >= $set->attempts_per_version()) {
				$status = $r->maketext("Completed.");
			} elsif ( time() > $set->due_date() + $self->r->ce->{gatewayGracePeriod} ) {
				$status = $r->maketext("Over time, closed.");
			} else {
				$self->{gw_quiz_version_in_progress} = 1;
				$status = $self->set_due_msg($set,1);
			}
			# we let people go back to old tests
			$setIsOpen = 1;
			# reset the link to give the test number
			my $vnum = $set->version_id;
			$interactive = CGI::a(
				{
					class=>"set-id-tooltip gw-parenthetical",
					"data-toggle"=>"tooltip",
					"data-placement"=>"right",
					title=>"",
					"data-original-title"=>$globalSet->description(),
					href=>$interactiveURL
				},
				$r->maketext("(version&nbsp;[_1])", $vnum)
			);
		} else {
			my $t = time();
			if ($set->{version_time_limit} > 0 && $t < $set->due_date()) {
				$display_name = CGI::i({
						class => "icon far fa-clock",
						title => $r->maketext("Quiz with time limit"),
						data_alt => $r->maketext("Quiz with time limit.")
					}, '') . ' ' . CGI::span({ class => 'gwquiz-info', data_time_limit => $set->{version_time_limit} }, $display_name);
			}
			if ( $t < $set->open_date() ) {
				$status = $r->maketext("Will open on [_1].", $self->formatDateTime($set->open_date,undef,$ce->{studentDateDisplayFormat}));
				if (@restricted) {
					my $restriction = ($set->restricted_status)*100;
					$status .= restricted_progression_msg($r,1, $restriction, @restricted);
				}
				if ( $preOpenSets ) {
					# reset the link
					$interactive = CGI::a(
						{
							class=>"set-id-tooltip",
							"data-toggle"=>"tooltip",
							"data-placement"=>"right",
							title=>"",
							"data-original-title"=>$globalSet->description(),
							href=>$interactiveURL
						},
						$display_name
					);
				} else {
					$interactive = $display_name;
				}
				$control = "";
			} elsif ( $t < $set->due_date() ) {
				$status = $self->set_due_msg($set,0);
				if (@restricted) {
					my $restriction = ($set->restricted_status)*100;
					$control = "" unless $preOpenSets;
					$interactive = $display_name unless $preOpenSets;
					$setIsOpen = 0;
					$status .= restricted_progression_msg($r,0,$restriction,@restricted);
				} elsif ($LTIRestricted) {
					$status .= CGI::br().$r->maketext("You must log into this set via your Learning Management System ([_1]).", $ce->{LMS_name});
					$control = "" unless $preOpenSets;
					$interactive = $display_name unless $preOpenSets;
					$setIsOpen = 0;
				} else {
					$setIsOpen = 1;
				}
				if ($setIsOpen ||  $preOpenSets ) {
					# reset the link
					$interactive = CGI::a(
						{
							class=>"set-id-tooltip",
							"data-toggle"=>"tooltip",
							"data-placement"=>"right",
							data_open => $setIsOpen && $effectiveUser eq $user && !$self->{gw_quiz_version_in_progress},
							title=>"",
							"data-original-title"=>$globalSet->description(),
							href=>$interactiveURL
						},
						$display_name
					);
					$control = "";
				} else {
					$control = "";
					$interactive = $display_name;
				}
			} else {
				$status = $r->maketext("Closed.");
				if ( $authz->hasPermissions( $user, "record_answers_after_due_date" ) ) {
					$interactive = CGI::a(
						{
							class=>"set-id-tooltip",
							"data-toggle"=>"tooltip",
							"data-placement"=>"right",
							title=>"",
							"data-original-title"=>$globalSet->description(),
							href=>$interactiveURL
						},
						$display_name
					);
				} else {
					$interactive = CGI::a(
						{
							class=>"set-id-tooltip",
							"data-toggle"=>"tooltip",
							"data-placement"=>"right",
							title=>"",
							"data-original-title"=>$globalSet->description(),
							href=>$interactiveURL
						},
						$display_name
					);
				}
			}
		}
	# old conditional
	} elsif (time < $set->open_date) {
		$status = $r->maketext("Will open on [_1].", $self->formatDateTime($set->open_date,undef,$ce->{studentDateDisplayFormat}));
	  
	  if (@restricted) {
	    my $restriction = ($set->restricted_status)*100;
	    $status .= restricted_progression_msg($r,1,$restriction,@restricted);
	  }
	  
	  $control = "" unless $preOpenSets;
	  $interactive = $display_name unless $preOpenSets;
	  
	} elsif (time < $set->due_date) {
	  
	  $status = $self->set_due_msg($set,0);
	  
	  if (@restricted) {
	    my $restriction = ($set->restricted_status)*100;
	    $control = "" unless $preOpenSets;
	    $interactive = $display_name unless $preOpenSets;
	    
	    $status .= restricted_progression_msg($r,0,$restriction, @restricted);
	    
	    $setIsOpen = 0;
	  } elsif ($LTIRestricted) {
	    $status .= CGI::br().$r->maketext("You must log into this set via your Learning Management System ([_1]).", $ce->{LMS_name});
	    $control = "" unless $preOpenSets;
	    $interactive = $display_name unless $preOpenSets;
	    $setIsOpen = 0;
	  } else {
	    $setIsOpen = 1;
	  }
	  
	} elsif (time < $set->answer_date) {
	  $status = $r->maketext("Closed, answers on [_1].", $self->formatDateTime($set->answer_date,undef,$ce->{studentDateDisplayFormat}));
	} elsif ($set->answer_date <= time and time < $set->answer_date +RECENT ) {
	  $status = $r->maketext("Closed, answers recently available.");
	} else {
	  $status = $r->maketext("Closed, answers available.");
	}
	
	if ($multiSet) {
	  if ( $gwtype < 2 ) {
	    $control = CGI::input({
				   -type=>"checkbox",
				   -id=>$name . ($gwtype ? ",v" . $set->version_id : ''), 
				   -name=>"selected_sets",
				   -value=>$name . ($gwtype ? ",v" . $set->version_id : '')
				  });
	    # make sure interactive is the label for control
	    $interactive = CGI::label({"for"=>$name . ($gwtype ? ",v" . $set->version_id : '')},$interactive);
	    
	  } else {
	    $control = '';
	  }
	} else {
	  if ( $gwtype < 2 && after($set->open_date) && 
	       (!@restricted || after($set->due_date))) {
	    my $n = $name  . ($gwtype ? ",v" . $set->version_id : '');
	    my $hardcopyPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Hardcopy", $r, courseID => $courseName, setID => $urlname);
	    
	    my $link = $self->systemLink($hardcopyPage,
					 params=>{selected_sets=>$n});
	    $control = CGI::a({class=>"hardcopy-link", href=>$link},
			CGI::i({
					class => "icon far fa-arrow-alt-circle-down", aria_hidden => "true",
					title => $r->maketext("Download [_1]", $set->set_id =~ s/_/ /gr),
					data_alt => $r->maketext("Download [_1]", $set->set_id =~ s/_/ /gr)
				}, ''));
	  } else {
	    $control = '';
	  }
	}
	
	my $visiblityStateClass = ($set->visible) ? "font-visible" : "font-hidden";
	
	$status = CGI::span({class=>$visiblityStateClass}, $status) if $preOpenSets;
	
	# check to see if we need to return a score and a date column
	if ( ! $existVersions ) {
	  return CGI::Tr(CGI::td([$interactive, $status]),CGI::td({class => "hardcopy"}, $control));
	} else {
	  my ( $startTime, $score );
	  
	  if ( defined( $set->assignment_type() ) && 
	       $set->assignment_type() =~ /gateway/ && $gwtype == 1 ) {
	    $startTime = localtime($set->version_creation_time() || 0); #fixes error message for undefined creation_time
	    
	    if ( $authz->hasPermissions($user, "view_hidden_work") || 
		 $set->hide_score() eq 'N' || 
		 ( $set->hide_score eq 'BeforeAnswerDate' && time > $tmplSet->answer_date() ) ) {
	      # find score
	      
	      # DBFIXME we can do this math in the database, i think
	      my $possible = 0;
	      $score = 0;
	      foreach my $pRec ( @problemRecords ) {
		my $pval = $pRec->value() ? $pRec->value() : 1;
		if ( defined( $pRec ) && 
		     $score ne 'undef' ) {
		  $score += $pRec->status()*$pval || 0;
		} else {
		  $score = 'undef';
		}
		$possible += $pval;
	      }
	      $score = wwRound(2,$score);
	      $score = "$score/$possible";
	    } else {
	      $score = "n/a";
	    }
	  } else {
	    $startTime = '&nbsp;';
	    $score = $startTime;
	  }
	  
	  return CGI::Tr(($gwtype == 1) ? {class => 'gw-version'} : {},
		  CGI::td(($gwtype == 1) ? {class => 'gw-version'} : ($gwtype == 2) ? {class => 'gw-template'} : {},$interactive).
		  CGI::td([$status, $score, $startTime]),
		  CGI::td({class => "hardcopy"}, $control));
	}
      }

sub byname { $a->set_id cmp $b->set_id; }

sub byUrgency {
	my $mytime = time;
	my @a_parts = ($a->answer_date + RECENT <= $mytime) ?  (4, $a->open_date, $a->due_date, $a->set_id) 
		: ($a->answer_date <= $mytime and $mytime < $a->answer_date + RECENT) ? (3, $a-> answer_date, $a-> due_date, $a->set_id)
		: ($a->due_date <= $mytime and $mytime < $a->answer_date ) ? (2, $a->answer_date, $a->due_date, $a->set_id)
		: ($mytime < $a->open_date) ? (1, $a->open_date, $a->due_date, $a->set_id) 
		: (0, $a->due_date, $a->open_date, $a->set_id);
	my @b_parts = ($b->answer_date + RECENT <= $mytime) ?  (4, $b->open_date, $b->due_date, $b->set_id) 
		: ($b->answer_date <= $mytime and $mytime < $b->answer_date + RECENT) ? (3, $b-> answer_date, $b-> due_date, $b->set_id)
		: ($b->due_date <= $mytime and $mytime < $b->answer_date ) ? (2, $b->answer_date, $b->due_date, $b->set_id)
		: ($mytime < $b->open_date) ? (1, $b->open_date, $b->due_date, $b->set_id) 
		: (0, $b->due_date, $b->open_date, $b->set_id);
	my $returnIt=0;
	while (scalar(@a_parts) > 1) {
		if ($returnIt = ( (shift @a_parts) <=> (shift @b_parts) ) ) {
			return($returnIt);
		}
	}
	return (  $a_parts[0] cmp  $b_parts[0] );
}

sub check_sets {
	my ($self,$db,$sets_string) = @_;
	my @proposed_sets = split(/\s*,\s*/,$sets_string);
	foreach(@proposed_sets) {
	  return 0 unless $db->existsGlobalSet($_);
	  return 1;
	}
}

sub set_due_msg {
  my $self = shift;
  my $r = $self->r;
  my $ce = $r->ce;
  my $set = shift;
  my $gwversion = shift;
  my $status = ''; 

  my $enable_reduced_scoring =  $ce->{pg}{ansEvalDefaults}{enableReducedScoring} && $set->enable_reduced_scoring && $set->reduced_scoring_date &&$set->reduced_scoring_date < $set->due_date;
  my $reduced_scoring_date = $set->reduced_scoring_date;
  my $beginReducedScoringPeriod =  $self->formatDateTime($reduced_scoring_date,undef,$ce->{studentDateDisplayFormat});

  my $t = time;

  if ($enable_reduced_scoring &&
      $t < $reduced_scoring_date) {
    
    $status .= $r->maketext("Open, due [_1].",$beginReducedScoringPeriod) . CGI::br() . $r->maketext("Afterward reduced credit can be earned until [_1].", $self->formatDateTime($set->due_date(),undef,$ce->{studentDateDisplayFormat}));
  } else {
    if ($gwversion) {
      $status = $r->maketext("Open, complete by [_1].",  $self->formatDateTime($set->due_date(),undef,$ce->{studentDateDisplayFormat}));
    } else {
      $status = $r->maketext("Open, closes [_1].",  $self->formatDateTime($set->due_date(),undef,$ce->{studentDateDisplayFormat}));  
    }

    if ($enable_reduced_scoring && $reduced_scoring_date &&
	$t > $reduced_scoring_date) {
      $status = $r->maketext("Due date [_1] has passed.",$beginReducedScoringPeriod) . CGI::br() . $r->maketext("Reduced credit can still be earned until [_1].", $self->formatDateTime($set->due_date(),undef,$ce->{studentDateDisplayFormat}));
    }
  }

  return $status;
}  
  

sub restricted_progression_msg {
  my $r = shift;
  my $open = shift;
  my $restriction = shift;
  my @restricted = @_;
  my $status = ' ';

  if (scalar(@restricted) == 1) {
    $status .= $r->maketext("To access this set you must score at least [_1]% on set [_2].", sprintf("%.0f",$restriction), @restricted);
  } else {
    $status .= $r->maketext("To access this set you must score at least [_1]% on the following sets: [_2].", sprintf("%.0f",$restriction), join(', ', @restricted));
  }

  return $status;
}

sub output_JS {
	my $self = shift;
	my $site_url = $self->r->ce->{webworkURLs}{htdocs};

	print CGI::script({ src => "$site_url/js/apps/ProblemSets/problemsets.js", defer => '' }, "");

	return "";
}

1;
