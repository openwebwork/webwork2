################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/ProblemList.pm,v 1.34 2006/01/11 22:41:51 dpvc Exp $
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

package WeBWorK::ContentGenerator::Instructor::ProblemList;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemList - List and edit problems in a set

=cut

# This file is currently in an intermediate form, at best.  The look
# for global editting has changed significantly.  The look for dealing
# with a single student is pretty much the same as before, except for
# rendering the problems.

# For now, this leaves the code in a clumsy state, with the two versions
# given in their entirety different clauses of an if-then-else.

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(readDirectory list2hash max);
use WeBWorK::DB::Record::Set;
use WeBWorK::Utils::Tasks qw(renderProblems);


use constant PROBLEM_FIELDS =>[qw(source_file value max_attempts)];
use constant PROBLEM_USER_FIELDS => [qw(problem_seed status num_correct num_incorrect)];

sub problemElementHTML {
	my ($fieldName, $fieldValue, $size, $override, $overrideValue) = @_;
	my $attributeHash = {type => "text", name => $fieldName, value => $fieldValue};
	$attributeHash->{size} = $size if defined $size;
	my $html;
#	my $html = CGI::input($attributeHash);
	
	unless (defined $override) {
		$html = CGI::input($attributeHash);
	} else {
		$html = $fieldValue;
		$attributeHash->{name} = "${fieldName}.override";
		$attributeHash->{value} = ($override ? $overrideValue : "");
		$html = "default:" . CGI::br() . $html . CGI::br()
			. CGI::checkbox({
				type => "checkbox",
				name => "override",
				label => "override:",
				value => $fieldName,
				checked => ($override ? 1 : 0)
			})
			. CGI::br()
			. CGI::input($attributeHash);
	}
	
	return $html;
}

sub problem_number_popup {
	my $num = shift;
	my $total = shift;
	return (CGI::popup_menu(-name => "problem_num_$num",
				-values => [1..$total],
				-default => $num));
}

sub handle_problem_numbers {
	my $newProblemNumbersref = shift;
	my %newProblemNumbers = %$newProblemNumbersref;
	my $maxNum = shift;
	my $db = shift;
	my $setName = shift;
	my $force = shift || 0;
	my @sortme=();
	my ($j, $val);

	foreach $j (keys %newProblemNumbers) {
		# what happens our first time on this page
		return "" if (not defined $newProblemNumbers{"$j"});
		if ($newProblemNumbers{"$j"} != $j) {
			$force = 1;
			$val = 1000 * $newProblemNumbers{$j} - $j;
		} else {
			$val = 1000 * $newProblemNumbers{$j};
		}
		push @sortme, [$j, $val];
		$newProblemNumbers{$j} = $db->getGlobalProblem($setName, $j);
		die "global $j for set $setName not found." unless $newProblemNumbers{$j};
	}

	return "" unless $force;

	@sortme = sort {$a->[1] <=> $b->[1]} @sortme;
	# now, for global and each user with this set, loop through problem list
	#   get all of the problem records
	# assign new problem numbers
	# loop - if number is new, put the problem record
	# print "Sorted to get ". join(', ', map {$_->[0] } @sortme) ."<p>\n";


	# Now, three stages.  First global values

	for ($j = 0; $j < scalar @sortme; $j++) {
		if($sortme[$j]->[0] == $j + 1) {
			# do nothing
		} elsif (not defined $newProblemNumbers{$j + 1}) {
			$newProblemNumbers{$sortme[$j]->[0]}->problem_id($j + 1);
			$db->addGlobalProblem($newProblemNumbers{$sortme[$j]->[0]});
		} else {
			$newProblemNumbers{$sortme[$j]->[0]}->problem_id($j + 1);
			$db->putGlobalProblem($newProblemNumbers{$sortme[$j]->[0]});
		}
	}

	my @setUsers = $db->listSetUsers($setName);
	my (@problist, $user);
	my $globalUserID = $db->{set}->{params}->{globalUserID} || '';

	foreach $user (@setUsers) {
		# if this is gdbm, the global user has been taken care of above.
		# we can't do it again.  This relies on the global user not having
		# a blank name.
		next if $globalUserID eq $user;
		for $j (keys %newProblemNumbers) {
			$problist[$j] = $db->getUserProblem($user, $setName, $j);
			die " problem $j for set $setName and effective user $user not found" 
				unless $problist[$j];
		}
		# ok, now we have all problem data for $user
		for($j = 0; $j < scalar @sortme; $j++) { 
			if ($sortme[$j]->[0] == $j + 1) {
				# do nothing
			} elsif (not defined $newProblemNumbers{$j + 1}) { 
				$problist[$sortme[$j]->[0]]->problem_id($j + 1); 
				$db->addUserProblem($problist[$sortme[$j]->[0]]); 
			} else { 
				$problist[$sortme[$j]->[0]]->problem_id($j + 1); 
				$db->putUserProblem($problist[$sortme[$j]->[0]]); 
			} 
		} 
	}


	foreach ($j = scalar @sortme; $j < $maxNum; $j++) {
		if (defined $newProblemNumbers{$j + 1}) {
			$db->deleteGlobalProblem($setName, $j+1);
		}
	}

	return join(', ', map {$_->[0]} @sortme);
}

