################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# 
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

package WeBWorK::ContentGenerator::Instructor::ProblemSetDetail;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetDetail - Edit general set and specific user/set information as well as problem information

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::HTML::ComboBox qw/comboBox/;
use WeBWorK::Utils qw(readDirectory list2hash listFilesRecursive max);
use WeBWorK::DB::Record::Set;
use WeBWorK::Utils::Tasks qw(renderProblems);
use WeBWorK::Debug;

# Important Note: the following two sets of constants may seem similar 
# 	but they are functionally and semantically different

# these constants determine which fields belong to what type of record
use constant SET_FIELDS => [qw(set_header hardcopy_header open_date due_date answer_date published assignment_type attempts_per_version version_time_limit versions_per_interval time_interval problem_randorder)];
use constant PROBLEM_FIELDS =>[qw(source_file value max_attempts)];
use constant USER_PROBLEM_FIELDS => [qw(problem_seed status num_correct num_incorrect)];

# these constants determine what order those fields should be displayed in
use constant HEADER_ORDER => [qw(set_header hardcopy_header)];
use constant PROBLEM_FIELD_ORDER => [qw(problem_seed status value max_attempts attempted last_answer num_correct num_incorrect)];

# we exclude the gateway set fields from the set field order, because they
# are only displayed for sets that are gateways.  this results in a bit of 
# convoluted logic below, but it saves burdening people who are only using 
# homework assignments with all of the gateway parameters
use constant SET_FIELD_ORDER => [qw(open_date due_date answer_date published assignment_type)];
use constant GATEWAY_SET_FIELD_ORDER => [qw(attempts_per_version version_time_limit time_interval versions_per_interval problem_randorder)];

# this constant is massive hash of information corresponding to each db field.
# override indicates for how many students at a time a field can be overridden
# this hash should make it possible to NEVER have explicitly: if (somefield) { blah() }
#
#	All but name are optional
#	some_field => {
#		name      => "Some Field",
#		type      => "edit",		# edit, choose, hidden, view - defines how the data is displayed
#		size      => "50",		# size of the edit box (if any)
#		override  => "none",		# none, one, any, all - defines for whom this data can/must be overidden
#		module    => "problem_list",	# WeBWorK module 
#		default   => 0			# if a field cannot default to undefined/empty what should it default to
#		labels    => {			# special values can be hashed to display labels
#				1 => "Yes",
#				0 => "No",
#		},

use constant BLANKPROBLEM => 'blankProblem.pg';

use constant  FIELD_PROPERTIES => {
	# Set information
	set_header => {
		name      => "Set Header",
		type      => "edit",
		size      => "50",
		override  => "all",
		module    => "problem_list",
		default   => "",
	},
	hardcopy_header => {
		name      => "Hardcopy Header",
		type      => "edit",
		size      => "50",
		override  => "all",
		module    => "hardcopy_preselect_set",
		default   => "",		
	},
	open_date => {
		name      => "Opens",
		type      => "edit",
		size      => "26",
		override  => "any",
		labels    => {
				#0 => "None Specified",
				"" => "None Specified",
		},
	},
	due_date => {
		name      => "Answers Due",
		type      => "edit",
		size      => "26",
		override  => "any",
		labels    => {
				#0 => "None Specified",
				"" => "None Specified",
		},
	},
	answer_date => {
		name      => "Answers Available",
		type      => "edit",
		size      => "26",
		override  => "any",
		labels    => {
				#0 => "None Specified",
				"" => "None Specified",
		},
	},
	published => {
		name      => "Visible to Students",
		type      => "choose",
		override  => "all",
		choices   => [qw( 0 1 )],
		labels    => {
				1 => "Yes",
				0 => "No",
		},
	},
	assignment_type => {
		name      => "Assignment type",
		type      => "choose",
		override  => "all",
		choices   => [qw( default gateway proctored_gateway )],
		labels    => {	default => "homework",
				gateway => "gateway/quiz",
				proctored_gateway => "proctored gateway/quiz",
		},
	},
	attempts_per_version => {
		name      => "Attempts per Version (untested for &gt; 1)",
		type      => "edit",
		size      => "3",
		override  => "all",
#		labels    => {	"" => 1 },
	},
	version_time_limit => {
		name      => "Test Time Limit (sec)",
		type      => "edit",
		size      => "4",
		override  => "all",
		labels    => {	"" => 0 },  # I'm not sure this is quite right
	},
	time_interval => {
		name      => "Time Interval for New Versions (sec)",
		type      => "edit",
                size      => "5",
		override  => "all",
		labels    => {	"" => 0 },
	},
	versions_per_interval => {
		name      => "Number of New Versions per Time Interval (0=infty)",
		type      => "edit",
                size      => "3",
		override  => "all",
#		labels    => {	"" => 1 },
	},
	problem_randorder => {
		name      => "Order Problems Randomly",
		type      => "choose",
		choices   => [qw( 0 1 )],
		override  => "all",
		labels    => {	0 => "No", 1 => "Yes" },
	},
	# Problem information
	source_file => {
		name      => "Source File",
		type      => "edit",
		size      => 50,
		override  => "any",
		default   => "",
	},
	value => {
		name      => "Weight",
		type      => "edit",
		size      => 6,
		override  => "any",
	},
	max_attempts => {
		name      => "Max&nbsp;attempts",
		type      => "edit",
		size      => 6,
		override  => "any",
		labels    => {
				"-1" => "unlimited",
		},
	},
	problem_seed => {
		name      => "Seed",
		type      => "edit",
		size      => 6,
		override  => "one",
		
	},
	status => {
		name      => "Status",
		type      => "edit",
		size      => 6,
		override  => "one",
		default   => 0,
	},
	attempted => {
		name      => "Attempted",
		type      => "hidden",
		override  => "none",
		choices   => [qw( 0 1 )],
		labels    => {
				1 => "Yes",
				0 => "No",
		},
		default   => 0,
	},
	last_answer => {
		name      => "Last Answer",
		type      => "hidden",
		override  => "none",
	},
	num_correct => {
		name      => "Correct",
		type      => "hidden",
		override  => "none",
		default   => 0,
	},
	num_incorrect => {
		name      => "Incorrect",
		type      => "hidden",
		override  => "none",
		default   => 0,
	},	
};

