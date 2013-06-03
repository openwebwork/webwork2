################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
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
use WeBWorK::Utils qw(readFile sortByName path_is_subdir);
use WeBWorK::Localize;
# what do we consider a "recent" problem set?
use constant RECENT => 2*7*24*60*60 ; # Two-Weeks in seconds

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
		
		print CGI::start_div({-class=>"info-wrapper"});
		print CGI::start_div({class=>"info-box", id=>"InfoPanel"});
		
		# deal with instructor crap
		my $editorURL;
		if ($authz->hasPermissions($user, "access_instructor_tools")) {
			if (defined $r->param("editMode") and $r->param("editMode") eq "temporaryFile") {
				$course_info_path = $r->param("sourceFilePath");
				$course_info_path = $ce->{courseDirs}{templates}.'/'.$course_info_path unless $course_info_path =~ m!^/!;
				die "sourceFilePath is unsafe!" unless path_is_subdir($course_info_path, $ce->{courseDirs}->{templates});
				$self->addmessage(CGI::div({class=>'temporaryFile'}, $r->maketext("Viewing temporary file: "), $course_info_path));
			}
			
			my $editorPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor",  $r, courseID => $courseID);
			$editorURL = $self->systemLink($editorPage, params => { file_type => "course_info" });
		}
		
		if ($editorURL) {
			print CGI::h2($r->maketext("Course Info"), CGI::a({href=>$editorURL, target=>"WW_Editor"}, $r->maketext("~[edit~]")));
		} else {
			print CGI::h2($r->maketext("Course Info"));
		}
		
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

		print CGI::end_div();
		print CGI::end_div();
		
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
		? CGI::u($r->maketext("Name"))
		: CGI::a({href=>$self->systemLink($urlpath, params=>{sort=>"name"})}, $r->maketext("Name"));
	my $statusHeader = $sort eq "status"
		? CGI::u($r->maketext("Status"))
		: CGI::a({href=>$self->systemLink($urlpath, params=>{sort=>"status"})}, $r->maketext("Status"));
# print the start of the form

    print CGI::start_form(-method=>"POST",-action=>$actionURL),
          $self->hidden_authen_fields;
    
# and send the start of the table
# UPDATE - ghe3
# This table now contains a summary and a caption, scope attributes for the column headers, and no longer prints a column for 'Sel.' (due to it having been merged with the second column for accessibility purposes).
	print CGI::start_table({ -class=>"problem_set_table", -summary=>"This table lists out the available homework sets for this class, along with its current status. Click on the link on the name of the homework sets to take you to the problems in that homework set.  Clicking on the links in the table headings will sort the table by the field it corresponds to.  You can also select sets for download to PDF or TeX format using the radio buttons or checkboxes next to the problem set names, and then clicking on the 'Download PDF or TeX Hardcopy for Selected Sets' button at the end of the table.  There is also a clear button and an Email instructor button at the end of the table."});
	print CGI::caption($r->maketext("Homework Sets"));
	if ( ! $existVersions ) {
	    print CGI::Tr({},
		    CGI::th({-scope=>"col"},$nameHeader),
		    CGI::th({-scope=>"col"},$statusHeader),
	        );
	} else {
	    print CGI::Tr(
		    CGI::th({-scope=>"col"},$nameHeader),
		    CGI::th({-scope=>"col"},$r->maketext("Test Score")),
		    CGI::th({-scope=>"col"},$r->maketext("Test Date")),
		    CGI::th({-scope=>"col"},$statusHeader),
	        );
	}

	debug("Begin sorting merged sets");

# before building final set lists, exclude proctored gateway sets 
#    for users without permission to view them
	my $viewPr = $authz->hasPermissions( $user, "view_proctored_tests" );
	@gwSets = grep {$_->assignment_type !~ /proctored/ || $viewPr} @gwSets;
	
	if ( $sort eq 'name' ) {
	    @nonGWsets = sortByName("set_id", @nonGWsets);
	    @gwSets = sortByName("set_id", @gwSets);
	} elsif ( $sort eq 'status' ) {
	    @nonGWsets = sort byUrgency  @nonGWsets;
	    @gwSets = sort byUrgency @gwSets;
	}
# we sort set versions by name
	@vSets = sortByName(["set_id", "version_id"], @vSets);

# put together a complete list of sorted sets to consider
	@sets = (@nonGWsets, @gwSets );
	
	debug("End preparing merged sets");