# swap index given with next bigger index
# leftover from when we had up/down buttons
# maybe we will bring them back

sub moveme {
	my $index = shift;
	my $db = shift;
	my $setName = shift;
	my (@problemList) = @_;
	my ($prob1, $prob2, $prob);

	foreach $prob (@problemList) {
		my $problemRecord = $db->getGlobalProblem($setName, $prob); # checked
		die "global $prob for set $setName not found." unless $problemRecord;
		if ($problemRecord->problem_id == $index) {
			$prob1 = $problemRecord;
		} elsif ($problemRecord->problem_id == $index + 1) {
			$prob2 = $problemRecord;
		}
	}
	if (not defined $prob1 or not defined $prob2) {
		die "cannot find problem $index or " . ($index + 1);
	}

	$prob1->problem_id($index + 1);
	$prob2->problem_id($index);
	$db->putGlobalProblem($prob1);
	$db->putGlobalProblem($prob2);

	my @setUsers = $db->listSetUsers($setName);

	my $user;
	foreach $user (@setUsers) {
		$prob1 = $db->getUserProblem($user, $setName, $index); #checked
		die " problem $index for set $setName and effective user $user not found"
			unless $prob1;
		$prob2 = $db->getUserProblem($user, $setName, $index+1); #checked
		die " problem $index for set $setName and effective user $user not found"
			unless $prob2;
    		$prob1->problem_id($index+1);
		$prob2->problem_id($index);
		$db->putUserProblem($prob1);
		$db->putUserProblem($prob2);
	}
}


sub initialize {
	my ($self)    = @_;
	my $r         = $self->r;
	my $db        = $r->db;
	my $ce        = $r->ce;
	my $authz     = $r->authz;
	my $user      = $r->param('user');
	my $setName   = $r->urlpath->arg("setID");
	my $setRecord = $db->getGlobalSet($setName); # checked
	die "global set $setName  not found." unless $setRecord;

	$self->{set}  = $setRecord;
	my @editForUser = $r->param('editForUser');
	# some useful booleans
	my $forUsers   = scalar(@editForUser);
	my $forOneUser = $forUsers == 1;

	# Check permissions
	return unless ($authz->hasPermissions($user, "access_instructor_tools"));
	return unless ($authz->hasPermissions($user, "modify_problem_sets"));

	# build a quick lookup table
	my %overrides = list2hash $r->param('override');

	my @problemList = $db->listGlobalProblems($setName);	# the Problem form was submitted
	if (defined($r->param('submit_problem_changes'))) {
		foreach my $problem (@problemList) {
			my $problemRecord = $db->getGlobalProblem($setName, $problem); # checked
			die "global $problem for set $setName not found." unless $problemRecord;
	    
			foreach my $field (@{PROBLEM_FIELDS()}) {
				my $paramName = "problem.${problem}.${field}";
				if (defined($r->param($paramName))) {
					my $pvalue = $r->param($paramName);
					if ($field eq "max_attempts") {
						$pvalue =~ s/[^-\d]//g;
						$pvalue = -1 if $pvalue eq "";
					}
					$problemRecord->$field($pvalue);
				}
			}
			$db->putGlobalProblem($problemRecord);
	    
			if ($forOneUser) {
				my $userProblemRecord = $db->getUserProblem($editForUser[0], $setName, $problem); # checked
				die " problem $problem for set $setName and effective user $editForUser[0] not found" unless $userProblemRecord;
				foreach my $field (@{PROBLEM_USER_FIELDS()}) {
					my $paramName = "problem.${problem}.${field}";
					if (defined($r->param($paramName))) {
						$userProblemRecord->$field($r->param($paramName));
					}
				}

				foreach my $field (@{PROBLEM_FIELDS()}) {
					my $paramName = "problem.${problem}.${field}";
					if (defined($r->param("${paramName}.override"))) {
						if (exists $overrides{$paramName}) {
							$userProblemRecord->$field($r->param("${paramName}.override"));
						} else {
							$userProblemRecord->$field(undef);
						}
					}
				}

				# the attempted field has to be computed from num correct and num incorrect
				my $attempted = ($userProblemRecord->num_correct+$userProblemRecord->num_incorrect > 0) ? 1 : 0;
				$userProblemRecord->attempted($attempted);
				$db->putUserProblem($userProblemRecord);
			}
		}

		foreach my $problem ($r->param('deleteProblem')) {
			$db->deleteGlobalProblem($setName, $problem);
		}
	
	} else {
		# Look for up and down buttons
		my $index = 2;
		while ($index <= scalar @problemList) {
			if (defined $r->param("move.up.$index.x")) {
				moveme($index-1, $db, $setName, @problemList);
			}
			$index++;
		}
		$index = 1;
		
		while ($index < scalar @problemList) {
			if (defined $r->param("move.down.$index.x")) {
				moveme($index, $db, $setName, @problemList);
			}
			$index++;
		}
	}
}