# Create a table of fields for the given parameters, one row for each db field
# if only the setID is included, it creates a table of set information
# if the problemID is included, it creates a table of problem information
sub FieldTable {
	my ($self, $userID, $setID, $problemID, $globalRecord, $userRecord) = @_;

	my $r = $self->r;	
	my @editForUser = $r->param('editForUser');
	my $forUsers    = scalar(@editForUser);
	my $forOneUser  = $forUsers == 1;

	my @fieldOrder;
	my $gwoutput = '';
	if (defined $problemID) {
		@fieldOrder = @{ PROBLEM_FIELD_ORDER() };
	} else {
		@fieldOrder = @{ SET_FIELD_ORDER() };

    # gateway data fields are included only if the set is a gateway
		if ( $globalRecord->assignment_type() =~ /gateway/ ) {
			$gwoutput = "\n<!-- begin gwoutput table -->\n" . CGI::start_table({border => 0, cellpadding => 1});
			foreach my $gwfield ( @{ GATEWAY_SET_FIELD_ORDER() } ) {
				$gwoutput .= CGI::Tr({}, CGI::td({}, [$self->FieldHTML($userID, $setID, $problemID, $globalRecord, $userRecord, $gwfield)]));
		    	}
		    	$gwoutput .= CGI::end_table() . "\n<!-- end gwoutput table -->\n";
		}
	}

	my $output = CGI::start_table({border => 0, cellpadding => 1});
	if ($forUsers) {
		$output .= CGI::Tr(
		    CGI::th({colspan=>"2"}, "&nbsp;"),
			CGI::th({colspan=>"1"}, "User Values"),
			CGI::th({}, "Class values"),
		);
	}
	
	foreach my $field (@fieldOrder) {
		my %properties = %{ FIELD_PROPERTIES()->{$field} };
		unless ($properties{type} eq "hidden") {
			$output .= CGI::Tr({}, CGI::td({}, [$self->FieldHTML($userID, $setID, $problemID, $globalRecord, $userRecord, $field)])) . "\n";
		}
  # this is a rather artifical addition to include gateway fields, which we 
  # only want to show for gateways
		$output .= CGI::Tr({}, CGI::td({colspan => '4'}, $gwoutput)) . "\n"
		    if ( $field eq 'assignment_type' &&
			 $globalRecord->assignment_type() =~ /gateway/ );
	} 

	if (defined $problemID) {
		#my $problemRecord = $r->{db}->getUserProblem($userID, $setID, $problemID);
		my $problemRecord = $userRecord; # we get this from the caller, hopefully
		$output .= CGI::Tr({}, CGI::td({}, ["","Attempts", ($problemRecord->num_correct || 0) + ($problemRecord->num_incorrect || 0)])) if $forOneUser;
	}		
	$output .= CGI::end_table();
	
	return $output;
}

# Returns a list of information and HTML widgets
# for viewing and editing the specified db fields
# if only the setID is included, it creates a list of set information
# if the problemID is included, it creates a list of problem information
sub FieldHTML {
	my ($self, $userID, $setID, $problemID, $globalRecord, $userRecord, $field) = @_;
	
	my $r = $self->r;
	my $db = $r->db;
	my @editForUser = $r->param('editForUser');
	my $forUsers    = scalar(@editForUser);
	my $forOneUser  = $forUsers == 1;

	#my ($globalRecord, $userRecord, $mergedRecord);
	#if (defined $problemID) { 	
	#	$globalRecord = $db->getGlobalProblem($setID, $problemID);
	#	$userRecord = $db->getUserProblem($userID, $setID, $problemID);
	#	#$mergedRecord = $db->getMergedProblem($userID, $setID, $problemID); # never used --sam
	#} else {
	#	$globalRecord = $db->getGlobalSet($setID);
	#	$userRecord = $db->getUserSet($userID, $setID);
	#	#$mergedRecord = $db->getMergedSet($userID, $setID); # never user --sam
	#}
	
	return "No data exists for set $setID and problem $problemID" unless $globalRecord;
	return "No user specific data exists for user $userID" if $forOneUser and $globalRecord and not $userRecord;
	
	my %properties = %{ FIELD_PROPERTIES()->{$field} };
	my %labels = %{ $properties{labels} };
	return "" if $properties{type} eq "hidden";
	return "" if $properties{override} eq "one" && not $forOneUser;
	return "" if $properties{override} eq "none" && not $forOneUser;
	return "" if $properties{override} eq "all" && $forUsers;
			
	my $edit = ($properties{type} eq "edit") && ($properties{override} ne "none");
	my $choose = ($properties{type} eq "choose") && ($properties{override} ne "none");
	
	my $globalValue = $globalRecord->{$field};
	# use defined instead of value in order to allow 0 to printed, e.g. for the 'value' field
	$globalValue = (defined($globalValue)) ? ($labels{$globalValue || ""} || $globalValue) : "";
	my $userValue = $userRecord->{$field};
	$userValue = (defined($userValue)) ? ($labels{$userValue || ""} || $userValue) : "";

	if ($field =~ /_date/) {
		$globalValue = $self->formatDateTime($globalValue) if defined $globalValue && $globalValue ne $labels{""};
		$userValue = $self->formatDateTime($userValue) if defined $userValue && $userValue ne $labels{""};
	}

	# check to make sure that a given value can be overridden
	my %canOverride = map { $_ => 1 } (@{ PROBLEM_FIELDS() }, @{ SET_FIELDS() });
	my $check = $canOverride{$field};

	# $recordType is a shorthand in the return statement for problem or set
	# $recordID is a shorthand in the return statement for $problemID or $setID
	my $recordType = "";
	my $recordID = "";
	if (defined $problemID) {
		$recordType = "problem";
		$recordID = $problemID;
	} else {
		$recordType = "set";
		$recordID = $setID;
	}
	
	# $inputType contains either an input box or a popup_menu for changing a given db field
	my $inputType = "";
	if ($edit) {
		$inputType = CGI::input({
				name => "$recordType.$recordID.$field",
				value => $r->param("$recordType.$recordID.$field") || ($forUsers ? $userValue : $globalValue),
				size => $properties{size} || 5,
		});
	} elsif ($choose) {
		# Note that in popup menus, you're almost guaranteed to have the choices hashed to labels in %properties
		# but $userValue and and $globalValue are the values in the hash not the keys
		# so we have to use the actual db record field values to select our default here.
		$inputType = CGI::popup_menu({
				name => "$recordType.$recordID.$field",
				values => $properties{choices},
				labels => \%labels,
				default => $r->param("$recordType.$recordID.$field") || ($forUsers ? $userRecord->$field : $globalRecord->$field),
		});
	}
	
	return (($forUsers && $edit && $check) ? CGI::checkbox({
				type => "checkbox",
				name => "$recordType.$recordID.$field.override",
				label => "",
				value => $field,
				checked => $r->param("$recordType.$recordID.$field.override") || ($userValue ne ($labels{""} || "") ? 1 : 0),
		}) : "",
		$properties{name},
		$inputType,
		$forUsers ? " $globalValue" : "",
	);
}

# creates a popup menu of all possible problem numbers (for possible rearranging)
sub problem_number_popup {
	my $num = shift;
	my $total = shift;
	return (CGI::popup_menu(-name => "problem_num_$num",
				-values => [1..$total],
				-default => $num));
}

