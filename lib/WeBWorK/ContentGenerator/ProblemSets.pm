################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/ProblemSets.pm,v 1.79 2006/07/14 21:25:11 gage Exp $
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
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::Utils qw(readFile sortByName path_is_subdir);

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
		
		print CGI::start_div({class=>"info-box", id=>"InfoPanel"});
		
		# deal with instructor crap
		my $editorURL;
		if ($authz->hasPermissions($user, "access_instructor_tools")) {
			if (defined $r->param("editMode") and $r->param("editMode") eq "temporaryFile") {
				$course_info_path = $r->param("sourceFilePath");
				$course_info_path = $ce->{courseDirs}{templates}.'/'.$course_info_path unless $course_info_path =~ m!^/!;
				die "sourceFilePath is unsafe!" unless path_is_subdir($course_info_path, $ce->{courseDirs}->{templates});
				$self->addmessage(CGI::div({class=>'temporaryFile'}, "Viewing temporary file: ", $course_info_path));
			}
			
			my $editorPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor", courseID => $courseID);
			$editorURL = $self->systemLink($editorPage, params => { file_type => "course_info" });
		}
		
		if ($editorURL) {
			print CGI::h2("Course Info", CGI::a({href=>$editorURL, target=>"WW_Editor"}, "[edit]"));
		} else {
			print CGI::h2("Course Info");
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
	
	my $hardcopyPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Hardcopy", courseID => $courseName);
	my $actionURL = $self->systemLink($hardcopyPage, authen => 0); # no authen info for form action
	
# we have to get sets and versioned sets separately
	my @setIDs = $db->listUserSets($effectiveUser);
	my @vSetIDs = $db->listUserSetVersions($effectiveUser);
	
	my @userSetIDs = map {[$effectiveUser, $_]} @setIDs;
	my @vUserSetIDs = map {[$effectiveUser, /(.*),v\d+$/, $_]} @vSetIDs;
	debug("Begin collecting merged sets");
	my @sets = $db->getMergedSets( @userSetIDs );
	my @vSets = (@vSetIDs) ? $db->getMergedVersionedSets(@vUserSetIDs) : ();
	
	debug("Begin fixing merged sets");
	
	# Database fix (in case of undefined published values)
	# this may take some extra time the first time but should NEVER need to be run twice
	# this is only necessary because some people keep holding to ww1.9 which did not have a published field
	foreach my $set (@sets) {
		# make sure published is set to 0 or 1
		if ( $set and $set->published ne "0" and $set->published ne "1") {
			my $globalSet = $db->getGlobalSet($set->set_id);
			$globalSet->published("1");	# defaults to published
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
	foreach ( @sets ) {
	    if ( defined( $_->assignment_type() ) && 
		 $_->assignment_type() =~ /gateway/ ) {
		$existVersions = 1; 
		push( @gwSets, $_ ) 
		    if ( $_->assignment_type() !~ /proctored/ ||
			 $authz->hasPermissions($user,"view_proctored_tests") );
	    } else {
		push( @nonGWsets, $_ );
	    }
	}

# set sort method
	$sort = "status" unless $sort eq "status" or $sort eq "name";

# now set the headers for the table
	my $nameHeader = $sort eq "name"
		? CGI::u("Name")
		: CGI::a({href=>$self->systemLink($urlpath, params=>{sort=>"name"})}, "Name");
	my $statusHeader = $sort eq "status"
		? CGI::u("Status")
		: CGI::a({href=>$self->systemLink($urlpath, params=>{sort=>"status"})}, "Status");
# print the start of the form

    print CGI::start_form(-method=>"POST",-action=>$actionURL),
          $self->hidden_authen_fields;
    
# and send the start of the table 
	print CGI::start_table();
	if ( ! $existVersions ) {
	    print CGI::Tr({},
		    CGI::th("Sel."),
		    CGI::th($nameHeader),
		    CGI::th($statusHeader),
	        );
	} else {
	    print CGI::Tr(
		    CGI::th("Sel."),
		    CGI::th($nameHeader),
		    CGI::th("Score"),
		    CGI::th("Date"),
		    CGI::th($statusHeader),
	        );
	}

	debug("Begin sorting merged sets");
	
	if ( $sort eq 'name' ) {
	    @nonGWsets = sortByName("set_id", @nonGWsets);
	    @gwSets = sortByName("set_id", @gwSets);
	} elsif ( $sort eq 'status' ) {
	    @nonGWsets = sort byUrgency  @nonGWsets;
	    @gwSets = sort byUrgency @gwSets;
	}
# we sort set versions by name; this at least in part relies on versions
# being finished by the time they show up on the list here.
	@vSets = sortByName("set_id", @vSets);

# put together a complete list of sorted sets to consider
	@sets = (@nonGWsets, @gwSets, @vSets);
	
	debug("End preparing merged sets");
	
	foreach my $set (@sets) {
		die "set $set not defined" unless $set;
		
		if ($set->published || $authz->hasPermissions($user, "view_unpublished_sets")) {
			print $self->setListRow($set, $authz->hasPermissions($user, "view_multiple_sets"), $authz->hasPermissions($user, "view_unopened_sets"),$existVersions,$db);
		}
	}
	
	print CGI::end_table();
	my $pl = ($authz->hasPermissions($user, "view_multiple_sets") ? "s" : "");
	print CGI::p(CGI::submit(-name=>"hardcopy", -label=>"Download Hardcopy for Selected Set$pl"));
	print CGI::endform();
	
	## feedback form url
	#my $feedbackPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Feedback", courseID => $courseName);
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
	
	return "";
}

sub setListRow {
	my ($self, $set, $multiSet, $preOpenSets, $existVersions, $db) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $urlpath = $r->urlpath;
	
	my $name = $set->set_id;
	my $courseName      = $urlpath->arg("courseID");
	
	my $problemSetPage;

	if ( ! defined( $set->assignment_type() ) || 
	     $set->assignment_type() !~ /gateway/ ) {
	    $problemSetPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",
				      courseID => $courseName, setID => $name);
	} elsif( $set->assignment_type() !~ /proctored/ ) {

	    $problemSetPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::GatewayQuiz",
				      courseID => $courseName, setID => $name);
	} else {

	    $problemSetPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::GatewayQuiz",
				      courseID => $courseName, setID => $name);
	}

	my $interactiveURL = $self->systemLink($problemSetPage,
	                                       params=>{  displayMode => $self->{displayMode}, 
													  showOldAnswers => $self->{will}->{showOldAnswers}
										   }
	);
  # check for gateway and template gateway assignments
	my $gwtype = 0;
	if ( defined( $set->assignment_type() ) && 
	     $set->assignment_type() =~ /gateway/ ) {
	    if ( $name =~ /,v\d+$/ ) {
		$gwtype = 1;
	    } else {
		$gwtype = 2;
	    }
	}

  # the conditional here should be redundant.  ah well.
	$interactiveURL =~ s|/quiz_mode/|/proctored_quiz_mode/| if 
	    ( defined( $set->assignment_type() ) && 
	      $set->assignment_type() eq 'proctored_gateway' );
	
	my $control = "";
	if ($multiSet) {
		if ( $gwtype < 2 ) {
			$control = CGI::checkbox(
				-name=>"selected_sets",
				-value=>$name,
				-label=>"",
			);
		} else {
			$control = '&nbsp;';
		}
	} else {
		if ( $gwtype < 2 ) {
			$control = CGI::radio_group(
				-name=>"selected_sets",
				-values=>[$name],
				-default=>"-",
				-labels=>{$name => ""},
			);
		} else {
			$control = '&nbsp;';
		}
	}
	
	$name =~ s/_/&nbsp;/g;
	my $interactive = CGI::a({-href=>$interactiveURL}, "$name");