sub title {
	my ($self)    = @_;
	my $r         = $self->r;
	my $setName   = $r->urlpath->arg("setID");
	
	#print "\n<!-- BEGIN " . __PACKAGE__ . "::title -->\n";
	print $r->urlpath->name. " for set $setName ";
	#print "<!-- END " . __PACKAGE__ . "::title -->\n";
	
	return "";
}

sub body {
	my ($self)      = @_;
	my $r           = $self->r;
	my $db          = $r->db;
	my $ce          = $r->ce;
	my $authz       = $r->authz;
	my $user        = $r->param('user');
	my $urlpath     = $r->urlpath;
	my $courseName  = $urlpath->arg("courseID");
	my $setName     = $urlpath->arg("setID");
	my $setRecord   = $db->getGlobalSet($setName); 
	die "Global set $setName not found." unless $setRecord;
	my @editForUser = $r->param('editForUser');
	
	my $problemListPage  = $urlpath -> newFromModule($urlpath->module, courseID => $courseName, setID => $setName);
	my $problemListURL   = $self->systemLink($problemListPage,authen=>0);
	# some useful booleans
	my $forUsers    = scalar(@editForUser);
	my $forOneUser  = $forUsers == 1;
	my $editForUserName = $editForUser[0];
    
	# Check permissions
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($r->param("user"), "access_instructor_tools");
	
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to modify problems.")
		unless $authz->hasPermissions($r->param("user"), "modify_problem_sets");
	
	my $userCount        = $db->listUsers();
	my $setUserCount     = $db->countSetUsers($setName);
	my $editUsersAssignedToSetURL = $self->systemLink(
	      $urlpath->newFromModule(
                "WeBWorK::ContentGenerator::Instructor::UsersAssignedToSet",
                  courseID => $courseName, setID => $setName));

	my $userCountMessage = CGI::a({href=>$editUsersAssignedToSetURL},
		$self->userCountMessage($setUserCount, $userCount));

	$userCountMessage = "The set $setName is assigned to " . $userCountMessage . ".";

	if (@editForUser) {
		print CGI::p("$userCountMessage  Editing user-specific overrides for ". CGI::b(join ", ", @editForUser));
	} else {
		print CGI::p($userCountMessage);
	}

	## Problems Form ##
	my @problemList = $db->listGlobalProblems($setName);
 	print CGI::a({name=>"problems"});
# 	print CGI::h2({}, "Problems");
	
	my %newProblemNumbers = ();
	my $maxProblemNumber = -1;
	for my $jj (@problemList) {
		$newProblemNumbers{$jj} = $r->param('problem_num_' . $jj);
		$maxProblemNumber = $jj if $jj > $maxProblemNumber;
	}

	my $forceRenumber = $r->param('force_renumber') || 0;
#print "<p> old order: ".join(', ', @problemList);
#print "<p> new order: ". handle_problem_numbers(\%newProblemNumbers, $maxProblemNumber, $db, $setName, $forceRenumber);
	handle_problem_numbers(\%newProblemNumbers, $maxProblemNumber, $db, $setName, $forceRenumber);

	@problemList = $db->listGlobalProblems($setName); #reload them

	if (scalar @problemList) {
		# This will contain the mode list control
		my $problemWord = 'Display&nbsp;Mode:&nbsp;';
		my %display_modes = %{WeBWorK::PG::DISPLAY_MODES()};
		my @active_modes = grep { exists $display_modes{$_} } @{$r->ce->{pg}->{displayModes}};
		push @active_modes, 'None';
		my $default_mode = $r->param('mydisplaymode') || 'None';
		$problemWord .= CGI::popup_menu(-name => "mydisplaymode",
						-values => \@active_modes,
						-default => $default_mode);
		$problemWord .= '&nbsp;'. CGI::input({type => "submit", name => "refresh", value => "Refresh"});

	  if($forUsers) {
############### Order things differently.  This is for one user
		print CGI::start_form({method=>"POST", action=>$problemListURL.'#problems'});
		print CGI::start_table({border=>1, cellpadding=>4});
		print CGI::Tr({}, CGI::th({}, [
			($forUsers ? () : ("Delete?")), 
			"Problem",
			($forUsers ? ("Status", "Problem Seed") : ()),
			#"Source File", 
		        $problemWord, "Max. Attempts", "Weight",
			($forUsers ? ("Number Correct", "Number Incorrect") : ())
		]));
		foreach my $problem (sort {$a <=> $b} @problemList) {
			my $problemRecord = $db->getGlobalProblem($setName, $problem); # checked
			die "global problem $problem in set $setName not found." unless $problemRecord;
			my $problemID = $problemRecord->problem_id;
			my $userProblemRecord;
			my %problemOverrideArgs;
			my @problem_html;
			my $userSet =  $db->getUserSet($editForUser[0], $setName); # checked
			die "user homework set $setName not found." unless $userSet;

			if ($forOneUser) {
				$userProblemRecord = $db->getUserProblem($editForUser[0], $setName, $problem); # checked
				die "problem $problem for set $setName and user $editForUser[0] not found. " unless $userProblemRecord;
				foreach my $field (@{PROBLEM_FIELDS()}) {
					$problemOverrideArgs{$field} = [defined $userProblemRecord->$field && $userProblemRecord->$field ne '', $userProblemRecord->$field];
				}
				@problem_html = renderProblems(r=> $r, 
				                      user => $db->getUser($editForUser[0]),
				                      displayMode=> $default_mode,
				                      problem_number=> $problem,
				                      this_set=> $userSet,
						      problem_seed=> $userProblemRecord->problem_seed,
				                      problem_list =>[$problemRecord->source_file]);

	#		} elsif ($forUsers) {
	#			foreach my $field (@{PROBLEM_FIELDS()}) {
	#				$problemOverrideArgs{$field} = ["", ""];
	#			}
			} else {
				foreach my $field (@{PROBLEM_FIELDS()}) {
					$problemOverrideArgs{$field} = [undef, undef];
				}
			}

			print CGI::Tr({}, 
				CGI::td({}, [
					($forUsers ? () : (CGI::input({type=>"checkbox", name=>"deleteProblem", value=>$problemID}))),
					"$problemID "
						. CGI::a({href=>$self->systemLink( $urlpath->new(type=>'problem_detail',
						                                                args=>{courseID =>$courseName,setID=>$setName,problemID=>$problemID}
						                                                ),
						                                   params =>{effectiveUser => $editForUserName}
						                                 )}, "view"
						) . " "
						. CGI::a({href=>$self->systemLink( $urlpath->new(type=>'instructor_problem_editor_withset_withproblem',
						                                                args=>{courseID =>$courseName,setID=>$setName,problemID=>$problemID}
						                                                )
						                                 )}, "edit"
						),
					($forUsers ? (
						problemElementHTML("problem.${problemID}.status", $userProblemRecord->status, "7"),
						problemElementHTML("problem.${problemID}.problem_seed", $userProblemRecord->problem_seed, "7"),
					) : ()),
					problemElementHTML("problem.${problemID}.source_file", $problemRecord->source_file, "40", @{$problemOverrideArgs{source_file}}) .

					CGI::br(). CGI::div({class=> "RenderSolo"}, $problem_html[0]->{body_text})
,
					problemElementHTML("problem.${problemID}.max_attempts",$problemRecord->max_attempts,"7", @{$problemOverrideArgs{max_attempts}}),
					problemElementHTML("problem.${problemID}.value",$problemRecord->value,"7", @{$problemOverrideArgs{value}}),
					($forUsers ? (
						problemElementHTML("problem.${problemID}.num_correct", $userProblemRecord->num_correct, "7"),
						problemElementHTML("problem.${problemID}.num_incorrect", $userProblemRecord->num_incorrect, "7")
					) : ())
				])

			)
		}
		print CGI::end_table();
		print $self->hiddenEditForUserFields(@editForUser);
		print $self->hidden_authen_fields;
		print CGI::input({type=>"submit", name=>"submit_problem_changes", value=>"Save Problem Changes"});
		print CGI::end_form();
	      } else {
################################ Second go for global version
################################ forUsers will be false

		print CGI::start_form({method=>"POST", action=>$problemListURL.'#problems'});
		print CGI::start_table({border=>1, cellpadding=>4});
		print CGI::Tr({}, CGI::th({}, [
			"Data",
			$problemWord
		]));
		my (%shown_yet) = ();
		foreach my $problem (sort {$a <=> $b} @problemList) {
			my $problemRecord = $db->getGlobalProblem($setName, $problem); # checked
			die "global problem $problem in set $setName not found." unless $problemRecord;
			my $problemID = $problemRecord->problem_id;
			my $userProblemRecord;
			my %problemOverrideArgs;
			my $have_this_one = '';
			if(defined($shown_yet{$problemRecord->source_file})) {
			  $have_this_one = "This problem uses the same source file as number " . $shown_yet{$problemRecord->source_file} . ".";
			} else {
			  $shown_yet{$problemRecord->source_file} = $problemID;
			}

			my @problem_html = renderProblems(r=> $r, 
			                      user => $db->getUser($user),
			                      displayMode=> $default_mode,
			                      problem_number=> $problem,
			                      problem_list =>[$problemRecord->source_file]);


			foreach my $field (@{PROBLEM_FIELDS()}) {
			  $problemOverrideArgs{$field} = [undef, undef];
			}

			print CGI::Tr({}, 
				CGI::td({}, [
			          problem_number_popup($problemID, $maxProblemNumber) .
			          '&nbsp;'.
			          CGI::a({href=>$self->systemLink( 
			            $urlpath->new(type=>'instructor_problem_editor_withset_withproblem',
			              args=>{courseID =>$courseName,setID=>$setName,problemID=>$problemID}
			            )
			          ), target=>"WW_Editor"}, "Edit it" ) .
			          '&nbsp;'.
			        CGI::a({href=>$self->systemLink( $urlpath->new(type=>'problem_detail',
			          args=>{courseID =>$courseName,setID=>$setName,problemID=>$problemID}
			           ),
			          params =>{effectiveUser => $editForUserName}  ), target=>"WW_View"}, "Try it") . 

			        CGI::br() .
			        CGI::start_table().
			        CGI::Tr({}, CGI::td({-align=>"right"}, "Delete?"),
			          CGI::td({-align=>"left"}, CGI::input({type=>"checkbox", 
			            name=>"deleteProblem", value=>$problemID}))).
			          CGI::Tr({}, CGI::td({-align=>"right"}, 'Max&nbsp;Attempts:'),
			            CGI::td({-align=>"left"}, CGI::input({type=>"text", 
			              name=>"problem.${problemID}.max_attempts",
			              value=>
			                (($problemRecord->max_attempts<0)? "unlim": $problemRecord->max_attempts), size=>"4"}))).
			            CGI::Tr({}, CGI::td({-align=>"right"}, 'Weight:'),
			              CGI::td({-align=>"left"}, CGI::input({type=>"text", 
			                name=>"problem.${problemID}.value",
			                value=>$problemRecord->value, size=>"4"}))).
			        CGI::end_table(),

			        problemElementHTML("problem.${problemID}.source_file", 
			          $problemRecord->source_file, "50", 
			          @{$problemOverrideArgs{source_file}}) .

			        CGI::br().
			        CGI::div({class=> "RenderSolo"}, $problem_html[0]->{body_text})
			          . ($have_this_one ? CGI::div({class=>"ResultsWithError", 
			            style=>"font-weight: bold"}, $have_this_one) : '') ,
				]) # end of table entry
			) # end of table row
		} # end of loop over problems
		print CGI::end_table();
		print $self->hiddenEditForUserFields(@editForUser);
		print $self->hidden_authen_fields;
		print CGI::checkbox({
				  label=> "Force problems to be numbered consecutively from one",
				  name=>"force_renumber", value=>"1"}),

		  CGI::br();
		print CGI::input({type=>"submit", name=>"submit_problem_changes", value=>"Save Problem Changes"});
		print CGI::p(<<HERE);
Any time problem numbers are intentionally changed, the problems will
always be renumbered consecutively, starting from one.  When deleting
problems, gaps will be left in the numbering unless the box above is
checked.
HERE
                print CGI::p("It is before the open date.  You probably want to renumber the problems if you are deleting some from the middle.") if ($setRecord->open_date>time());
		print CGI::p("When changing problem numbers, we will move 
 the problem to be ", CGI::em("before"), " the chosen number.");

		print CGI::end_form();

	      }

	} else {
		print CGI::p("This set doesn't contain any problems yet.");
	}

	return "";
}

1;