# handles rearrangement necessary after changes to problem ordering
sub handle_problem_numbers {
	my $newProblemNumbersref = shift;
	my %newProblemNumbers = %$newProblemNumbersref;
	my $maxNum = shift;
	my $db = shift;
	my $setID = shift;
	my $force = shift || 0;
	my @sortme=();
	my ($j, $val);

	# keys are current problem numbers, values are target problem numbers
	foreach $j (keys %newProblemNumbers) {
		# we don't want to act unless all problems have been assigned a new problem number, so if any have not, return
		return "" if (not defined $newProblemNumbers{"$j"});
		# if the problem has been given a new number, we reduce the "score" of the problem by the original number of the problem
		# when multiple problems are assigned the same number, this results in the last one ending up first -- FIXME?
		if ($newProblemNumbers{"$j"} != $j) {
			# force always gets set if reordering is done, so don't expect to be able to delete a problem,
			# reorder some other problems, and end up with a hole -- FIXME
			$force = 1;
			$val = 1000 * $newProblemNumbers{$j} - $j;
		} else {
			$val = 1000 * $newProblemNumbers{$j};
		}
		# store a mapping between current problem number and score (based on currnet and new problem number)
		push @sortme, [$j, $val];
		# replace new problem numbers in hash with the (global) problems themselves
		$newProblemNumbers{$j} = $db->getGlobalProblem($setID, $j);
		die "global $j for set $setID not found." unless $newProblemNumbers{$j};
	}

	# we don't have to do anything if we're not getting rid of holes
	return "" unless $force;

	# sort the curr. prob. num./score pairs by score
	@sortme = sort {$a->[1] <=> $b->[1]} @sortme;
	# now, for global and each user with this set, loop through problem list
	#   get all of the problem records
	# assign new problem numbers
	# loop - if number is new, put the problem record
	# print "Sorted to get ". join(', ', map {$_->[0] } @sortme) ."<p>\n";


	# Now, three stages.  First global values

	for ($j = 0; $j < scalar @sortme; $j++) {
		if($sortme[$j][0] == $j + 1) {
			# if the jth problem (according to the new ordering) is in the right place (problem IDs are numbered from 1, hence $j+1)
			# do nothing
		} elsif (not defined $newProblemNumbers{$j + 1}) {
			# otherwise, if there's a hole for it, add it there
			$newProblemNumbers{$sortme[$j][0]}->problem_id($j + 1);
			$db->addGlobalProblem($newProblemNumbers{$sortme[$j][0]});
		} else {
			# otherwise, overwrite the data for the problem that's already there with the jth problem's data (with a changed problemID)
			$newProblemNumbers{$sortme[$j][0]}->problem_id($j + 1);
			$db->putGlobalProblem($newProblemNumbers{$sortme[$j][0]});
		}
	}

	my @setUsers = $db->listSetUsers($setID);
	my (@problist, $user);
	my $globalUserID = $db->{set}->{params}->{globalUserID} || '';

	foreach $user (@setUsers) {
		# if this is gdbm, the global user has been taken care of above.
		# we can't do it again.  This relies on the global user not having
		# a blank name.
		next if $globalUserID eq $user;
		# grab a copy of each UserProblem for this user. @problist can be sparse (if problems were deleted)
		for $j (keys %newProblemNumbers) {
			$problist[$j] = $db->getUserProblem($user, $setID, $j);
		}
		use Data::Dumper;
		for($j = 0; $j < scalar @sortme; $j++) { 
			if ($sortme[$j][0] == $j + 1) {
				# same as above -- the jth problem is in the right place, so don't worry about it
				# do nothing
			} elsif ($problist[$sortme[$j][0]]) {
				# we've made sure the user's problem actually exists HERE, since we want to be able to fail gracefullly if it doesn't
				# the problem with the original conditional below is that %newProblemNumbers maps oldids => global problem record
				# we need to check if the target USER PROBLEM exists, which is what @problist knows
				#if (not defined $newProblemNumbers{$j + 1}) {
				if (not defined $problist[$j+1]) {
					# same as above -- there's a hole for that problem to go into, so add it in its new place
					$problist[$sortme[$j][0]]->problem_id($j + 1); 
					$db->addUserProblem($problist[$sortme[$j][0]]); 
				} else { 
					# same as above -- there's a problem already there, so overwrite its data with the data from the jth problem
					$problist[$sortme[$j][0]]->problem_id($j + 1); 
					$db->putUserProblem($problist[$sortme[$j][0]]); 
				} 
			} else {
				warn "UserProblem missing for user=$user set=$setID problem=$sortme[$j][0]. This may indicate database corruption.\n";
				# when a problem doesn't exist in the target slot, a new problem gets added there, but the original problem
				# never gets overwritten (because there wan't a problem it would have to get exchanged with)
				# i think this can get pretty complex. consider 1=>2, 2=>3, 3=>4, 4=>1 where problem 1 doesn't exist for some user:
				# @sortme[$j][0] will contain: 4, 1, 2, 3
				# - problem 1 will get **added** with the data from problem 4 (because problem 1 doesn't exist for this user)
				# - problem 2 will get overwritten with the data from problem 1
				# - problem 3 will get overwritten with the data from problem 2
				# - nothing will happend to problem 4, since problem 1 doesn't exit
				# so the solution is to delete problem 4 altogether!
				# here's the fix:
				
				# the data from problem $j+1 was/will be moved to another problem slot,
				# but there's no problem $sortme[$j][0] to replace it. thus, we delete it now.
				$db->deleteUserProblem($user, $setID, $j+1);
			}
		} 
	}

	# any problems with IDs above $maxNum get deleted -- presumably their data has been copied into problems with lower IDs
	foreach ($j = scalar @sortme; $j < $maxNum; $j++) {
		if (defined $newProblemNumbers{$j + 1}) {
			$db->deleteGlobalProblem($setID, $j+1);
		}
	}

	# return a string form of the old problem IDs in the new order (not used by caller, incidentally)
	return join(', ', map {$_->[0]} @sortme);
}

# swap index given with next bigger index
# leftover from when we had up/down buttons
# maybe we will bring them back

#sub moveme {
#	my $index = shift;
#	my $db = shift;
#	my $setID = shift;
#	my (@problemIDList) = @_;
#	my ($prob1, $prob2, $prob);
#
#	foreach my $problemID (@problemIDList) {
#		my $problemRecord = $db->getGlobalProblem($setID, $problemID); # checked
#		die "global $problemID for set $setID not found." unless $problemRecord;
#		if ($problemRecord->problem_id == $index) {
#			$prob1 = $problemRecord;
#		} elsif ($problemRecord->problem_id == $index + 1) {
#			$prob2 = $problemRecord;
#		}
#	}
#	if (not defined $prob1 or not defined $prob2) {
#		die "cannot find problem $index or " . ($index + 1);
#	}
#
#	$prob1->problem_id($index + 1);
#	$prob2->problem_id($index);
#	$db->putGlobalProblem($prob1);
#	$db->putGlobalProblem($prob2);
#
#	my @setUsers = $db->listSetUsers($setID);
#
#	my $user;
#	foreach $user (@setUsers) {
#		$prob1 = $db->getUserProblem($user, $setID, $index); #checked
#		die " problem $index for set $setID and effective user $user not found"
#			unless $prob1;
#		$prob2 = $db->getUserProblem($user, $setID, $index+1); #checked
#		die " problem $index for set $setID and effective user $user not found"
#			unless $prob2;
#    		$prob1->problem_id($index+1);
#		$prob2->problem_id($index);
#		$db->putUserProblem($prob1);
#		$db->putUserProblem($prob2);
#	}
#}