# edit this a bit for gateways 
	if ( $gwtype ) {
	    if ( $gwtype == 1 ) {
		my $sname = $name;
		$sname =~ s/,v(\d+)$//;
		$interactive = CGI::a({-href=>$interactiveURL}, 
				      "$sname (test$1)");
	    } else {  # this is the case of a template URL
		$interactive = CGI::a({-href=>$interactiveURL}, 
				      "Take new $name test");
	    }
	}
	
# for gateways, we aren't as verbose about open/closed status, because 
#    there's only one attempt and we default to showing answers once the 
#    test is done.
	my $status;
	if ( $gwtype ) {
	    if ( $gwtype == 1 ) {
		$status = ' ';  # for g/w, we only give one attempt per version,
                                #    so by the time we're here it's closed
	    } else {            
		my $t = time();
		if ( $t < $set->open_date() ) {
		    $status = "will open on " . $self->formatDateTime($set->open_date);
		    $control = "" unless $preOpenSets;
		    $interactive = $name unless $preOpenSets;
		} elsif ( $t < $set->due_date() ) {
		    $status = "open, due " . $self->formatDateTime($set->due_date);
		} else {
		    $status = "closed";
		}
	    }
# old conditional
	} elsif (time < $set->open_date) {
		$status = "will open on " . $self->formatDateTime($set->open_date);
		$control = "" unless $preOpenSets;
		$interactive = $name unless $preOpenSets;
	} elsif (time < $set->due_date) {
           if ( $set->set_id() !~ /,v\d+$/ ) {
	        $status = "now open, due " . $self->formatDateTime($set->due_date);
	    } else {
		$status = "now open (if version attempts remain), due " . $self->formatDateTime($set->due_date);
	    }
	} elsif (time < $set->answer_date) {
		$status = "closed, answers on " . $self->formatDateTime($set->answer_date);
	} elsif ($set->answer_date <= time and time < $set->answer_date +RECENT ) {
		$status = "closed, answers recently available";
	} else {
		$status = "closed, answers available";
	}
	
	my $publishedClass = ($set->published) ? "Published" : "Unpublished";

	$status = CGI::font({class=>$publishedClass}, $status) if $preOpenSets;
	
# check to see if we need to return a score and a date column
	if ( ! $existVersions ) {
	    return CGI::Tr(CGI::td([
			     $control,
                             $interactive,
		             $status,
	    ]));
	} else {
	    my ( $startTime, $score );

		if ( defined( $set->assignment_type() ) && 
		 $set->assignment_type() =~ /gateway/ &&
		 $set->set_id() =~ /,v\d+$/ ) {
			$startTime = localtime( $set->version_creation_time() );

			# find score
			my @problemRecords = $db->getAllUserProblems( $set->user_id(),
							      $set->set_id() );
			my $possible = 0;
			$score = 0;
			foreach my $pRec ( @problemRecords ) {
				if ( defined( $pRec ) && $score ne 'undef' ) {
					$score += $pRec->status() || 0;
				} else {
					$score = 'undef';
				}
				$possible++;
			}
			$score = "$score/$possible";
		} else {
			$startTime = '&nbsp;';
			$score = $startTime;
		}
		return CGI::Tr(CGI::td([
		                     $control,
		                     $interactive,
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
