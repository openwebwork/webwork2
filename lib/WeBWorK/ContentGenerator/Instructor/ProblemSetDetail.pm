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
use WeBWorK::Utils qw(readDirectory list2hash max);
use WeBWorK::DB::Record::Set;
use WeBWorK::Utils::Tasks qw(renderProblems);

# Important Note: the following two sets of constants may seem similar 
# 	but they are functionally and semantically different

# these constants determine which fields belong to what type of record
use constant SET_FIELDS => [qw(set_header hardcopy_header open_date due_date answer_date published)];
use constant PROBLEM_FIELDS =>[qw(source_file value max_attempts)];
use constant USER_PROBLEM_FIELDS => [qw(problem_seed status num_correct num_incorrect)];

# these constants determine what order those fields should be displayed in
use constant HEADER_ORDER => [qw(set_header hardcopy_header)];
use constant PROBLEM_FIELD_ORDER => [qw(problem_seed status value max_attempts attempted last_answer num_correct num_incorrect)];
use constant SET_FIELD_ORDER => [qw(open_date due_date answer_date published)];

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
		size      => "20",
		override  => "any",
	},
	due_date => {
		name      => "Answers Due",
		type      => "edit",
		size      => "20",
		override  => "any",
	},
	answer_date => {
		name      => "Answers Available",
		type      => "edit",
		size      => "20",
		override  => "any",
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
		size      => 5,
		override  => "any",
	},
	max_attempts => {
		name      => "Max&nbsp;attempts",
		type      => "edit",
		size      => 5,
		override  => "any",
		labels    => {
				"-1" => "unlimited",
		},
	},
	problem_seed => {
		name      => "Seed",
		type      => "edit",
		size      => 5,
		override  => "one",
		
	},
	status => {
		name      => "Status",
		type      => "edit",
		size      => 5,
		override  => "any",
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
	my ($self, $userID, $setID, $problemID) = @_;

	my $r = $self->r;	
	my @editForUser = $r->param('editForUser');
	my $forUsers    = scalar(@editForUser);
	my $forOneUser  = $forUsers == 1;

	my @fieldOrder;
	if (defined $problemID) {
		@fieldOrder = @{ PROBLEM_FIELD_ORDER() };
	} else {
		@fieldOrder = @{ SET_FIELD_ORDER() };
	}

	my $output = CGI::start_table({border => 0, cellpadding => 1});
	foreach my $field (@fieldOrder) {
		my %properties = %{ FIELD_PROPERTIES()->{$field} };
		unless ($properties{type} eq "hidden") {
			$output .= CGI::Tr({}, CGI::td({}, [$self->FieldHTML($userID, $setID, $problemID, $field)]));
		}
	} 

	if (defined $problemID) {
		my $problemRecord = $r->{db}->getUserProblem($userID, $setID, $problemID);
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
	my ($self, $userID, $setID, $problemID, $field) = @_;
	
	my $r = $self->r;
	my $db = $r->db;
	my @editForUser = $r->param('editForUser');
	my $forUsers    = scalar(@editForUser);
	my $forOneUser  = $forUsers == 1;

	my ($globalRecord, $userRecord, $mergedRecord);
	if (defined $problemID) { 	
		$globalRecord = $db->getGlobalProblem($setID, $problemID);
		$userRecord = $db->getUserProblem($userID, $setID, $problemID);
		$mergedRecord = $db->getMergedProblem($userID, $setID, $problemID);
	} else {
		$globalRecord = $db->getGlobalSet($setID);
		$userRecord = $db->getUserSet($userID, $setID);
		$mergedRecord = $db->getMergedSet($userID, $setID);
	}
	
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
	$globalValue = $globalValue ? ($labels{$globalValue || ""} || $globalValue) : "";
	my $userValue = $userRecord->{$field};
	$userValue = $userValue ? ($labels{$userValue || ""} || $userValue) : "";

	if ($field =~ /_date/) {
		$globalValue = $self->formatDateTime($globalValue) if $globalValue;
		$userValue = $self->formatDateTime($userValue) if $userValue;
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
				value => $forUsers ? $userValue : $globalValue,
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
				default => $forUsers ? $userRecord->$field : $globalRecord->$field,
		});
	}
	
	return (($forUsers && $edit && $check) ? CGI::checkbox({
				type => "checkbox",
				name => "$recordType.$recordID.$field.override",
				label => "",
				value => $field,
				checked => ($userValue ne "" ? 1 : 0),
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


	my @problemList = $db->listGlobalProblems($setID);
	my %properties = %{ FIELD_PROPERTIES() };

	# takes a hash of hashes and inverts it
	my %undoLabels;
	foreach my $key (keys %properties) {
		%{ $undoLabels{$key} } = map { $properties{$key}->{labels}->{$_} => $_ } keys %{ $properties{$key}->{labels} };
	}


	if (defined $r->param('submit_changes')) {
	
		my $setRecord = $db->getGlobalSet($setID);

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
						$param = $properties{$field}->{default} unless defined $param && $param ne "";
						$param = $undoLabels{$field}->{$param} || $param;
						if ($field =~ /_date/) {
							$param = $self->parseDateTime($param);
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
				$param = $properties{$field}->{default} unless defined $param && $param ne "";
				$param = $undoLabels{$field}->{$param} || $param;
				if ($field =~ /_date/) {
					$param = $self->parseDateTime($param);
				}
				$setRecord->$field($param);
			}
			$db->putGlobalSet($setRecord);
		}


		#####################################################################
		# Save problem information
		#####################################################################

		my @problemIDs = $db->listGlobalProblems($setID);
		my @problemList = $db->getGlobalProblems(map { [$setID, $_] } @problemIDs);
		foreach my $problemRecord (@problemList) {
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
							$param = $properties{$field}->{default} unless defined $param && $param ne "";
							$param = $undoLabels{$field}->{$param} || $param;
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
						$param = $properties{$field}->{default} unless defined $param && $param ne "";
						$param = $undoLabels{$field}->{$param} || $param;
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
					$param = $properties{$field}->{default} unless defined $param && $param ne "";
					$param = $undoLabels{$field}->{$param} || $param;
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
						my $copy = $record;
						my $changed = 0; # keep track of any changes, if none are made, avoid unnecessary db accesses
						foreach my $field ( @{ USER_PROBLEM_FIELDS() } ) {
							next unless canChange($forUsers, $field);
							next unless $useful{$field};
	
							my $param = $r->param("problem.$problemID.$field");
							$param = $properties{$field}->{default} unless defined $param && $param ne "";
							$param = $undoLabels{$field}->{$param} || $param;
							$changed ||= changed($record->$field, $param);
							$record->$field($param);
						}
						$db->putUserProblem($record) if $changed;
					}
				}
			}
		}

		# Delete all problems marked for deletion
		foreach my $problemID ($r->param('deleteProblem')) {
			$db->deleteGlobalProblem($setID, $problemID);
		}
		
		# "Deleting" a header means setting it to "" so that the default header is used instead.
		foreach my $header ($r->param('deleteHeader')) {
			$setRecord->$header("");
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
	}
	

	# handle renumbering of problems if necessary
 	print CGI::a({name=>"problems"});
	
	my %newProblemNumbers = ();
	my $maxProblemNumber = -1;
	for my $jj (@problemList) {
		$newProblemNumbers{$jj} = $r->param('problem_num_' . $jj);
		$maxProblemNumber = $jj if $jj > $maxProblemNumber;
	}

	my $forceRenumber = $r->param('force_renumber') || 0;
	handle_problem_numbers(\%newProblemNumbers, $maxProblemNumber, $db, $setID, $forceRenumber);
	$self->{maxProblemNumber} = $maxProblemNumber;
}