# primarily saves any changes into the correct set or problem records (global vs user)
# also deals with deleting or rearranging problems
sub initialize {
	my ($self)    = @_;
	my $r         = $self->r;
	my $db        = $r->db;
	my $ce        = $r->ce;
	my $authz     = $r->authz;
	my $user      = $r->param('user');
	my $setID   = $r->urlpath->arg("setID");
	my $setRecord = $db->getGlobalSet($setID); # checked
	die "global set $setID  not found." unless $setRecord;

	$self->{set}  = $setRecord;
	my @editForUser = $r->param('editForUser');
	# some useful booleans
	my $forUsers   = scalar(@editForUser);
	my $forOneUser = $forUsers == 1;

	# Check permissions
	return unless ($authz->hasPermissions($user, "access_instructor_tools"));
	return unless ($authz->hasPermissions($user, "modify_problem_sets"));


	my %properties = %{ FIELD_PROPERTIES() };

	# takes a hash of hashes and inverts it
	my %undoLabels;
	foreach my $key (keys %properties) {
		%{ $undoLabels{$key} } = map { $properties{$key}->{labels}->{$_} => $_ } keys %{ $properties{$key}->{labels} };
	}

	# Unfortunately not everyone uses Javascript enabled browsers so
	# we must fudge the information coming from the ComboBoxes
	# Since the textfield and menu both have the same name, we get an array of two elements
	# We then reset the param to the first if its not-empty or the second (empty or not).
	foreach ( @{ HEADER_ORDER() } ) {
		my @values = $r->param("set.$setID.$_");
		my $value = $values[0] || $values[1] || "";	
		$r->param("set.$setID.$_", $value);
	}

	#####################################################################
	# Check date information
	#####################################################################

	my ($open_date, $due_date, $answer_date);
	my $error = 0;
	if (defined $r->param('submit_changes')) {
		my @names = ("open_date", "due_date", "answer_date");
		
		my %dates = map { $_ => $r->param("set.$setID.$_") } @names;
		%dates = map { 
			my $unlabel = $undoLabels{$_}->{$dates{$_}}; 
			$_ => defined $unlabel ? $setRecord->$_ : $self->parseDateTime($dates{$_}) 
		} @names;

		($open_date, $due_date, $answer_date) = map { $dates{$_} } @names;

		if ($answer_date < $due_date || $answer_date < $open_date) {		
			$self->addbadmessage("Answers cannot be made available until on or after the due date!");
			$error = $r->param('submit_changes');
		}
		
		if ($due_date < $open_date) {
			$self->addbadmessage("Answers cannot be due until on or after the open date!");
			$error = $r->param('submit_changes');
		}
		
		# make sure the dates are not more than 10 years in the future
		my $curr_time = time;
		my $seconds_per_year = 31_556_926;
		my $cutoff = $curr_time + $seconds_per_year*10;
		if ($open_date > $cutoff) {
			$self->addbadmessage("Error: open date cannot be more than 10 years from now in set $setID");
			$error = $r->param('submit_changes');
		}
		if ($due_date > $cutoff) {
			$self->addbadmessage("Error: due date cannot be more than 10 years from now in set $setID");
			$error = $r->param('submit_changes');
		}
		if ($answer_date > $cutoff) {
			$self->addbadmessage("Error: answer date cannot be more than 10 years from now in set $setID");
			$error = $r->param('submit_changes');
		}
		
		
		if ($error) {
			$self->addbadmessage("No changes were saved!");
		}
	}
	
	if (defined $r->param('submit_changes') && !$error) {

		#my $setRecord = $db->getGlobalSet($setID); # already fetched above --sam

		#####################################################################
		# Save general set information (including headers)
		#####################################################################

		if ($forUsers) {
			my @userRecords = $db->getUserSets(map { [$_, $setID] } @editForUser);
			foreach my $record (@userRecords) {
				foreach my $field ( @{ SET_FIELDS() } ) {
					next unless canChange($forUsers, $field);
					my $override = $r->param("set.$setID.$field.override");

					if (defined $override && $override eq $field) {

						my $param = $r->param("set.$setID.$field");
						$param = $properties{$field}->{default} || "" unless defined $param && $param ne "";
						my $unlabel = $undoLabels{$field}->{$param};
						$param = $unlabel if defined $unlabel;
#						$param = $undoLabels{$field}->{$param} || $param;
						if ($field =~ /_date/) {
							$param = $self->parseDateTime($param) unless defined $unlabel;
						}
						$record->$field($param);
					} else {
						$record->$field(undef);					
					}
				
				}
				$db->putUserSet($record);
			}
		} else {
			foreach my $field ( @{ SET_FIELDS() } ) {
				next unless canChange($forUsers, $field);

				my $param = $r->param("set.$setID.$field");
				$param = $properties{$field}->{default} || "" unless defined $param && $param ne "";
				my $unlabel = $undoLabels{$field}->{$param};
				$param = $unlabel if defined $unlabel;
				if ($field =~ /_date/) {
					$param = $self->parseDateTime($param) unless defined $unlabel;
				}
				$setRecord->$field($param);
			}
			$db->putGlobalSet($setRecord);
		}
		
		#####################################################################
		# Save problem information
		#####################################################################

		my @problemIDs = sort { $a <=> $b } $db->listGlobalProblems($setID);;
		my @problemRecords = $db->getGlobalProblems(map { [$setID, $_] } @problemIDs);
		foreach my $problemRecord (@problemRecords) {
			my $problemID = $problemRecord->problem_id;
			die "Global problem $problemID for set $setID not found." unless $problemRecord;
			
			if ($forUsers) {
				# Since we're editing for specific users, we don't allow the GlobalProblem record to be altered on that same page
				# So we only need to make changes to the UserProblem record and only then if we are overriding a value
				# in the GlobalProblem record or for fields unique to the UserProblem record.
								
				my @userIDs = @editForUser;
				my @userProblemIDs = map { [$_, $setID, $problemID] } @userIDs;
				my @userProblemRecords = $db->getUserProblems(@userProblemIDs);
				foreach my $record (@userProblemRecords) {

					my $changed = 0; # keep track of any changes, if none are made, avoid unnecessary db accesses
					foreach my $field ( @{ PROBLEM_FIELDS() } ) {
						next unless canChange($forUsers, $field);

						my $override = $r->param("problem.$problemID.$field.override");
						if (defined $override && $override eq $field) {

							my $param = $r->param("problem.$problemID.$field");
							$param = $properties{$field}->{default} || "" unless defined $param && $param ne "";
							my $unlabel = $undoLabels{$field}->{$param};
							$param = $unlabel if defined $unlabel;
							$changed ||= changed($record->$field, $param);
							$record->$field($param);
						} else {
							$changed ||= changed($record->$field, undef);
							$record->$field(undef);
						}
						
					}
					
					foreach my $field ( @{ USER_PROBLEM_FIELDS() } ) {
						next unless canChange($forUsers, $field);

						my $param = $r->param("problem.$problemID.$field");
						$param = $properties{$field}->{default} || "" unless defined $param && $param ne "";
						my $unlabel = $undoLabels{$field}->{$param};
						$param = $unlabel if defined $unlabel;
						$changed ||= changed($record->$field, $param);
						$record->$field($param);
					}
					$db->putUserProblem($record) if $changed;
				}
			} else { 
				# Since we're editing for ALL set users, we will make changes to the GlobalProblem record.
				# We may also have instances where a field is unique to the UserProblem record but we want
				# all users to (at least initially) have the same value

				# this only edits a globalProblem record
				my $changed = 0; # keep track of any changes, if none are made, avoid unnecessary db accesses
				foreach my $field ( @{ PROBLEM_FIELDS() } ) {
					next unless canChange($forUsers, $field);

					my $param = $r->param("problem.$problemID.$field");
					$param = $properties{$field}->{default} || "" unless defined $param && $param ne "";
					my $unlabel = $undoLabels{$field}->{$param};
					$param = $unlabel if defined $unlabel;
					$changed ||= changed($problemRecord->$field, $param);
					$problemRecord->$field($param);
				}
				$db->putGlobalProblem($problemRecord) if $changed;


				# sometimes (like for status) we might want to change an attribute in
				# the userProblem record for every assigned user
				# However, since this data is stored in the UserProblem records,
				# it won't be displayed once its been changed and if you hit "Save Changes" again
				# it gets erased
				
				# So we'll enforce that there be something worth putting in all the UserProblem records
				# This also will make hitting "Save Changes" on the global page MUCH faster
				my %useful;
				foreach my $field ( @{ USER_PROBLEM_FIELDS() } ) {
					my $param = $r->param("problem.$problemID.$field");
					$useful{$field} = 1 if defined $param and $param ne "";
				}

				if (keys %useful) {
					my @userIDs = $db->listProblemUsers($setID, $problemID);
					my @userProblemIDs = map { [$_, $setID, $problemID] } @userIDs;
					my @userProblemRecords = $db->getUserProblems(@userProblemIDs);
					foreach my $record (@userProblemRecords) {
						my $changed = 0; # keep track of any changes, if none are made, avoid unnecessary db accesses
						foreach my $field ( keys %useful ) {
							next unless canChange($forUsers, $field);

							my $param = $r->param("problem.$problemID.$field");
							$param = $properties{$field}->{default} || "" unless defined $param && $param ne "";
							my $unlabel = $undoLabels{$field}->{$param};
							$param = $unlabel if defined $unlabel;
							$changed ||= changed($record->$field, $param);
							$record->$field($param);
						}
						$db->putUserProblem($record) if $changed;
					}
				}
			}
		}
		
		# Mark the specified problems as correct for all users
		foreach my $problemID ($r->param('markCorrect')) {
			my @userProblemIDs = map { [$_, $setID, $problemID] } ($forUsers ? @editForUser : $db->listProblemUsers($setID, $problemID));
			my @userProblemRecords = $db->getUserProblems(@userProblemIDs);
			foreach my $record (@userProblemRecords) {
				if (defined $record && ($record->status eq "" || $record->status < 1)) {
					$record->status(1);
					$record->attempted(1);
					$db->putUserProblem($record);
				}
			}
		}
		
		# Delete all problems marked for deletion
		foreach my $problemID ($r->param('deleteProblem')) {
			$db->deleteGlobalProblem($setID, $problemID);
		}
		
		#####################################################################
		# Add blank problem if needed
		#####################################################################
		if (defined($r->param("add_blank_problem") ) and $r->param("add_blank_problem") == 1) {
					my $targetProblemNumber   =  1+ WeBWorK::Utils::max( $self->r->db->listGlobalProblems($setID));
					##################################################
					# make local copy of the blankProblem
					##################################################
					my $blank_file_path       =  $ce->{webworkFiles}->{screenSnippets}->{blankProblem};
					my $problemContents       =  WeBWorK::Utils::readFile($blank_file_path);
					my $new_file_path         =  "set$setID/".BLANKPROBLEM();
					my $fullPath              =  WeBWorK::Utils::surePathToFile($ce->{courseDirs}->{templates},'/'.$new_file_path);
					local(*TEMPFILE);
					open(TEMPFILE, ">$fullPath") or warn "Can't write to file $fullPath";
					print TEMPFILE $problemContents;
					close(TEMPFILE);
					
					#################################################
					# Update problem record
					#################################################
					my $problemRecord  = $self->addProblemToSet(
							   setName        => $setID,
							   sourceFile     => $new_file_path, 
							   problemID      => $targetProblemNumber, #added to end of set
					);
					$self->assignProblemToAllSetUsers($problemRecord);
					$self->addgoodmessage("Added $new_file_path to ". $setID. " as problem $targetProblemNumber") ;
		}
		
		# Sets the specified header to "" so that the default file will get used.
		foreach my $header ($r->param('defaultHeader')) {
			$setRecord->$header("");
		}
	}	
	
# Leftover code from when there were up/down buttons

#	} else {
#		# Look for up and down buttons
#		my $index = 2;
#		while ($index <= scalar @problemList) {
#			if (defined $r->param("move.up.$index.x")) {
#				moveme($index-1, $db, $setID, @problemList);
#			}
#			$index++;
#		}
#		$index = 1;
#		
#		while ($index < scalar @problemList) {
#			if (defined $r->param("move.down.$index.x")) {
#				moveme($index, $db, $setID, @problemList);
#			}
#			$index++;
#		}
#	}


	# This erases any sticky fields if the user saves changes, resets the form, or reorders problems
	# It may not be obvious why this is necessary when saving changes or reordering problems
	# 	but when the problems are reorder the param problem.1.source_file needs to be the source
	#	file of the problem that is NOW #1 and not the problem that WAS #1.
	unless (defined $r->param('refresh')) {
		
		# reset all the parameters dealing with set/problem/header information
		# if the current naming scheme is changed/broken, this could reek havoc
		# on all kinds of things
		foreach my $param ($r->param) {
			$r->param($param, "") if $param =~ /^(set|problem|header)\./  && $param !~ /displaymode/;
		}
	}
}