# we do regular sets and the gateway set templates separately
# from the actual set-versions, to avoid managing a tricky test
# for a version number that may not exist
	foreach my $set (@sets) {
		die "set $set not defined" unless $set;
		
		if ($set->visible || $authz->hasPermissions($user, "view_hidden_sets")) {
			print $self->setListRow($set, $authz->hasPermissions($user, "view_multiple_sets"), $authz->hasPermissions($user, "view_unopened_sets"),$existVersions,$db);
		}
	}
	foreach my $set (@vSets) {
		die "set $set not defined" unless $set;
		
		if ($set->visible || $authz->hasPermissions($user, "view_hidden_sets")) {
			print $self->setListRow($set, $authz->hasPermissions($user, "view_multiple_sets"), $authz->hasPermissions($user, "view_unopened_sets"),$existVersions,$db,1, $gwSetsBySetID{$set->{set_id}}, "ethet" );  # 1 = gateway, versioned set
		}
	}
	
	print CGI::end_table();
	my $pl = ($authz->hasPermissions($user, "view_multiple_sets") ? "s" : "");
# 	print CGI::p(CGI::submit(-name=>"hardcopy", -label=>$r->maketext("Download Hardcopy for Selected [plural,_1,Set,Sets]",$pl)));

	# UPDATE - ghe3
	# Added reset button to form.
	print CGI::start_div({-class=>"problem_set_options"});
	print CGI::p(WeBWorK::CGI_labeled_input(-type=>"reset", -input_attr=>{-value=>$r->maketext("Clear")}));
	print CGI::p(WeBWorK::CGI_labeled_input(-type=>"submit", -input_attr=>{-name=>"hardcopy", -value=>$r->maketext("Download PDF or TeX Hardcopy for Selected Sets")}));
	print CGI::endform();
	
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
	#	CGI::endform(),"\n";
	
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
	print CGI::end_div();
	
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
	my $urlpath = $r->urlpath;
	$gwtype = 0 if ( ! defined( $gwtype ) );
	$tmplSet = $set if ( ! defined( $tmplSet ) );
	
	my $name = $set->set_id;
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

	    $problemSetPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::GatewayQuiz", $r, 
				      courseID => $courseName, setID => $urlname);
	}

	my $interactiveURL = $self->systemLink($problemSetPage,
	                                       params=>{  displayMode => $self->{displayMode}, 
													  showOldAnswers => $self->{will}->{showOldAnswers}
										   }
	);

  # check to see if this is a template gateway assignment
	$gwtype = 2 if ( defined( $set->assignment_type() ) && 
			 $set->assignment_type() =~ /gateway/ && ! $gwtype );
  # and get problemRecords if we're dealing with a versioned set, so that
  #    we can test status and scores
  # FIXME: should we really have to get the merged 
  # problem_versions here?  it looks that way, because
  # otherwise we don't inherit things like the problem
  # value properly.
	my @problemRecords = 
		$db->getAllProblemVersions($set->user_id(), $set->set_id(),
					   $set->version_id()) 
		if ( $gwtype == 1 );

  # the conditional here should be redundant.  ah well.
	$interactiveURL =~ s|/quiz_mode/|/proctored_quiz_mode/| if 
	    ( defined( $set->assignment_type() ) && 
	      $set->assignment_type() eq 'proctored_gateway' );
	my $display_name = $name;
	$display_name =~ s/_/&nbsp;/g;