# helper method for debugging
sub debug ($) {
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
	return 0 if not defined $first and not defined $second;
	return "ne" if $first ne $second;
	return 0;	# if they're equal, there's no change
}

# helper method that determines if a given 
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
	return 0 if $howManyCan eq "all" && $forUsers;
	return 0;	# FIXME: maybe it should default to 1?
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
	my $courseName  = $urlpath->arg("courseID");
	my $setName     = $urlpath->arg("setID");
	my $setRecord   = $db->getGlobalSet($setName); 
		die "Global set $setName not found." unless $setRecord;
	my @editForUser = $r->param('editForUser');

	# some useful booleans
	my $forUsers    = scalar(@editForUser);
	my $forOneUser  = $forUsers == 1;

	# If you're editing for users, initially they're records will be different but
	# if you make any changes to them they will be the same.
	# if you're editing for one user, the problems shown should be his/hers
	my $userToShow = $forUsers ? $editForUser[0] : $userID;

	# Check permissions
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($r->param("user"), "access_instructor_tools");
	
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to modify problems.")
		unless $authz->hasPermissions($r->param("user"), "modify_problem_sets");


	my $userCount        = $db->listUsers();
	my $setCount         = $db->listGlobalSets() if $forOneUser;
	my $setUserCount     = $db->countSetUsers($setName);
	my $userSetCount     = $db->countUserSets($editForUser[0]) if $forOneUser;
	my $editUsersAssignedToSetURL = $self->systemLink(
	      $urlpath->newFromModule(
                "WeBWorK::ContentGenerator::Instructor::UsersAssignedToSet",
                  courseID => $courseName, setID => $setName));
	my $editSetsAssignedToUserURL = $self->systemLink(
	      $urlpath->newFromModule(
                "WeBWorK::ContentGenerator::Instructor::SetsAssignedToUser",
                  courseID => $courseName, userID => $editForUser[0])) if $forOneUser;


	my $setDetailPage  = $urlpath -> newFromModule($urlpath->module, courseID => $courseName, setID => $setName);
	my $setDetailURL   = $self->systemLink($setDetailPage,authen=>0);


	my $userCountMessage = CGI::a({href=>$editUsersAssignedToSetURL}, $self->userCountMessage($setUserCount, $userCount));
	my $setCountMessage = CGI::a({href=>$editSetsAssignedToUserURL}, $self->setCountMessage($userSetCount, $setCount)) if $forOneUser;

	$userCountMessage = "The set $setName is assigned to " . $userCountMessage . ".";
	$setCountMessage  = "The user $editForUser[0] has been assigned " . $setCountMessage . "." if $forOneUser;

	if ($forUsers) {
		print CGI::p("$userCountMessage  Editing user-specific overrides for ". CGI::b(join ", ", @editForUser));
		if ($forOneUser) {
			print CGI::p($setCountMessage);
		}
	} else {
		print CGI::p($userCountMessage);
	}
	
	

	my %properties = %{ FIELD_PROPERTIES() };

	my %display_modes = %{WeBWorK::PG::DISPLAY_MODES()};
	my @active_modes = grep { exists $display_modes{$_} } @{$r->ce->{pg}->{displayModes}};
	push @active_modes, 'None';
	my $default_header_mode = $r->param('header.displaymode') || 'None';
	my $default_problem_mode = $r->param('problem.displaymode') || 'None';


	# Display a useful warning message
	if ($forUsers) {
		print CGI::p(CGI::b("Any changes made below will be reflected in the set for ONLY the student" . 
					($forOneUser ? "" : "s") . " listed above."));
	} else {
		print CGI::p(CGI::b("Any changes made below will be reflected in the set for ALL students."));
	}

	print CGI::start_form({method=>"POST", action=>$setDetailURL});
	print CGI::input({type=>"submit", name=>"submit_changes", value=>"Save Changes"});
	
	# spacing
	print CGI::p();
	
	#####################################################################
	# Display general set information
	#####################################################################

	print CGI::start_table({border=>1, cellpadding=>4});
	print CGI::Tr({}, CGI::th({}, [
		"General Information",
	]));

	print CGI::Tr({}, CGI::td({}, [
		$self->FieldTable($userToShow, $setName),
	]));
	print CGI::end_table();	

	# spacing
	print CGI::p();

	
	#####################################################################
	# Display header information
	#####################################################################
	my @headers = @{ HEADER_ORDER() };
	my %headerModules = (set_header => 'problem_list', 'hardcopy_header' => 'hardcopy_preselect_set');
	my @headerFiles = map { $setRecord->{$_} } @headers;
	if (scalar @headers and not $forUsers) {

		print CGI::start_table({border=>1, cellpadding=>4});
		print CGI::Tr({}, CGI::th({}, [
			"Headers",
#			"Data",
			"Display&nbsp;Mode:&nbsp;" . 
			CGI::popup_menu(-name => "header.displaymode", -values => \@active_modes, -default => $default_header_mode) . '&nbsp;'. 
			CGI::input({type => "submit", name => "refresh", value => "Refresh"}),
		]));

		my %header_html;
		
		foreach my $header (@headers) {
			my @temp = renderProblems(	r=> $r, 
							user => $db->getUser($userToShow),
							displayMode=> $default_header_mode,
							problem_number=> 0,
							this_set => $db->getMergedSet($userToShow, $setName),
							problem_list => [$setRecord->{$header}],
			);
			$header_html{$header} = $temp[0];
		}
		
		foreach my $header (@headers) {
	
			my $editHeaderPage = $urlpath->new(type => 'instructor_problem_editor_withset_withproblem', args => { courseID => $courseName, setID => $setName, problemID => 0 });
			my $editHeaderLink = $self->systemLink($editHeaderPage, params => { file_type => $header, make_local_copy => 1 });
		
			my $viewHeaderPage = $urlpath->new(type => $headerModules{$header}, args => { courseID => $courseName, setID => $setName });
			my $viewHeaderLink = $self->systemLink($viewHeaderPage);
			
			print CGI::Tr({}, CGI::td({}, [
				CGI::start_table({border => 0, cellpadding => 0}) . 
					CGI::Tr({}, CGI::td({}, $properties{$header}->{name})) . 
					CGI::Tr({}, CGI::td({}, CGI::a({href => $editHeaderLink}, "Edit it"))) .
					CGI::Tr({}, CGI::td({}, CGI::a({href => $viewHeaderLink}, "View it"))) .
					CGI::Tr({}, CGI::td({}, CGI::checkbox({name => "defaultHeader", value => $header, label => "Use Default"}))) .
				CGI::end_table(),
#				"",
				CGI::input({ name => "set.$setName.$header", value => $setRecord->{$header}, size => 50}) .
			        CGI::div({class=> "RenderSolo"}, $header_html{$header}->{body_text}),
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

	my @problemList = $db->listGlobalProblems($setName);
	if (scalar @problemList) {

		my $maxProblemNumber = $self->{maxProblemNumber};

		print CGI::start_table({border=>1, cellpadding=>4});
		print CGI::Tr({}, CGI::th({}, [
			"Problems",
			"Data",
			"Display&nbsp;Mode:&nbsp;" . 
			CGI::popup_menu(-name => "problem.displaymode", -values => \@active_modes, -default => $default_problem_mode) . '&nbsp;'. 
			CGI::input({type => "submit", name => "refresh", value => "Refresh"}),
		]));
		
		foreach my $problem (@problemList) {
		
			my $problemRecord;
			if ($forOneUser) {
				$problemRecord = $db->getMergedProblem($editForUser[0], $setName, $problem);
			} else {
				$problemRecord = $db->getGlobalProblem($setName, $problem);
			}
			
			my $editProblemPage = $urlpath->new(type => 'instructor_problem_editor_withset_withproblem', args => { courseID => $courseName, setID => $setName, problemID => $problem });
			my $editProblemLink = $self->systemLink($editProblemPage, params => { file_type => $problem, make_local_copy => 0 });

			# FIXME: should we have an "act as" type link here when editing for multiple users?		
			my $viewProblemPage = $urlpath->new(type => 'problem_detail', args => { courseID => $courseName, setID => $setName });
			my $viewProblemLink = $self->systemLink($viewProblemPage, params => { effectiveUser => ($forOneUser ? $editForUser[0] : $userID)});

			my @fields = @{ PROBLEM_FIELDS() };
			push @fields, @{ USER_PROBLEM_FIELDS() } if $forOneUser;

			my @problem_html = renderProblems(	r=> $r, 
								user => $db->getUser($userToShow),
								displayMode=> $default_problem_mode,
								problem_number=> $problem,
								this_set => $db->getMergedSet($userToShow, $setName),
								problem_seed => $forOneUser ? $problemRecord->problem_seed : 0,
								problem_list => [$problemRecord->source_file],
			);

			print CGI::Tr({}, CGI::td({}, [
				CGI::start_table({border => 0, cellpadding => 1}) .
					CGI::Tr({}, CGI::td({}, problem_number_popup($problem, $maxProblemNumber))) .
					CGI::Tr({}, CGI::td({}, CGI::a({href => $editProblemLink}, "Edit it"))) .
					CGI::Tr({}, CGI::td({}, CGI::a({href => $viewProblemLink}, "Try it" . ($forOneUser ? " (as $editForUser[0])" : "")))) .
					($forUsers ? "" : CGI::Tr({}, CGI::td({}, CGI::checkbox({name => "deleteProblem", value => $problem, label => "Delete it?"})))) .
#					CGI::Tr({}, CGI::td({}, "Delete&nbsp;it?" . CGI::input({type => "checkbox", name => "deleteProblem", value => $problem}))) .
				CGI::end_table(),
				$self->FieldTable($userToShow, $setName, $problem),
				join ("\n", $self->FieldHTML($userToShow, $setName, $problem, "source_file")) .
			        	CGI::br() . CGI::div({class=> "RenderSolo"}, $problem_html[0]->{body_text}),
			]));
		}

		print CGI::end_table();
		print $self->hiddenEditForUserFields(@editForUser);
		print $self->hidden_authen_fields;
		print CGI::checkbox({
				  label=> "Force problems to be numbered consecutively from one",
				  name=>"force_renumber", value=>"1"}),

		  CGI::br();
		print CGI::input({type=>"submit", name=>"submit_changes", value=>"Save Changes"});
		print CGI::p(<<HERE);
Any time problem numbers are intentionally changed, the problems will
always be renumbered consecutively, starting from one.  When deleting
problems, gaps will be left in the numbering unless the box above is
checked.
HERE
                print CGI::p("It is before the open date.  You probably want to renumber the problems if you are deleting some from the middle.") if ($setRecord->open_date>time());
		print CGI::p("When changing problem numbers, we will move 
 the problem to be ", CGI::em("before"), " the chosen number.");

	} else {
		print CGI::p(CGI::b("This set doesn't contain any problems yet."));
	}

	print CGI::end_form();
	
	return "";
}

1;

=head1 AUTHOR

Written by Robert Van Dam, toenail (at) cif.rochester.edu

=cut