# helper method for debugging
sub definedness ($) {
	my ($variable) = @_;

	return "undefined" unless defined $variable;
	return "empty" unless $variable ne "";
	return $variable;
}

# helper method for checking if two things are different
# the return values will usually be thrown away, but they could be useful for debugging
sub changed ($$) {
	my ($first, $second) = @_;

	return "def/undef" if defined $first and not defined $second;
	return "undef/def" if not defined $first and defined $second;
	return "" if not defined $first and not defined $second;
	return "ne" if $first ne $second;
	return "";	# if they're equal, there's no change
}

# helper method that determines for how many users at a time a field can be changed
# 	none means it can't be changed for anyone
# 	any means it can be changed for anyone
# 	one means it can ONLY be changed for one at a time. (eg problem_seed)
# 	all means it can ONLY be changed for all at a time. (eg set_header)
sub canChange ($$) {
	my ($forUsers, $field) = @_;
	
	my %properties = %{ FIELD_PROPERTIES() };
	my $forOneUser = $forUsers == 1;
	
	my $howManyCan = $properties{$field}->{override};
	
	return 0 if $howManyCan eq "none";
	return 1 if $howManyCan eq "any";	
	return 1 if $howManyCan eq "one" && $forOneUser;
	return 1 if $howManyCan eq "all" && !$forUsers;
	return 0;	# FIXME: maybe it should default to 1?
}

