################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/ProblemSet.pm,v 1.38 2003/12/12 02:24:29 gage Exp $
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
use CGI qw();
use WeBWorK::PG;

sub initialize {
	my ($self, $setName) = @_;
	my $courseEnvironment = $self->{ce};
	my $r = $self->{r};
	my $db = $self->{db};
	my $userName = $r->param("user");
	my $effectiveUserName = $r->param("effectiveUser");
	
	my $user            = $db->getUser($userName); # checked
	my $effectiveUser   = $db->getUser($effectiveUserName); # checked
	my $set             = $db->getMergedSet($effectiveUserName, $setName); # checked
	my $permissionLevel = $db->getPermissionLevel($userName)->permission(); # checked
	
	die "user $user (real user) not found."  unless $user;
	die "effective user $effectiveUserName  not found. One 'acts as' the effective user."  unless $effectiveUser;
	die "set $setName for effectiveUser $effectiveUserName not found." unless $set;
	die "permisson level for user $userName  not found."  unless defined $permissionLevel;

	$self->{userName}        = $userName;
	$self->{user}            = $user;
	$self->{effectiveUser}   = $effectiveUser;
	$self->{set}             = $set;
	$self->{permissionLevel} = $permissionLevel;
	
	##### permissions #####
	
	$self->{isOpen} = time >= $set->open_date || $permissionLevel > 0;
}

sub path {
	my ($self, $setName, $args) = @_;
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home" => "$root",
		$courseName => "$root/$courseName",
		$setName => "",
	);
}

sub nav {
	my ($self, $setName, $args) = @_;
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my @links = ("Problem Sets" , "$root/$courseName", "navUp");
	my $tail = "";
	
	return $self->navMacro($args, $tail, @links);
}
	

sub siblings {
	my ($self, $setName) = @_;
#	$WeBWorK::timer0->continue('begin  siblings');
	my $ce = $self->{ce};
	my $db = $self->{db};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $effectiveUser = $self->{r}->param("effectiveUser");
	
	print CGI::strong("Problem Sets"), CGI::br();
	
	my @sets;
	
	#  FIXME   The following access to the complete list of sets is very slow.
	#  $WeBWorK::timer0->continue('collect siblings');
	#  push @sets, $db->getMergedSet($effectiveUser, $_)
	#  	  foreach ($db->listUserSets($effectiveUser));
	
	my @setNames = $db->listUserSets($effectiveUser);
	@setNames   = sort @setNames;
#	$WeBWorK::timer0->continue('done collecting siblings');
	# FIXME only experience will tell us the best sorting procedure.
	# due_date seems right for students, but alphabetically may be more
	# useful for professors?
	
# 	my @sorted_sets;
# 	
# 	# sort by set name
# 	#@sorted_sets = sort { $a->set_id cmp $b->set_id } @sets;
# 	
# 	# sort by set due date
# 	$WeBWorK::timer0->continue('begin sorting siblings');
# 	@sorted_sets = sort { $a->due_date <=> $b->due_date } @sets;
# 	
# 	# ...and put closed sets last;
# 	my $now = time();
# 	my @open_sets = grep { $_->due_date > $now } @sorted_sets;
# 	my @closed_sets = grep { $_->due_date <= $now } @sorted_sets;
# 	@sorted_sets = (@open_sets,@closed_sets);
# 	$WeBWorK::timer0->continue('end sorting siblings');
# 	foreach my $set (@sorted_sets) { 
# 		if (time >= $set->open_date) {
# 			print CGI::a({-href=>"$root/$courseName/".$set->set_id."/?"
# 				. $self->url_authen_args}, $set->set_id), CGI::br();
# 		} else {
# 			print $set->set_id, CGI::br();
# 		}
# 	}
# hack to put links up quickly FIXME when database is faster.
	foreach my $setName (@setNames) {
	
		print '&nbsp;&nbsp;'.CGI::a({-href=>"$root/$courseName/".$setName."/?"
 				. $self->url_authen_args}, $setName), CGI::br();
	
	
	}
}

sub title {
	my ($self, $setName) = @_;
	
	return $setName;
}