# this is the link to the homework assignment
	my $interactive = CGI::a({-href=>$interactiveURL}, "$display_name");
	
	my $control = "";
	
	my $setIsOpen = 0;
	my $status = '';
	if ( $gwtype ) {
		if ( $gwtype == 1 ) {
		  unless (ref($problemRecords[0]) ) {warn "Error: problem not defined in set $display_name"; return()}
			if ( $problemRecords[0]->num_correct() + 
			     $problemRecords[0]->num_incorrect() >= 
			     ( ( !($set->attempts_per_version()) ) ? 0 : $set->attempts_per_version() ) ) {
				$status = $r->maketext("completed.");
			} elsif ( time() > $set->due_date() + 
				  $self->r->ce->{gatewayGracePeriod} ) {
				$status = $r->maketext("over time: closed.");
			} else {
				$status = $r->maketext("open: complete by [_1]",  
					$self->formatDateTime($set->due_date(),undef,$ce->{studentDateDisplayFormat}));
			}
			# we let people go back to old tests
			$setIsOpen = 1;

			# reset the link to give the test number
			my $vnum = $set->version_id;
			$interactive = CGI::a({-href=>$interactiveURL},
					      $r->maketext("[_1] (test [_2])", $display_name, $vnum));
		} else {
			my $t = time();
			if ( $t < $set->open_date() ) {
				$status = $r->maketext("will open on [_1]", $self->formatDateTime($set->open_date,undef,$ce->{studentDateDisplayFormat}));
				if ( $preOpenSets ) {
					# reset the link
					$interactive = CGI::a({-href=>$interactiveURL},
							      $r->maketext("Take [_1] test", $display_name));
				} else {
					$control = "";
					$interactive = $r->maketext("[_1] test", $display_name);
				}
			} elsif ( $t < $set->due_date() ) {
				$status = $r->maketext("now open, due ") . $self->formatDateTime($set->due_date,undef,$ce->{studentDateDisplayFormat});
				$setIsOpen = 1;
				$interactive = CGI::a({-href=>$interactiveURL},
						      $r->maketext("Take [_1] test", $display_name));
			} else {
				$status = $r->maketext("Closed");

				if ( $authz->hasPermissions( $user, "record_answers_after_due_date" ) ) {
					$interactive = CGI::a({-href=>$interactiveURL},
							      $r->maketext("Take [_1] test", $display_name));
				} else {
					$interactive = $r->maketext("[_1] test", $display_name);
				}
			}
		}

# old conditional
	} elsif (time < $set->open_date) {
		$status = $r->maketext("will open on [_1]", $self->formatDateTime($set->open_date,undef,$ce->{studentDateDisplayFormat}));
		$control = "" unless $preOpenSets;
		$interactive = $name unless $preOpenSets;
	} elsif (time < $set->due_date) {
			$status = $r->maketext("now open, due ") . $self->formatDateTime($set->due_date,undef,$ce->{studentDateDisplayFormat});
			my $enable_reduced_scoring = $set->enable_reduced_scoring;
			my $reducedScoringPeriod = $ce->{pg}->{ansEvalDefaults}->{reducedScoringPeriod};
			if ($reducedScoringPeriod > 0 and $enable_reduced_scoring ) {
				my $reducedScoringPeriodSec = $reducedScoringPeriod*60;   # $reducedScoringPeriod is in minutes
				my $beginReducedScoringPeriod =  $self->formatDateTime($set->due_date() - $reducedScoringPeriodSec,undef,$ce->{studentDateDisplayFormat});
#				$status .= '. <FONT COLOR="#cc6600">Reduced Credit starts ' . $beginReducedScoringPeriod . '</FONT>';
				$status .= CGI::div({-class=>"ResultsAlert"}, $r->maketext("Reduced Credit Starts: [_1]", $beginReducedScoringPeriod));

			}
		$setIsOpen = 1;
	} elsif (time < $set->answer_date) {
		$status = $r->maketext("closed, answers on [_1]", $self->formatDateTime($set->answer_date,undef,$ce->{studentDateDisplayFormat}));
	} elsif ($set->answer_date <= time and time < $set->answer_date +RECENT ) {
		$status = $r->maketext("closed, answers recently available");
	} else {
		$status = $r->maketext("closed, answers available");
	}
	
	if ($multiSet) {
		if ( $gwtype < 2 ) {
			$control = WeBWorK::CGI_labeled_input(
				-type=>"checkbox",
				-id=>$name . ($gwtype ? ",v" . $set->version_id : ''),
				-label_text=>$interactive,
				-input_attr=>{
					-name=>"selected_sets",
					-value=>$name . ($gwtype ? ",v" . $set->version_id : '')
					}
			);
		} else {
			$control = $interactive;
		}
	} else {
		if ( $gwtype < 2 ) {
			my $n = $name  . ($gwtype ? ",v" . $set->version_id : '');
			$control = WeBWorK::CGI_labeled_input(
				-type=>"radio",
				-id=>$n,
				-label_text=>$interactive,
				-input_attr=>{
					-name=>"selected_sets",
					-value=>$n
					}
			);
		} else {
			$control = $interactive;
		}
	}

	my $visiblityStateClass = ($set->visible) ? "visible" : "hidden";

	$status = CGI::font({class=>$visiblityStateClass}, $status) if $preOpenSets;
	
# check to see if we need to return a score and a date column
	if ( ! $existVersions ) {
	    return CGI::Tr(CGI::td([
			     $control,
		             $status,
	    ]));
	} else {
		my ( $startTime, $score );

		if ( defined( $set->assignment_type() ) && 
		     $set->assignment_type() =~ /gateway/ && $gwtype == 1 ) {
			$startTime = localtime($set->version_creation_time() || 0); #fixes error message for undefined creation_time

			if ( $authz->hasPermissions($user, "view_hidden_work") || 
			     $set->hide_score_by_problem eq 'Y' ||
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
				$score = "$score/$possible";
			} else {
				$score = "n/a";
			}
		} else {
			$startTime = '&nbsp;';
			$score = $startTime;
		}
		return CGI::Tr(CGI::td([
		                     $control,
		                     $score,
		                     $startTime,
		                     $status,
		]));
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

1;