# helper method that determines if a file is valid and returns a pretty error message
sub checkFile ($) {
	my ($self, $file) = @_;

	my $r = $self->r;
	my $ce = $r->ce;

	return "No source file specified" unless $file;
	$file = $ce->{courseDirs}->{templates} . '/' . $file unless $file =~ m|^/|;

	my $text = "This source file ";
	my $fileError;
	return "" if -e $file && -f $file && -r $file;
	return $text . "is not readable!" if -e $file && -f $file;
	return $text . "is a directory!" if -d $file;
	return $text . "does not exist!" unless -e $file;
	return $text . "is not a plain file!";
}

# don't show view options -- we provide display mode controls for headers/problems separately
sub options {
	return "";
}

# Creates two separate tables, first of the headers, and the of the problems in a given set
# If one or more users are specified in the "editForUser" param, only the data for those users
# becomes editable, not all the data
sub body {

	my ($self)      = @_;
	my $r           = $self->r;
	my $db          = $r->db;
	my $ce          = $r->ce;
	my $authz       = $r->authz;
	my $userID      = $r->param('user');
	my $urlpath     = $r->urlpath;
	my $courseID    = $urlpath->arg("courseID");
	my $setID       = $urlpath->arg("setID");
	my $setRecord   = $db->getGlobalSet($setID) or die "No record for global set $setID.";

	my $userRecord = $db->getUser($userID) or die "No record for user $userID.";
	# Check permissions
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($userRecord->user_id, "access_instructor_tools");
	
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to modify problems.")
		unless $authz->hasPermissions($userRecord->user_id, "modify_problem_sets");

	my @editForUser = $r->param('editForUser');

	# Check that every user that we're editing for has a valid UserSet
	my @assignedUsers;
	my @unassignedUsers;
	if (scalar @editForUser) {
		foreach my $ID (@editForUser) {
			if ($db->getUserSet($ID, $setID)) {
				unshift @assignedUsers, $ID;
			} else {
				unshift @unassignedUsers, $ID;
			}
		}
		@editForUser = sort @assignedUsers;
		$r->param("editForUser", \@editForUser);
		
		if (scalar @editForUser && scalar @unassignedUsers) {
			print CGI::div({class=>"ResultsWithError"}, "The following users are NOT assigned to this set and will be ignored: " . CGI::b(join(", ", @unassignedUsers)));
		} elsif (scalar @editForUser == 0) {
			print CGI::div({class=>"ResultsWithError"}, "None of the selected users are assigned to this set: " . CGI::b(join(", ", @unassignedUsers)));
			print CGI::div({class=>"ResultsWithError"}, "Global set data will be shown instead of user specific data");
		}		
	}
	
	# some useful booleans
	my $forUsers    = scalar(@editForUser);
	my $forOneUser  = $forUsers == 1;

	# If you're editing for users, initially their records will be different but
	# if you make any changes to them they will be the same.
	# if you're editing for one user, the problems shown should be his/hers
	my $userToShow        = $forUsers ? $editForUser[0] : $userID;
	
	my $userCount        = $db->listUsers();
	my $setCount         = $db->listGlobalSets(); # if $forOneUser;
	my $setUserCount     = $db->countSetUsers($setID);
	my $userSetCount     = $db->countUserSets($editForUser[0]) if $forOneUser;

	
	my $editUsersAssignedToSetURL = $self->systemLink(
	      $urlpath->newFromModule(
                "WeBWorK::ContentGenerator::Instructor::UsersAssignedToSet",
                  courseID => $courseID, setID => $setID));
	my $editSetsAssignedToUserURL = $self->systemLink(
	      $urlpath->newFromModule(
                "WeBWorK::ContentGenerator::Instructor::SetsAssignedToUser",
                  courseID => $courseID, userID => $editForUser[0])) if $forOneUser;


	my $setDetailPage  = $urlpath -> newFromModule($urlpath->module, courseID => $courseID, setID => $setID);
	my $setDetailURL   = $self->systemLink($setDetailPage,authen=>0);


	my $userCountMessage = CGI::a({href=>$editUsersAssignedToSetURL}, $self->userCountMessage($setUserCount, $userCount));
	my $setCountMessage = CGI::a({href=>$editSetsAssignedToUserURL}, $self->setCountMessage($userSetCount, $setCount)) if $forOneUser;

	$userCountMessage = "The set $setID is assigned to " . $userCountMessage . ".";
	$setCountMessage  = "The user $editForUser[0] has been assigned " . $setCountMessage . "." if $forOneUser;

	if ($forUsers) {
	    ##############################################
		# calculate links for the users being edited:
		##############################################
		my @userLinks = ();
		foreach my $userID (@editForUser) {
		    my $u = $db->getUser($userID);
			my $line = $u->last_name.", ".$u->first_name."&nbsp;&nbsp;&nbsp;".$u->user_id."&nbsp;&nbsp; ";
			my $editSetsAssignedToUserURL = $self->systemLink(
	           $urlpath->newFromModule(
                "WeBWorK::ContentGenerator::Instructor::SetsAssignedToUser",
                  courseID => $courseID, userID => $u->user_id));
            $line .= CGI::a({href=>$editSetsAssignedToUserURL}, 
                     $self->setCountMessage($db->countUserSets($u->user_id), $setCount));
            unshift @userLinks,$line;
		}
		@userLinks = sort @userLinks;
	
		print CGI::table({border=>2,cellpadding=>10}, 
		    CGI::Tr(
				CGI::td([
					 "Editing problem set ".CGI::strong($setID)." data for these individual students:".CGI::br(). 
					                CGI::strong(join CGI::br(), @userLinks),
					CGI::a({href=>$setDetailURL },"Edit set ".CGI::strong($setID)." data for ALL students assigned to this set."),
				
				])
			)
		);
	} else {
		print CGI::table({border=>2,cellpadding=>10}, 
		    CGI::Tr(
				CGI::td([
					"This set ".CGI::strong($setID)." is assigned to ".$self->userCountMessage($setUserCount, $userCount).'.' ,
					'Edit '.CGI::a({href=>$editUsersAssignedToSetURL},'individual versions '). "of set $setID.",
				
				])
			)
		);
	}
	
	# handle renumbering of problems if necessary
 	print CGI::a({name=>"problems"});

	my %newProblemNumbers = ();
	my $maxProblemNumber = -1;
	for my $jj (sort { $a <=> $b } $db->listGlobalProblems($setID)) {
		$newProblemNumbers{$jj} = $r->param('problem_num_' . $jj);
		$maxProblemNumber = $jj if $jj > $maxProblemNumber;
	}

	my $forceRenumber = $r->param('force_renumber') || 0;
	handle_problem_numbers(\%newProblemNumbers, $maxProblemNumber, $db, $setID, $forceRenumber) unless defined $r->param('undo_changes');

	my %properties = %{ FIELD_PROPERTIES() };

	my %display_modes = %{WeBWorK::PG::DISPLAY_MODES()};
	my @active_modes = grep { exists $display_modes{$_} } @{$r->ce->{pg}->{displayModes}};
	push @active_modes, 'None';
	my $default_header_mode = $r->param('header.displaymode') || 'None';
	my $default_problem_mode = $r->param('problem.displaymode') || 'None';

	#####################################################################
	# Browse available header/problem files
	#####################################################################
	
	my $templates = $r->ce->{courseDirs}->{templates};
	my %probLibs = %{ $r->ce->{courseFiles}->{problibs} };
	my $skip = join("|", keys %probLibs);

	my @headerFileList = listFilesRecursive(
		$templates,
		qr/header.*\.pg$/i, 		# match these files
		qr/^(?:$skip|CVS)$/, 	# prune these directories
		0, 				# match against file name only
		1, 				# prune against path relative to $templates
	);

	# this just takes too much time to search
#	my @problemFileList = listFilesRecursive(
#		$templates,
#		qr/\.pg$/i,			# problem files don't say problem
#		qr/^(?:$skip|CVS)$/, 	# prune these directories
#		0, 				# match against file name only
#		1, 				# prune against path relative to $templates
#	);

	# Display a useful warning message
	if ($forUsers) {
		print CGI::p(CGI::b("Any changes made below will be reflected in the set for ONLY the student" . 
					($forOneUser ? "" : "s") . " listed above."));
	} else {
		print CGI::p(CGI::b("Any changes made below will be reflected in the set for ALL students."));
	}

	print CGI::start_form({method=>"POST", action=>$setDetailURL});
	print $self->hiddenEditForUserFields(@editForUser);
	print $self->hidden_authen_fields;
	print CGI::input({type=>"submit", name=>"submit_changes", value=>"Save Changes"});
	print CGI::input({type=>"submit", name=>"undo_changes", value => "Reset Form"});

	# spacing
	print CGI::p();
	
	#####################################################################
	# Display general set information
	#####################################################################

	print CGI::start_table({border=>1, cellpadding=>4});
	print CGI::Tr({}, CGI::th({}, [
		"General Information",
	]));
	
	# this is kind of a hack -- we need to get a user record here, so we can
	# pass it to FieldTable, so FieldTable can pass it to FieldHTML, so
	# FieldHTML doesn't have to fetch it itself.
	my $userSetRecord = $db->getUserSet($userToShow, $setID);
	
	print CGI::Tr({}, CGI::td({}, [
		$self->FieldTable($userToShow, $setID, undef, $setRecord, $userSetRecord),
	]));
	print CGI::end_table();	

	# spacing
	print CGI::p();

	
	#####################################################################
	# Display header information
	#####################################################################
	my @headers = @{ HEADER_ORDER() };
	my %headerModules = (set_header => 'problem_list', hardcopy_header => 'hardcopy_preselect_set');
	my %headerDefaults = (set_header => $ce->{webworkFiles}->{screenSnippets}->{setHeader}, hardcopy_header => $ce->{webworkFiles}->{hardcopySnippets}->{setHeader});
	my @headerFiles = map { $setRecord->{$_} } @headers;
	if (scalar @headers and not $forUsers) {

		print CGI::start_table({border=>1, cellpadding=>4});
		print CGI::Tr({}, CGI::th({}, [
			"Headers",
#			"Data",
			"Display&nbsp;Mode:&nbsp;" . 
			CGI::popup_menu(-name => "header.displaymode", -values => \@active_modes, -default => $default_header_mode) . '&nbsp;'. 
			CGI::input({type => "submit", name => "refresh", value => "Refresh Display"}),
		]));

		my %header_html;
		
		my %error;
		foreach my $header (@headers) {
			my $headerFile = $r->param("set.$setID.$header") || $setRecord->{$header} || $headerDefaults{$header};

			$error{$header} = $self->checkFile($headerFile);
			unless ($error{$header}) {
				my @temp = renderProblems(	r=> $r, 
								user => $db->getUser($userToShow),
								displayMode=> $default_header_mode,
								problem_number=> 0,
								this_set => $db->getMergedSet($userToShow, $setID),
								problem_list => [$headerFile],
				);
				$header_html{$header} = $temp[0];
			}
		}
		
		foreach my $header (@headers) {
	
			my $editHeaderPage = $urlpath->new(type => 'instructor_problem_editor_withset_withproblem', args => { courseID => $courseID, setID => $setID, problemID => 0 });
			my $editHeaderLink = $self->systemLink($editHeaderPage, params => { file_type => $header, make_local_copy => 1 });
		
			my $viewHeaderPage = $urlpath->new(type => $headerModules{$header}, args => { courseID => $courseID, setID => $setID });
			my $viewHeaderLink = $self->systemLink($viewHeaderPage);
			
			print CGI::Tr({}, CGI::td({}, [
				CGI::start_table({border => 0, cellpadding => 0}) . 
					CGI::Tr({}, CGI::td({}, $properties{$header}->{name})) . 
					CGI::Tr({}, CGI::td({}, CGI::a({href => $editHeaderLink}, "Edit it"))) .
					CGI::Tr({}, CGI::td({}, CGI::a({href => $viewHeaderLink}, "View it"))) .
#					CGI::Tr({}, CGI::td({}, CGI::checkbox({name => "defaultHeader", value => $header, label => "Use Default"}))) .
				CGI::end_table(),
#				"",
#				CGI::input({ name => "set.$setID.$header", value => $setRecord->{$header}, size => 50}) .
#				join ("\n", $self->FieldHTML($userToShow, $setID, $problemID, "source_file")) .
#			        	CGI::br() . CGI::div({class=> "RenderSolo"}, $problem_html[0]->{body_text}),

				comboBox({
					name => "set.$setID.$header",
					request => $r,
					default => $r->param("set.$setID.$header") || $setRecord->{$header},
					multiple => 0,
					values => ["", @headerFileList],
					labels => { "" => "Use Default Header File" },
				}) .
				($error{$header} ? 
					CGI::div({class=>"ResultsWithError", style=>"font-weight: bold"}, $error{$header}) 
					: CGI::div({class=> "RenderSolo"}, $header_html{$header}->{body_text})
				),
			]));
		}
		
		print CGI::end_table();
	} else {
		print CGI::p(CGI::b("Screen and Hardcopy set header information can not be overridden for individual students."));
	}

	# spacing
	print CGI::p();


	#####################################################################
	# Display problem information
	#####################################################################

	my @problemIDList = sort { $a <=> $b } $db->listGlobalProblems($setID);
	
	# get global problem records for all problems in one go
	my %GlobalProblems;
	my @globalKeypartsRef = map { [$setID, $_] } @problemIDList;
	@GlobalProblems{@problemIDList} = $db->getGlobalProblems(@globalKeypartsRef);
	
	# if needed, get user problem records for all problems in one go
	my (%UserProblems, %MergedProblems);
	if ($forOneUser) {
		my @userKeypartsRef = map { [$editForUser[0], $setID, $_] } @problemIDList;
		@UserProblems{@problemIDList} = $db->getUserProblems(@userKeypartsRef);
		@MergedProblems{@problemIDList} = $db->getMergedProblems(@userKeypartsRef);
	}
	
	if (scalar @problemIDList) {

		print CGI::start_table({border=>1, cellpadding=>4});
		print CGI::Tr({}, CGI::th({}, [
			"Problems",
			"Data",
			"Display&nbsp;Mode:&nbsp;" . 
			CGI::popup_menu(-name => "problem.displaymode", -values => \@active_modes, -default => $default_problem_mode) . '&nbsp;'. 
			CGI::input({type => "submit", name => "refresh", value => "Refresh Display"}),
		]));
		
		my %shownYet;
		my $repeatFile;
		foreach my $problemID (@problemIDList) {
		
			my $problemRecord;
			if ($forOneUser) {
				#$problemRecord = $db->getMergedProblem($editForUser[0], $setID, $problemID);
				$problemRecord = $MergedProblems{$problemID}; # already fetched above --sam
			} else {
				#$problemRecord = $db->getGlobalProblem($setID, $problemID);
				$problemRecord = $GlobalProblems{$problemID}; # already fetched above --sam
			}
			
			#$self->addgoodmessage("");
			#$self->addbadmessage($problemRecord->toString());
			
			
			my $editProblemPage = $urlpath->new(type => 'instructor_problem_editor_withset_withproblem', args => { courseID => $courseID, setID => $setID, problemID => $problemID });
			my $editProblemLink = $self->systemLink($editProblemPage, params => { make_local_copy => 0 });
            
            
			# FIXME: should we have an "act as" type link here when editing for multiple users?		
			my $viewProblemPage = $urlpath->new(type => 'problem_detail', args => { courseID => $courseID, setID => $setID, problemID => $problemID });
			my $viewProblemLink = $self->systemLink($viewProblemPage, params => { effectiveUser => ($forOneUser ? $editForUser[0] : $userID)});

			my @fields = @{ PROBLEM_FIELDS() };
			push @fields, @{ USER_PROBLEM_FIELDS() } if $forOneUser;

			my $problemFile = $r->param("problem.$problemID.source_file") || $problemRecord->source_file;

			# warn of repeat problems
			if (defined $shownYet{$problemFile}) {
				$repeatFile = "This problem uses the same source file as number " . $shownYet{$problemFile} . ".";
			} else {
				$shownYet{$problemFile} = $problemID;
				$repeatFile = "";
			}
			
			my $error = $self->checkFile($problemFile);
			my @problem_html;
			unless ($error) {
				@problem_html = renderProblems(	r=> $r, 
								user => $db->getUser($userToShow),
								displayMode=> $default_problem_mode,
								problem_number=> $problemID,
								this_set => $db->getMergedSet($userToShow, $setID),
								problem_seed => $forOneUser ? $problemRecord->problem_seed : 0,
								problem_list => [$problemRecord->source_file],
				);
			}

			print CGI::Tr({}, CGI::td({}, [
				CGI::start_table({border => 0, cellpadding => 1}) .
					CGI::Tr({}, CGI::td({}, problem_number_popup($problemID, $maxProblemNumber))) .
					CGI::Tr({}, CGI::td({}, CGI::a({href => $editProblemLink}, "Edit it"))) .
					CGI::Tr({}, CGI::td({}, CGI::a({href => $viewProblemLink}, "Try it" . ($forOneUser ? " (as $editForUser[0])" : "")))) .
					($forUsers ? "" : CGI::Tr({}, CGI::td({}, CGI::checkbox({name => "deleteProblem", value => $problemID, label => "Delete it?"})))) .
#					CGI::Tr({}, CGI::td({}, "Delete&nbsp;it?" . CGI::input({type => "checkbox", name => "deleteProblem", value => $problemID}))) .
					($forOneUser ? "" : CGI::Tr({}, CGI::td({}, CGI::checkbox({name => "markCorrect", value => $problemID, label => "Mark Correct?"})))) .
				CGI::end_table(),
				$self->FieldTable($userToShow, $setID, $problemID, $GlobalProblems{$problemID}, $UserProblems{$problemID}),
# A comprehensive list of problems is just TOO big to be handled well
#				comboBox({
#					name => "set.$setID.$problemID",
#					request => $r,
#					default => $problemRecord->{problem_id},
#					multiple => 0,
#					values => \@problemFileList,
#				}) .
				
				join ("\n", $self->FieldHTML(
					$userToShow,
					$setID,
					$problemID,
					$GlobalProblems{$problemID}, # pass previously fetched global record to FieldHTML --sam
					$UserProblems{$problemID}, # pass previously fetched user record to FieldHTML --sam
					"source_file"
				)) .
			        	CGI::br() . 
					($error ? 
						CGI::div({class=>"ResultsWithError", style=>"font-weight: bold"}, $error) 
						: CGI::div({class=> "RenderSolo"}, $problem_html[0]->{body_text})
					) .
					($repeatFile ? CGI::div({class=>"ResultsWithError", style=>"font-weight: bold"}, $repeatFile) : ''),
			]));
		}

          
# print final lines
		print CGI::end_table();
		print CGI::checkbox({
				  label=> "Force problems to be numbered consecutively from one (always done when reordering problems)",
				  name=>"force_renumber", value=>"1"}),
			  CGI::br(),
		      CGI::checkbox({
				  label=> "Add blank problem to set",
				  name=>"add_blank_problem", value=>"1"}),

		      CGI::br();
		print CGI::input({type=>"submit", name=>"submit_changes", value=>"Save Changes"});
		print CGI::input({type=>"submit", name=>"handle_numbers", value=>"Reorder problems only"}) . "(Any unsaved changes will be lost.)";
		print CGI::p(<<EOF);
Any time problem numbers are intentionally changed, the problems will
always be renumbered consecutively, starting from one.  When deleting
problems, gaps will be left in the numbering unless the box above is
checked.
EOF
        print CGI::p("It is before the open date.  You probably want to renumber the problems if you are deleting some from the middle.") if ($setRecord->open_date>time());
		print CGI::p("When changing problem numbers, we will move the problem to be ", CGI::em("before"), " the chosen number.");

	} else {
		print CGI::p(CGI::b("This set doesn't contain any problems yet."));
	}
	# always allow one to add a new problem.
	my $editNewProblemPage = $urlpath->new(type => 'instructor_problem_editor_withset_withproblem', args => { courseID => $courseID, setID => $setID, problemID =>'new_problem'    });
    my $editNewProblemLink = $self->systemLink($editNewProblemPage, params => { make_local_copy => 1, file_type => 'blank_problem'  });

	print CGI::p( CGI::a({href=>$editNewProblemLink},'Edit'). ' a new blank problem');

	print CGI::end_form();
	
	return "";
}

1;

=head1 AUTHOR

Written by Robert Van Dam, toenail (at) cif.rochester.edu

=cut