sub info {
	my ($self, $setName) = @_;
	
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $db = $self->{db};
	
	return "" unless $self->{isOpen};
	
	my $effectiveUser = $db->getUser($r->param("effectiveUser")); # checked 
	die "effective user ".$r->param("effectiveUser")." not found. One 'acts as' the effective user."  unless $effectiveUser;
	my $set  = $db->getMergedSet($effectiveUser->user_id, $setName); # checked
	die "set $setName for effectiveUser ".$effectiveUser->user_id." not found." unless $set;
	my $psvn = $set->psvn();
	
	my $screenSetHeader = $set->set_header || $ce->{webworkFiles}->{screenSnippets}->{setHeader};
	my $displayMode     = $ce->{pg}->{options}->{displayMode};
	
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
	# Add link for editor
	#### link to edit setHeader 
	my $editor_link			= '';
	if (defined($set) and $set->set_header and 
	    $self->{permissionLevel} >= $ce->{permissionLevels}->{modify_problem_sets} ) {  
	    #FIXME ?  can't edit the default set header this way
		$editor_link = CGI::p(
		                    CGI::a({-href=>$ce->{webworkURLs}->{root}.'/'.$ce->{courseName}.
								'/instructor/pgProblemEditor/'.
								$set->set_id.'/0'. '?'.$self->url_authen_args},
								'Edit set header: '.$set->set_header
		          			)
		);
	}	
	# handle translation errors
	if ($pg->{flags}->{error_flag}) {
		return $self->errorOutput($pg->{errors}, $pg->{body_text}.$editor_link);
	} else {
		return $pg->{body_text}.$editor_link;
	}
}

sub body {
	my ($self, $setName) = @_;
	my $r = $self->{r};
	my $courseEnvironment = $self->{ce};
	my $db = $self->{db};
	my $effectiveUser = $r->param('effectiveUser');
	my $set = $db->getMergedSet($effectiveUser, $setName);  # checked
	die "set $setName for user $effectiveUser not found" unless $set;
	
	print "$setName is due: ",WeBWorK::Utils::formatDateTime($set->due_date);
	return CGI::p(CGI::font({-color=>"red"}, "This problem set is not available because it is not yet open."))
		unless ($self->{isOpen});
	
	my $hardcopyURL =
		$courseEnvironment->{webworkURLs}->{root} . "/"
		. $courseEnvironment->{courseName} . "/"
		. "hardcopy/$setName/?" . $self->url_authen_args;
	print CGI::p(CGI::a({-href=>$hardcopyURL}, "Download a hardcopy"),
		"of this problem set.");
	
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
	
	# feedback form
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $feedbackURL = "$root/$courseName/feedback/";
# 	print
# 		CGI::startform("POST", $feedbackURL),
# 		$self->hidden_authen_fields,
# 		CGI::hidden("module", __PACKAGE__),
# 		CGI::hidden("set",    $set->set_id),
# 		CGI::p({-align=>"right"},
# 			CGI::submit(-name=>"feedbackForm", -label=>"Send Feedback")
# 		),
# 		CGI::endform();
	#print feedback form
	print
		CGI::start_form(-method=>"POST", -action=>$feedbackURL),"\n",
		$self->hidden_authen_fields,"\n",
		CGI::hidden("module",             __PACKAGE__),"\n",
		CGI::hidden("set",                $self->{set}->set_id),"\n",
		CGI::hidden("problem",            ""),"\n",
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
	my $self = shift;
	my $set = shift;
	my $problem = shift;
	
	my $name = $problem->problem_id;
	my $interactiveURL = "$name/?" . $self->url_authen_args;
	my $interactive = CGI::a({-href=>$interactiveURL}, "Problem $name");
	my $attempts = $problem->num_correct + $problem->num_incorrect;
	my $remaining = $problem->max_attempts < 0
		? "unlimited"
		: $problem->max_attempts - $attempts;
	my $status = sprintf("%.0f%%", $problem->status * 100); # round to whole number
	
	return CGI::Tr(CGI::td({-nowrap=>1}, [
		$interactive,
		$attempts,
		$remaining,
		$status,
	]));
}

1;
