
################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
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

package WeBWorK::ContentGenerator::Instructor::ProblemSetDetail2;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetDetail - Edit general set and specific user/set information as well as problem information

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::HTML::ComboBox qw/comboBox/;
use WeBWorK::Utils qw(after readDirectory list2hash sortByName listFilesRecursive max cryptPassword jitar_id_to_seq seq_to_jitar_id x);
use WeBWorK::Utils::Tasks qw(renderProblems);
use WeBWorK::Debug;
# IP RESTRICT
use WeBWorK::HTML::ScrollingRecordList qw/scrollingRecordList/;
use WeBWorK::Utils::DatePickerScripts;

# Important Note: the following two sets of constants may seem similar 
# 	but they are functionally and semantically different

# these constants determine which fields belong to what type of record
use constant SET_FIELDS => [qw(set_header hardcopy_header open_date reduced_scoring_date due_date answer_date visible description enable_reduced_scoring  restricted_release restricted_status restrict_ip relax_restrict_ip assignment_type attempts_per_version version_time_limit time_limit_cap versions_per_interval time_interval problem_randorder problems_per_page hide_score:hide_score_by_problem hide_work hide_hint restrict_prob_progression email_instructor)];
use constant PROBLEM_FIELDS =>[qw(source_file value max_attempts showMeAnother prPeriod att_to_open_children counts_parent_grade)];
use constant USER_PROBLEM_FIELDS => [qw(problem_seed status num_correct num_incorrect)];

# these constants determine what order those fields should be displayed in
use constant HEADER_ORDER => [qw(set_header hardcopy_header)];
use constant PROBLEM_FIELD_ORDER => [qw(problem_seed status value max_attempts showMeAnother prPeriod attempted last_answer num_correct num_incorrect)];
# for gateway sets, we don't want to allow users to change max_attempts on a per
#    problem basis, as that's nothing but confusing.
use constant GATEWAY_PROBLEM_FIELD_ORDER => [qw(problem_seed status value attempted last_answer num_correct num_incorrect)];
use constant JITAR_PROBLEM_FIELD_ORDER => [qw(problem_seed status value max_attempts showMeAnother prPeriod att_to_open_children counts_parent_grade attempted last_answer num_correct num_incorrect)];


# we exclude the gateway set fields from the set field order, because they
#     are only displayed for sets that are gateways.  this results in a bit of
#     convoluted logic below, but it saves burdening people who are only using
#     homework assignments with all of the gateway parameters
# FIXME: in the long run, we may want to let hide_score and hide_work be
# FIXME: set for non-gateway assignments.  right now (11/30/06) they are
# FIXME: only used for gateways
use constant SET_FIELD_ORDER => [qw(open_date reduced_scoring_date due_date answer_date visible enable_reduced_scoring restricted_release restricted_status restrict_ip relax_restrict_ip hide_hint assignment_type)];
# use constant GATEWAY_SET_FIELD_ORDER => [qw(attempts_per_version version_time_limit time_interval versions_per_interval problem_randorder problems_per_page hide_score hide_work)];
use constant GATEWAY_SET_FIELD_ORDER => [qw(version_time_limit time_limit_cap attempts_per_version time_interval versions_per_interval problem_randorder problems_per_page hide_score:hide_score_by_problem hide_work)];
use constant JITAR_SET_FIELD_ORDER => [qw(restrict_prob_progression email_instructor)];

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
#               convertby => 60,                # divide incoming database field values by this, and multiply when saving

use constant BLANKPROBLEM => 'blankProblem.pg';

# We use the x function to mark strings for localizaton 
use constant FIELD_PROPERTIES => {
	# Set information
	set_header => {
		name      => x("Set Header"),
		type      => "edit",
		size      => "50",
		override  => "all",
		module    => "problem_list",
		default   => "",
	},
	hardcopy_header => {
		name      => x("Hardcopy Header"),
		type      => "edit",
		size      => "50",
		override  => "all",
		module    => "hardcopy_preselect_set",
		default   => "",		
	},
	description => {
		name      => x("Description"),
		type      => "edit",
		override  => "all",
		default   => "",
	},
	open_date => {
		name      => x("Opens"),
		type      => "edit",
		size      => "25",
		override  => "any",
		labels    => {
				#0 => "None Specified",
				"" => x("None Specified"),
		},
	},
	due_date => {
		name      => x("Closes"),
		type      => "edit",
		size      => "25",
		override  => "any",
		labels    => {
				#0 => "None Specified",
				"" => x("None Specified"),
		},
	},
	answer_date => {
		name      => x("Answers Available"),
		type      => "edit",
		size      => "25",
		override  => "any",
		labels    => {
				#0 => "None Specified",
				"" => x("None Specified"),
		},
	},
	visible => {
		name      => x("Visible to Students"),
		type      => "choose",
		override  => "all",
		choices   => [qw( 0 1 )],
		labels    => {
				1 => x("Yes"),
				0 => x("No"),
		},
	},
	enable_reduced_scoring => {
		name      => x("Reduced Scoring Enabled"),
		type      => "choose",
		override  => "any",
		choices   => [qw( 0 1 )],
		labels    => {
				1 => x("Yes"),
				0 => x("No"),
		},
	},
	reduced_scoring_date => {
		name      => x("Reduced Scoring Date"),
		type      => "edit",
		size      => "25",
		override  => "any",
		labels    => {
				#0 => "None Specified",
				"" => x("None Specified"),
		},
	},
	restricted_release => {
		name      => x("Restrict release by set(s)"),
		type      => "edit",
		size      => "30",
		override  => "any",
		labels    => {
				#0 => "None Specified",
				"" => x("None Specified"),
		},
                help_text => x("This set will be unavailable to students until they have earned a certain score on the sets specified in this field.  The sets should be written as a comma separated list.  The minimum score required on the sets is specified in the following field.")
	},
	restricted_status => {
		name      => x("Score required for release"),
		type      => "choose",
		override  => "any",
		choices   => [qw( 1 0.9 0.8 0.7 0.6 0.5 0.4 0.3 0.2 0.1 )],
		labels    => {	'0.1' => '10%',
				'0.2' => '20%',
				'0.3' => '30%',
				'0.4' => '40%',
				'0.5' => '50%',
				'0.6' => '60%',
				'0.7' => '70%',
				'0.8' => '80%',
				'0.9' => '90%',
				'1' => '100%',
		},
	},
	restrict_ip => {
		name      => x("Restrict Access by IP"),
		type      => "choose",
		override  => "any",
		choices   => [qw( No RestrictTo DenyFrom )],
		labels    => {
				No => x("No"),
				RestrictTo => x("Restrict To"),
				DenyFrom => x("Deny From"),
		},
		default   => 'No',
	},
	relax_restrict_ip => { 
		name      => x("Relax IP restrictions when?"),
		type      => "choose",
		override  => "any",
		choices   => [qw( No AfterAnswerDate AfterVersionAnswerDate )],
		labels    => {
				No => x("Never"),
				AfterAnswerDate => x("After set answer date"),
				AfterVersionAnswerDate => x("(gw/quiz) After version answer date"),
		},
		default   => 'No',
	},
	assignment_type => {
		name      => x("Assignment type"),
		type      => "choose",
		override  => "all",
		choices   => [qw( default gateway proctored_gateway jitar)],
		labels    => {	default => "homework",
				gateway => "gateway/quiz",
				proctored_gateway => "proctored gateway/quiz",
				jitar => "just-in-time"
		},
	},
	version_time_limit => {
		name      => x("Test Time Limit (min; 0=Close Date)"),
		type      => "edit",
		size      => "4",
		override  => "any",
		default => "0",
#		labels    => {	"" => 0 },  # I'm not sure this is quite right
		convertby => 60,
	},
	time_limit_cap => {
		name      => x("Cap Test Time at Set Close Date?"),
		type      => "choose",
		override  => "all",
		choices   => [qw(0 1)],
		labels    => { '0' => 'No', '1' =>'Yes' },
	},
	attempts_per_version => {
		name      => x("Number of Graded Submissions per Test (0=infty)"),
		type      => "edit",
		size      => "3",
		override  => "any",
		default => "0",
#		labels    => {	"" => 1 },
	},
	time_interval => {
		name      => x("Time Interval for New Test Versions (min; 0=infty)"),
		type      => "edit",
                size      => "5",
		override  => "any",
		default => "0",
#		labels    => {	"" => 0 },
		convertby => 60,
	},
	versions_per_interval => {
		name      => x("Number of Tests per Time Interval (0=infty)"),
		type      => "edit",
                size      => "3",
		override  => "any",
		default   => "0",
		format    => '[0-9]+',      # an integer, possibly zero
#		labels    => {	"" => 0 },
#		labels    => {	"" => 1 },
	},
	problem_randorder => {
		name      => x("Order Problems Randomly"),
		type      => "choose",
		choices   => [qw( 0 1 )],
		override  => "any",
		labels    => {	0 => "No", 1 =>"Yes" },
	},
	problems_per_page => {
	        name      => x("Number of Problems per Page (0=all)"),
		type      => "edit",
		size      => "3",
		override  => "any",
		default   => "0",
#		labels    => { "" => 0 },
	},
	'hide_score:hide_score_by_problem' => {
		name      => x("Show Scores on Finished Assignments?"),
		type      => "choose",
		choices   => [ qw( N:N Y:Y BeforeAnswerDate:N N:Y BeforeAnswerDate:Y ) ],
		override  => "any",
		labels    => { 'N:N' => 'Yes', 'Y:Y' => 'No', 'BeforeAnswerDate:N' => x('Only after set answer date'), 'N:Y' => x('Totals only (not problem scores)'), 'BeforeAnswerDate:Y' => x('Totals only, only after answer date') },
	},
	hide_work         => {
		name      => x("Show Problems on Finished Tests"),
		type      => "choose",
		choices   => [ qw(N Y BeforeAnswerDate) ],
		override  => "any",
		labels    => { 'N' => "Yes", 'Y' =>"No", 'BeforeAnswerDate' =>x('Only after set answer date') },
	},

	restrict_prob_progression => {
		name      => x("Restrict Problem Progression"),
		type      => "choose",
		choices   => [ qw(0 1) ],
		override  => "all",
                default   => "0",
		labels    => { '1' => "Yes", '0' =>"No", },
                help_text => x("If this is enabled then students will be unable to attempt a problem until they have completed all of the previous problems, and their child problems if necessary."),
	},

	email_instructor  => {
		name      => x("Email Instructor On Failed Attempt"),
		type      => "choose",
		choices   => [ qw(0 1) ],
		override  => "any",
                default   => "0",
		labels    => { '1' => "Yes", '0' =>"No"},
                help_text => x("If this is enabled then instructors with the ability to receive feedback emails will be notified whenever a student runs out of attempts on a problem and its children without receiving an adjusted status of 100%."),
	},

	# in addition to the set fields above, there are a number of things
	#    that are set but aren't in this table:
	#    any set proctor information (which is in the user tables), and
	#    any set location restriction information (which is in the 
	#    location tables)
	#
	# Problem information
	source_file => {
		name      => x("Source File"),
		type      => "edit",
		size      => 50,
		override  => "any",
		default   => "",
	},
	value => {
		name      => x("Weight"),
		type      => "edit",
		size      => 6,
		override  => "any",
                default => "1",
	},
	max_attempts => {
		name      => x("Max attempts"),
		type      => "edit",
		size      => 6,
		override  => "any",
                default => "-1",
		labels    => {
				"-1" => x("unlimited"),
		},
	},
        showMeAnother => {
                 name => x("Show me another"),
                 type => "edit",
                 size => "6",
                 override  => "any",
                 default=>"-1",
                 labels    => {
			       "-1" => x("Never"),
			       "-2" => x("Default"),
                 },
                 help_text => x("When a student has more attempts than is specified here they will be able to view another version of this problem.  If set to -1 the feature is disabled and if set to -2 the course default is used.")
        },
	prPeriod => {
		name => x("Rerandomize after"),
		type => "edit",
		size => "6",
		override => "any",
		default=>"-1",
		labels => {
			"-1" => x("Default"),
			"0" => x("Never"),
		},
		help_text => x("This specifies the rerandomization period: the number of attempts before a new version of the problem is generated by changing the Seed value. The value of -1 uses the default from course configuration. The value of 0 disables rerandomization."),
	},
	problem_seed => {
		name      => x("Seed"),
		type      => "edit",
		size      => 6,
		override  => "one",
		
	},
	status => {
		name      => x("Status"),
		type      => "edit",
		size      => 6,
		override  => "one",
		default   => "0",
	},
	attempted => {
		name      => x("Attempted"),
		type      => "hidden",
		override  => "none",
		choices   => [qw( 0 1 )],
		labels    => {
				1 => x("Yes"),
				0 => x("No"),
		},
		default   => "0",
	},
	last_answer => {
		name      => x("Last Answer"),
		type      => "hidden",
		override  => "none",
	},
	num_correct => {
		name      => x("Correct"),
		type      => "hidden",
		override  => "none",
		default   => "0",
	},
	num_incorrect => {
		name      => x("Incorrect"),
		type      => "hidden",
		override  => "none",
		default   => "0",
	},
	hide_hint => {
		name      => x("Hide Hints from Students"),
		type      => "choose",
		override  => "all",
		choices   => [qw( 0 1 )],
		labels    => {
				1 => x("Yes"),
				0 => x("No"),
		},
	},
	att_to_open_children  => {
		name      => x("Att. to Open Children"),
		type      => "edit",
		size      => 6,
		override  => "any",
                default => "0",
		labels    => {
				"-1" => x("max"),
		},
                help_text => x("The child problems for this problem will become visible to the student when they either have more incorrect attempts than is specified here, or when they run out of attempts, whichever comes first.  If \"max\" is specified here then child problems will only be available after a student runs out of attempts."),
	},
	counts_parent_grade  => {
		name      => x("Counts for Parent"),
		type      => "choose",
		choices   => [ qw(0 1) ],
		override  => "any",
                default   => "0",
		labels    => { '1' => "Yes", '0' =>"No", },
                help_text => x("If this flag is set then this problem will count towards the grade of its parent problem.  In general the adjusted status on a problem is the larger of the problem's status and the weighted average of the status of its child problems which have this flag enabled."),
	},


	
};

use constant FIELD_PROPERTIES_GWQUIZ => {
	max_attempts => {
		type	=> "hidden",
		override=> "any",
	}
};

# Create a table of fields for the given parameters, one row for each db field
# if only the setID is included, it creates a table of set information
# if the problemID is included, it creates a table of problem information
sub FieldTable {
	my ($self, $userID, $setID, $problemID, $globalRecord, $userRecord, $setType) = @_;

	my $r = $self->r;	
	my $ce = $r->ce;
	my @editForUser = $r->param('editForUser');
	my $forUsers    = scalar(@editForUser);
	my $forOneUser  = $forUsers == 1;
	my $isGWset = 0;
	my @fieldOrder;

	# needed for gateway/jitar output
	my $extraFields = '';
	# $isGWset will come in undef if we don't need to worry about it
	$isGWset = 0 if ( ! defined( $isGWset ) );
	if (defined $setType && $setType =~ /gateway/) {
	    $isGWset = 1;
	}

	# are we editing a set version?
	my $setVersion = (defined($userRecord) && $userRecord->can("version_id")) ? 1 : 0;

	# needed for ip restrictions
	my $ipFields = '';
	my $ipDefaults;
	my $numLocations = 0;
	my $ipOverride;

	# needed for set-level proctor
	my $procFields = '';


	if (defined $problemID) {
	 
	    if ($setType eq 'jitar') {
		@fieldOrder = @{ JITAR_PROBLEM_FIELD_ORDER() };
	    } elsif ($setType =~ /gateway/) {
		@fieldOrder = @{ GATEWAY_PROBLEM_FIELD_ORDER() };
	    } else {
		@fieldOrder = @{ PROBLEM_FIELD_ORDER() };
	    }
	} else {
		@fieldOrder = @{ SET_FIELD_ORDER() };

		($extraFields, $ipFields, $numLocations, $procFields) = $self->extraSetFields($userID, $setID, $globalRecord, $userRecord, $forUsers);
	}

       	my $output = CGI::start_table({border => 0, cellpadding => 1});
	if ($forUsers) {
		$output .= CGI::Tr({},
		    CGI::th({colspan=>"2"}, "&nbsp;"),
			CGI::th({colspan=>"1"}, $r->maketext("User Values")),
			CGI::th({}, $r->maketext("Class values")),
		);
	}
	foreach my $field (@fieldOrder) {
		my %properties; 
		
		
		if($isGWset && defined( FIELD_PROPERTIES_GWQUIZ->{$field} )){
		    %properties = %{ FIELD_PROPERTIES_GWQUIZ->{$field} };
		}
		else{
		    %properties = %{ FIELD_PROPERTIES()->{$field} };
		}

		#Don't show fields if that option isn't enabled.  
		if (!$ce->{options}{enableConditionalRelease} && 
		    ($field eq 'restricted_release' || $field eq 'restricted_status')) {
			$properties{'type'} = 'hidden';
		    }
		
		if (!$ce->{pg}{ansEvalDefaults}{enableReducedScoring} &&
		    ($field eq 'reduced_scoring_date' || $field eq 'enable_reduced_scoring')) {
			$properties{'type'} = 'hidden';
		} elsif ($ce->{pg}{ansEvalDefaults}{enableReducedScoring} &&
		    $field eq 'reduced_scoring_date' && !$globalRecord->reduced_scoring_date) {
		    $globalRecord->reduced_scoring_date($globalRecord->due_date -
			60*$ce->{pg}{ansEvalDefaults}{reducedScoringPeriod});
		}

		# we don't show the ip restriction option if there are 
		#    no defined locations, nor the relax_restrict_ip option
		#    if we're not restricting ip access
		next if ( $field eq 'restrict_ip' && ( ! $numLocations || $setVersion ) );
		next if ($field eq 'relax_restrict_ip' &&
			 (! $numLocations || $setVersion ||
			  ($forUsers && $userRecord->restrict_ip eq 'No') ||
			  (! $forUsers && 
			   ( $globalRecord->restrict_ip eq '' ||
			     $globalRecord->restrict_ip eq 'No' ) ) ) );
		# skip the problem seed if we're editing a gateway set for users,
		#    but aren't editing a set version
		next if ( $field eq 'problem_seed'  &&
			  ( $isGWset && $forUsers && ! $setVersion ) );

		# skip the Show Me Another value if SMA is not enabled
		next if ( $field eq 'showMeAnother' &&
			  !$ce->{pg}->{options}->{enableShowMeAnother} );

		# skip the periodic re-randomization field if it is not enabled
		next if ( $field eq 'prPeriod' &&
			!$ce->{pg}->{options}->{enablePeriodicRandomization} );

		unless ($properties{type} eq "hidden") {
			$output .= CGI::Tr({}, CGI::td({}, [$self->FieldHTML($userID, $setID, $problemID, $globalRecord, $userRecord, $field)])) . "\n";
		}

		# finally, put in extra fields that are exceptions to the 
		#    usual display mechanism
		if ( $field eq 'restrict_ip' && $ipFields ) {
			$output .= $ipFields;
		}
					      
		if ( $field eq 'assignment_type' ) {
		    $output .= "$procFields\n$extraFields\n";
		}
	} 

	if (defined $problemID) {
		#my $problemRecord = $r->{db}->getUserProblem($userID, $setID, $problemID);
		my $problemRecord = $userRecord; # we get this from the caller, hopefully
		$output .= CGI::Tr({}, CGI::td({}, ["",$r->maketext("Attempts"), ($problemRecord->num_correct || 0) + ($problemRecord->num_incorrect || 0)])) if $forOneUser;
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
	
	return $r->maketext("No data exists for set [_1] and problem [_2]", $setID, $problemID) unless $globalRecord;
	return $r->maketext("No user specific data exists for user [_1]", $userID) if $forOneUser and $globalRecord and not $userRecord;
	
	my %properties = %{ FIELD_PROPERTIES()->{$field} };
	my %labels = %{ $properties{labels} };

	foreach my $key (keys %labels) {
	  $labels{$key} = $r->maketext($labels{$key});
	}

	return "" if $properties{type} eq "hidden";
	return "" if $properties{override} eq "one" && not $forOneUser;
	return "" if $properties{override} eq "none" && not $forOneUser;
	return "" if $properties{override} eq "all" && $forUsers;
	
	my $edit = ($properties{type} eq "edit") && ($properties{override} ne "none");
	my $choose = ($properties{type} eq "choose") && ($properties{override} ne "none");
	
# FIXME: allow one selector to set multiple fields
#	my $globalValue = $globalRecord->{$field};
# 	my $userValue = $userRecord->{$field};
	my ($globalValue, $userValue) = ('', '');
	my $blankfield = '';
	if ( $field =~ /:/ ) {
		my @gVals = ();
		my @uVals = ();
		my @bVals = ();
		foreach my $f ( split(/:/, $field) ) {
			# hmm.  this directly references the data in the 
			#    record rather than calling the access method, 
			#    thereby avoiding errors if the userRecord is 
			#    undefined.  that seems a bit suspect, but it's
			#    used below so we'll leave it here.

			push(@gVals, $globalRecord->{$f} );
			push(@uVals, $userRecord->{$f} );    # (defined($userRecord->{$f})?$userRecord->{$f}:'') );
			push(@bVals, '');
		}
		# I don't like this, but combining multiple values is a bit messy
		$globalValue = (grep {defined($_)} @gVals) ? join(':', (map { defined($_) ? $_ : '' } @gVals )) : undef;
		$userValue = (grep {defined($_)} @uVals) ? join(':', (map { defined($_) ? $_ : '' } @uVals )) : undef;
		$blankfield = join(':', @bVals);
	} else {
		$globalValue = $globalRecord->{$field};
		$userValue = $userRecord->{$field};
	}

	# use defined instead of value in order to allow 0 to printed, e.g. for the 'value' field
	$globalValue = (defined($globalValue)) ? ($labels{$globalValue // ""} || $globalValue) : ""; # this allows for a label if value is 0
	$userValue = (defined($userValue)) ? ($labels{$userValue // ""} || $userValue) : $blankfield; # this allows for a label if value is 0

	if ($field =~ /_date/) {
		$globalValue = $self->formatDateTime($globalValue,'','%m/%d/%Y at %I:%M%P') if defined $globalValue && $globalValue ne $labels{""};
		# this is still fragile, but the check for blank (as opposed to 0) $userValue seems to prevent errors when no user has been assigned.
		$userValue = $self->formatDateTime($userValue,'','%m/%d/%Y at %I:%M%P') if defined $userValue && $userValue =~/\S/ && $userValue ne $labels{""};
	}

	if ( defined($properties{convertby}) && $properties{convertby} ) {
		$globalValue = $globalValue/$properties{convertby} if $globalValue;
		$userValue = $userValue/$properties{convertby} if $userValue;
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

	my $onChange = "";

	# if we are creating override feilds we should add the js to automatically check the
	# override box.
	if ($forUsers && $check) {
	    $onChange = "\$('#$recordType\\\\.$recordID\\\\.$field\\\\.override_id').attr('checked',true)";
	}
	
	if ($edit) {
		$inputType = CGI::font({class=>"visible"}, CGI::input({
		                type => "text",
				name => "$recordType.$recordID.$field",
				id   => "$recordType.$recordID.${field}_id",
				value => $r->param("$recordType.$recordID.$field") || ($forUsers ? $userValue : $globalValue),
				size => $properties{size} || 5,
				onChange => $onChange,
		}));

	} elsif ($choose) {
		# Note that in popup menus, you're almost guaranteed to have the choices hashed to labels in %properties
		# but $userValue and and $globalValue are the values in the hash not the keys
		# so we have to use the actual db record field values to select our default here.

		# FIXME: this allows us to set one selector from two (or more) fields
		# if $field matches /:/, we have to get two fields to get the data we need here
		my $value = $r->param("$recordType.$recordID.$field");
		if ( ! $value && $field =~ /:/ ) { 
			my @fields = split(/:/, $field);
			$value = '';
			foreach my $f ( @fields ) {
				$value .= ($forUsers && $userRecord->$f ne '' ? $userRecord->$f : $globalRecord->$f) . ":";
			}
			$value =~ s/:$//;
		} elsif ( ! $value ) {
			$value = ($forUsers && $userRecord->$field ne '' ? $userRecord->$field : $globalRecord->$field);
		}
		
		$inputType = CGI::popup_menu({
				name => "$recordType.$recordID.$field",
				id   => "$recordType.$recordID.${field}_id",
				values => $properties{choices},
				labels => \%labels,
				default => $value,
				onChange => $onChange,
		});
	}
	
	my $gDisplVal = defined($properties{labels}) && defined($properties{labels}->{$globalValue}) ? $r->maketext($properties{labels}->{$globalValue}) : $globalValue;

	# FIXME: adding ":" in the checked => allows for multiple fields to be set by one selector

	return (($forUsers && $check) ? CGI::checkbox({
				type => "checkbox",
				name => "$recordType.$recordID.$field.override",
				id => "$recordType.$recordID.$field.override_id",
				label => "",
				value => $field,
				checked => $r->param("$recordType.$recordID.$field.override") || ($userValue ne ($labels{""} // '') || $blankfield) ? 1 : 0,
		}) : "",
		$r->maketext($properties{name}).
		($properties{help_text} ? "&nbsp;".CGI::a({class=>'help-popup',href=>'#',
						  'data-content'=>$r->maketext($properties{help_text}),'data-placement'=>'top', 'data-toggle'=>'popover'},'&#9072') : ''),
		$inputType,
		$forUsers ? " $gDisplVal" : "",
	);
}

# return weird fields that are non-native or which are displayed
#    for only some sets
sub extraSetFields {
	my ($self,$userID,$setID,$globalRecord,$userRecord,$forUsers) = @_;
	my $db = $self->r->{db};
	my $r = $self->r;

	my ($extraFields, $ipFields, $ipDefaults, $numLocations, $ipOverride,
	    $procFields) = ( '', '', '', 0, '', '' );

	# if we're dealing with a gateway, set up a table of gateway fields
	my $nF = 0;  # this is the number of columns in the set field table
	if ( $globalRecord->assignment_type() =~ /gateway/ ) {
		my $gwhdr = "\n<!-- begin gwoutput table -->\n";
		my $gwFields = '';
		foreach my $gwfield ( @{ GATEWAY_SET_FIELD_ORDER() } ) {

			# don't show template gateway fields when editing
			#    set versions
			next if ( ( $gwfield eq "time_interval" ||
				    $gwfield eq "versions_per_interval" ) &&
				  ( $forUsers &&
				    $userRecord->can('version_id') ) );

			my @fieldData = 
			    ($self->FieldHTML($userID, $setID, undef, 
					      $globalRecord, $userRecord, 
					      $gwfield));
			if ( @fieldData && defined($fieldData[1]) and 
			     $fieldData[1] ne '' ) {
				$nF = @fieldData if ( @fieldData > $nF );
				$gwFields .= CGI::Tr({}, 
					CGI::td({}, [@fieldData]));
		    	}
		}
		$gwhdr .= CGI::Tr({},CGI::td({colspan=>$nF}, 
					     CGI::em($r->maketext("Gateway parameters"))))
		    if ( $nF );
		$extraFields = "$gwhdr$gwFields\n" .
		    "<!-- end gwoutput table -->\n";
		
	} elsif ( $globalRecord->assignment_type() eq 'jitar') {
		my $jthdr = "\n<!-- begin jtoutput table -->\n";
		my $jtFields = '';
		foreach my $jtfield ( @{ JITAR_SET_FIELD_ORDER() } ) {
			my @fieldData = 
			    ($self->FieldHTML($userID, $setID, undef, 
					      $globalRecord, $userRecord, 
					      $jtfield));
			if ( @fieldData && defined($fieldData[1]) and 
			     $fieldData[1] ne '' ) {
				$nF = @fieldData if ( @fieldData > $nF );
				$jtFields .= CGI::Tr({}, 
					CGI::td({}, [@fieldData]));
		    	}
		}
		$jthdr .= CGI::Tr({},CGI::td({colspan=>$nF}, 
					     CGI::em($r->maketext("Just-In-Time parameters"))))
		    if ( $nF );
		$extraFields = "$jthdr$jtFields\n" .
			"<!-- end gwoutput table -->\n";
	}

	# if we have a proctored test, then also generate a proctored 
	#    set password input 
	if ( $globalRecord->assignment_type eq 'proctored_gateway' && ! $forUsers ) {
		my $nfm1 = $nF - 1;
		$procFields = CGI::Tr({},CGI::td({},''),
			CGI::td({colspan=>$nfm1},
				CGI::em($r->maketext("Proctored tests require proctor authorization to start and to grade.  Provide a password to have a single password for all students to start a proctored test."))));
		# we use a routine other than FieldHTML because of getting
		#    the default value here
		my @fieldData = 
			$self->proctoredFieldHTML($userID, $setID, 
						  $globalRecord);
		$procFields .= CGI::Tr({}, 
			CGI::td({}, [@fieldData]));
	}

	# finally, figure out what ip selector fields we want to include
	my @locations = sort {$a cmp $b} ($db->listLocations());
	$numLocations = @locations;

	# we don't show ip selector fields if we're editing a set version
	if ( ! defined( $userRecord ) ||
	     ( defined( $userRecord ) && ! $userRecord->can("version_id") ) ) {
		if ( ( ! $forUsers && $globalRecord->restrict_ip &&
		       $globalRecord->restrict_ip ne 'No' ) ||
		     ( $forUsers && $userRecord->restrict_ip ne 'No' ) ) {

			my @globalLocations = $db->listGlobalSetLocations($setID);
			# what ip locations should be selected?
			my @defaultLocations = ();
			if ( $forUsers && 
			     ! $db->countUserSetLocations($userID, $setID) ) { 
				@defaultLocations = @globalLocations;
				$ipOverride = 0;
			} elsif ( $forUsers ) {
				@defaultLocations = $db->listUserSetLocations($userID, $setID);
				$ipOverride = 1;
			} else {
				@defaultLocations = @globalLocations;
			}
			my $ipDefaults = join(', ', @globalLocations);

			my $ipSelector = CGI::scrolling_list({
				-name => "set.$setID.selected_ip_locations",
				-values => [ @locations ], 
				-default => [ @defaultLocations ], 
				-size => 5,
				-multiple => 'true'});

			my $override = ($forUsers) ? 
				CGI::checkbox({ type => "checkbox",
					name => "set.$setID.selected_ip_locations.override",
					label => "",
					checked => $ipOverride }) : '';
			$ipFields .= CGI::Tr({-valign=>'top'},
					     CGI::td({}, [ $override, 
						   $r->maketext('Restrict Locations'), 
						   $ipSelector, 
						   $forUsers ? 
						   " $ipDefaults" : '', ]
					),
			);
		}
	}
	return($extraFields, $ipFields, $numLocations, $procFields);
}

sub proctoredFieldHTML {
	my ( $self, $userID, $setID, $globalRecord ) = @_;

	my $r = $self->r;
	my $db = $r->db;

	# note that this routine assumes that the login proctor password
	#    is something that can only be changed for the global set

	# if the set doesn't require a login proctor, then we can assume
	#    that one doesn't exist; otherwise, we need to check the 
	#    database to find if there's an already defined password
	my $value = '';
	if ( $globalRecord->restricted_login_proctor eq 'Yes' &&
	     $db->existsPassword("set_id:$setID") ) {
		$value = '********';
	}

	return( ( '',
		  $r->maketext('Password (Leave blank for regular proctoring)'),
		  CGI::input({ name=>"set.$setID.restricted_login_proctor_password",
			       value=>$value,
			       size=>10,
		       }),
		  '' ) );
}

# used to print nested lists for jitar sets
# this is a recursive function which is used to print the tree structure
# that jitar sets can have using nested unordered lists
sub print_nested_list {
    my $nestedHash = shift;
    my $id = shift;
    
    # this hash contains information about the problem at this node, which
    # we print and then delete
    if (defined $nestedHash->{'row'}) {
	print CGI::start_li({class=>"psd_list_row",id=>"psd_list_".$nestedHash->{'id'}});
	print  $nestedHash->{'row'};
	delete $nestedHash->{'row'};
	delete $nestedHash->{'id'}
    }
    
    # any remaining keys are references to child nodes which need to be
    # printed in a sub list.  
    my @keys = keys %$nestedHash;
    if (@keys) {
	print CGI::start_ol();
	foreach my $id (sort {$a <=> $b} @keys) {
	    print_nested_list($nestedHash->{$id});
	}
	print CGI::end_ol();
    }

    print CGI::end_li();
}

# handles rearrangement necessary after changes to problem ordering
sub handle_problem_numbers {
	my $self = shift;
	my $r = $self->r;
	my $newProblemNumbersref = shift;
	my %newProblemNumbers = %$newProblemNumbersref;
	my $db = shift;
	my $setID = shift;
	my $force = 0;
	my $maxDepth = 0;
	my @sortme=();
	my ($j, $val);
	my @prob_ids; 

	# check to see that everything has a number and if anything was renumbered.  
	foreach $j (keys %newProblemNumbers) {
		return "" if (not defined $newProblemNumbers{$j});
		$force = 1 if $newProblemNumbers{$j} != $j; 
	}

	# we dont do anything unless a problem has been reordered or we were asked to
	return "" unless $force;

	# get problems and store them in a hash.  
        # We do this all at once because its not always clear 
	# what is overwriting what and when.  
	# We try to keep things sane by only getting and storing things
	# which have actually been reordered
	my %problemHash;
	my @setUsers = $db->listSetUsers($setID);
	my %userProblemHash;


	foreach $j (keys %newProblemNumbers) {
	    next if $newProblemNumbers{$j} == $j;

	    $problemHash{$j} = $db->getGlobalProblem($setID, $j);
	    die $r->maketext("global [_1] for set [_2] not found.", $j, $setID) unless $problemHash{$j};
	    foreach my $user (@setUsers) {
		$userProblemHash{$user}{$j} = $db->getUserProblem($user,$setID, $j);
		warn $r->maketext("UserProblem missing for user=[_1] set=[_2] problem=[_3]. This may indicate database corruption.", $user, $setID, $j)."\n" 
		    unless $userProblemHash{$user}{$j};
	    }
	}
	
	# now go through and move problems around 		
	# because of the way the reordering works with the draggable
	# js handler we cant have any conflicts or holes
	foreach $j (keys %newProblemNumbers) {
	    next if ($newProblemNumbers{$j} == $j);
			 
	    $problemHash{$j}->problem_id($newProblemNumbers{$j});
	    if ($db->existsGlobalProblem($setID, $newProblemNumbers{$j})) {
		$db->putGlobalProblem($problemHash{$j});
	    } else {
		$db->addGlobalProblem($problemHash{$j});
	    }
	    
	    # now deal with the user sets	
		
	    foreach my $user (@setUsers) {
	
		$userProblemHash{$user}{$j}->problem_id($newProblemNumbers{$j});
		if ($db->existsUserProblem($user, $setID, $newProblemNumbers{$j})) {
		    $db->putUserProblem($userProblemHash{$user}{$j});
		} else {
		    $db->addUserProblem($userProblemHash{$user}{$j});
		}

	    }

	    # now we need to delete "orphan" problems that were not overwritten by something else
	    my $delete = 1;
	    foreach my $k (keys %newProblemNumbers) {
		$delete = 0 if ($j == $newProblemNumbers{$k});
	    }
	    
	    if ($delete) {
		$db->deleteGlobalProblem($setID, $j);
	    }

	}

	
	# return a string form of the old problem IDs in the new order (not used by caller, incidentally)
	return join(', ', values %newProblemNumbers);
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

	## we're now allowing setID to come in as setID,v# to edit a set
	##    version; catch this first
	my $editingSetVersion = 0;
	if ( $setID =~ /,v(\d+)$/ ) {
	    $editingSetVersion = $1;
	    $setID =~ s/,v(\d+)$//;
	}

	my $setRecord = $db->getGlobalSet($setID); # checked
	die $r->maketext("global set [_1] not found.", $setID) unless $setRecord;

	$self->{set}  = $setRecord;
	my @editForUser = $r->param('editForUser');
	# some useful booleans
	my $forUsers   = scalar(@editForUser);
	my $forOneUser = $forUsers == 1;

	# Check permissions
	return unless ($authz->hasPermissions($user, "access_instructor_tools"));
	return unless ($authz->hasPermissions($user, "modify_problem_sets"));

	## if we're editing a versioned set, it only makes sense to be
	##    editing it for one user
	return if ( $editingSetVersion && ! $forOneUser );

	my %properties = %{ FIELD_PROPERTIES() };

	# takes a hash of hashes and inverts it
	my %undoLabels;
	foreach my $key (keys %properties) {
		%{ $undoLabels{$key} } = map { $r->maketext($properties{$key}->{labels}->{$_}) => $_ } keys %{ $properties{$key}->{labels} };
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

	my ($open_date, $due_date, $answer_date, $reduced_scoring_date);
	my $error = 0;	
	if (defined $r->param('submit_changes')) {
		my @names = ("open_date", "due_date", "answer_date", "reduced_scoring_date");

		my %dates = map { $_ => $r->param("set.$setID.$_") || ''} @names;

		%dates = map { 
			my $unlabel = $undoLabels{$_}->{$dates{$_}}; 
			$_ => (defined($unlabel) || !$dates{$_}) ? $setRecord->$_ : $self->parseDateTime($dates{$_}) 
		} @names;

		($open_date, $due_date, $answer_date, $reduced_scoring_date) = map { $dates{$_}||0 } @names;
		
		# make sure dates are numeric by using ||0
        
		if ($answer_date < $due_date || $answer_date < $open_date) {		
			$self->addbadmessage($r->maketext("Answers cannot be made available until on or after the close date!"));
			$error = $r->param('submit_changes');
		}
		
		if ($due_date < $open_date ) {
			$self->addbadmessage($r->maketext("Answers cannot be due until on or after the open date!"));
			$error = $r->param('submit_changes');
		}

		my $enable_reduced_scoring = 
		    $ce->{pg}{ansEvalDefaults}{enableReducedScoring} && 
		    (defined($r->param("set.$setID.enable_reduced_scoring")) ? 
		    $r->param("set.$setID.enable_reduced_scoring") : 
		    $setRecord->enable_reduced_scoring);

		if ($enable_reduced_scoring &&
		    $reduced_scoring_date
		    && ($reduced_scoring_date > $due_date 
			|| $reduced_scoring_date < $open_date)) {
		    $self->addbadmessage($r->maketext("The reduced scoring date should be between the open date and close date."));
		    $error = $r->param('submit_changes');
		}

		# make sure the dates are not more than 10 years in the future
		my $curr_time = time;
		my $seconds_per_year = 31_556_926;
		my $cutoff = $curr_time + $seconds_per_year*10;
		if ($open_date > $cutoff) {
			$self->addbadmessage($r->maketext("Error: open date cannot be more than 10 years from now in set [_1]", $setID));
			$error = $r->param('submit_changes');
		}
		if ($due_date > $cutoff) {
			$self->addbadmessage($r->maketext("Error: close date cannot be more than 10 years from now in set [_1]", $setID));
			$error = $r->param('submit_changes');
		}
		if ($answer_date > $cutoff) {
			$self->addbadmessage($r->maketext("Error: answer date cannot be more than 10 years from now in set [_1]", $setID));
			$error = $r->param('submit_changes');
		}

	}
	
	if ($error) {
		$self->addbadmessage($r->maketext("No changes were saved!"));
	}

	if (defined $r->param('submit_changes') && !$error) {

		#my $setRecord = $db->getGlobalSet($setID); # already fetched above --sam
	        my $oldAssignmentType = $setRecord->assignment_type(); 
		
		#####################################################################
		# Save general set information (including headers)
		#####################################################################

		if ($forUsers) {
			# note that we don't deal with the proctor user
			#    fields here, with the assumption that it can't
			#    be possible to change them for users.  this is
			#    not the most robust treatment of the problem
			#    (FIXME)

			# DBFIXME use a WHERE clause, iterator
			my @userRecords = $db->getUserSets(map { [$_, $setID] } @editForUser);
			# if we're editing a set version, we want to edit
			#    edit that instead of the userset, so get it
			#    too.
			my $userSet = $userRecords[0];
			my $setVersion = 0;
			if ( $editingSetVersion ) {
				$setVersion =
					$db->getSetVersion($editForUser[0],
							   $setID,
							   $editingSetVersion);
				@userRecords = ( $setVersion );
			}

			foreach my $record (@userRecords) {
				foreach my $field ( @{ SET_FIELDS() } ) {
					next unless canChange($forUsers, $field);
					my $override = $r->param("set.$setID.$field.override");

					if (defined $override && $override eq $field) {

					    my $param = $r->param("set.$setID.$field");
					    $param = defined $properties{$field}->{default} ? $properties{$field}->{default} : "" unless defined $param && $param ne "";

					    my $unlabel = $undoLabels{$field}->{$param};
						$param = $unlabel if defined $unlabel;
#						$param = $undoLabels{$field}->{$param} || $param;
						if ($field =~ /_date/ ) {
							$param = $self->parseDateTime($param) unless defined $unlabel;
						} 					    
						if (defined($properties{$field}->{convertby}) && $properties{$field}->{convertby}) {
							$param = $param*$properties{$field}->{convertby};
						}
						# special case; does field fill in multiple values?
						if ( $field =~ /:/ ) {
							my @values = split(/:/, $param);
							my @fields = split(/:/, $field);
							for ( my $i=0; $i<@values; $i++ ) { 
								my $f=$fields[$i]; 
								$record->$f($values[$i]);
							}
						} else {
							$record->$field($param);
						}
					} else {
						####################
						# FIXME: allow one selector to set multiple fields
						# 
						if ( $field =~ /:/ ) {
							foreach my $f ( split(/:/, $field) ) {
								$record->$f(undef);
							}
						} else {
							$record->$field(undef);
						}
					}
				
				}
				####################
				# FIXME: this is replaced by our allowing multiple fields to be set by one selector
				# a check for hiding scores: if we have 
				#    $set->hide_score eq 'N', we also want 
				#    $set->hide_score_by_problem eq 'N'
				# if ( $record->hide_score eq 'N' ) {
				# 	$record->hide_score_by_problem('N');
				# }
				####################
				if ( $editingSetVersion ) {
					$db->putSetVersion( $record );
				} else {
					$db->putUserSet($record);
				}
			}

		#######################################################
		# Save IP restriction Location information
		#######################################################
		# FIXME: it would be nice to have this in the field values
		#    hash, so that we don't have to assume that we can 
		#    override this information for users

			## should we allow resetting set locations for set versions?  this
			##    requires either putting in a new set of database routines
			##    to deal with the versioned setID, or fudging it at this end
			##    by manually putting in the versioned ID setID,v#.  neither
			##    of these seems desirable, so for now it's not allowed
			if ( ! $editingSetVersion ) {
				if ( $r->param("set.$setID.selected_ip_locations.override") ) {
					foreach my $record ( @userRecords ) {
						my $userID = $record->user_id;
						my @selectedLocations = $r->param("set.$setID.selected_ip_locations");
						my @userSetLocations = $db->listUserSetLocations($userID,$setID);
						my @addSetLocations = ();
						my @delSetLocations = ();
						foreach my $loc ( @selectedLocations ) {
							push( @addSetLocations, $loc ) if ( ! grep( /^$loc$/, @userSetLocations ) );
						}
						foreach my $loc ( @userSetLocations ) {
							push( @delSetLocations, $loc ) if ( ! grep( /^$loc$/, @selectedLocations ) );
						}
						# then update the user set_locations
						foreach ( @addSetLocations ) {
							my $Loc = $db->newUserSetLocation;
							$Loc->set_id( $setID );
							$Loc->user_id( $userID );
							$Loc->location_id($_);
							$db->addUserSetLocation($Loc);
						}
						foreach ( @delSetLocations ) {
							$db->deleteUserSetLocation($userID,$setID,$_);
						}
					}
				} else {
					# if override isn't selected, then we want
					#    to be sure that there are no
					#    set_locations_user entries setting around
					foreach my $record ( @userRecords ) {
						my $userID = $record->user_id;
						my @userLocations = $db->listUserSetLocations($userID,$setID);
						foreach ( @userLocations ) {
							$db->deleteUserSetLocation($userID,$setID,$_);
						}
					}
				}
			}
		} else {
			foreach my $field ( @{ SET_FIELDS() } ) {
				next unless canChange($forUsers, $field);

				my $param = $r->param("set.$setID.$field");
				$param = defined $properties{$field}->{default} ? $properties{$field}->{default} : "" unless defined $param && $param ne "";
				my $unlabel = $undoLabels{$field}->{$param};
				$param = $unlabel if defined $unlabel;
				if ($field =~ /_date/ ) {
				    $param = $self->parseDateTime($param) unless (defined $unlabel || !$param);
				} 
				if ($field =~ /restricted_release/) {
				    $self->check_sets($db,$param) if $param;
				}
				if (defined($properties{$field}->{convertby}) && $properties{$field}->{convertby} && $param) {
					$param = $param*$properties{$field}->{convertby};
				}
				# special case; does field fill in multiple values?
				if ( $field =~ /:/ ) {
					my @values = split(/:/, $param);
					my @fields = split(/:/, $field);
					for ( my $i=0; $i<@fields; $i++ ) { 
						my $f = $fields[$i];
						$setRecord->$f($values[$i]);
					}
				} else {
					$setRecord->$field($param);
				}
			}
####################
# FIXME: this is replaced by our setting both hide_score and hide_score_by_problem
#    with a single drop down
# 
# 			# a check for hiding scores: if we have 
# 			#    $set->hide_score eq 'N', we also want 
# 			#    $set->hide_score_by_problem eq 'N', and if it's
# 			#    changed to 'Y' and hide_score_by_problem is Null,
# 			#    give it a value 'N'
# 			if ( $setRecord->hide_score eq 'N' ||
# 			     ( ! defined($setRecord->hide_score_by_problem) ||
# 			       $setRecord->hide_score_by_problem eq '' ) ) {
# 				$setRecord->hide_score_by_problem('N');
# 			}
####################
			$db->putGlobalSet($setRecord);

		#######################################################
		# Save IP restriction Location information
		#######################################################

			if ( defined($r->param("set.$setID.restrict_ip")) and $r->param("set.$setID.restrict_ip") ne 'No' ) {
				my @selectedLocations = $r->param("set.$setID.selected_ip_locations");
				my @globalSetLocations = $db->listGlobalSetLocations($setID);
				my @addSetLocations = ();
				my @delSetLocations = ();
				foreach my $loc ( @selectedLocations ) {
					push( @addSetLocations, $loc ) if ( ! grep( /^$loc$/, @globalSetLocations ) );
				}
				foreach my $loc ( @globalSetLocations ) {
					push( @delSetLocations, $loc ) if ( ! grep( /^$loc$/, @selectedLocations ) );
				}
				# then update the global set_locations
				foreach ( @addSetLocations ) {
					my $Loc = $db->newGlobalSetLocation;
					$Loc->set_id( $setID );
					$Loc->location_id($_);
					$db->addGlobalSetLocation($Loc);
				}
				foreach ( @delSetLocations ) {
					$db->deleteGlobalSetLocation($setID,$_);
				}
			} else {
				my @globalSetLocations = $db->listGlobalSetLocations($setID);
				foreach ( @globalSetLocations ) {
					$db->deleteGlobalSetLocation($setID,$_);
				}
			}

		#######################################################
		# Save proctored problem proctor user information
		#######################################################
			if ($r->param("set.$setID.restricted_login_proctor_password") &&
			    $setRecord->assignment_type eq 'proctored_gateway') {
				# in this case we're adding a set-level proctor
				#    or updating the password

				my $procID = "set_id:$setID";
				my $pass = $r->param("set.$setID.restricted_login_proctor_password");
				# should we carefully check in this case that
				#    the user and password exist?  the code 
				#    in the add stanza is pretty careful to 
				#    be sure that there's a one-to-one 
				#    correspondence between the existence of 
				#    the user and the setting of the set
				#    restricted_login_proctor field, so we 
				#    assume that just checking the latter 
				#    here is sufficient.
				if ( $setRecord->restricted_login_proctor eq 'Yes' ) {
					# in this case we already have a set
					#    level proctor, and so should be 
					#    resetting the password
					if ( $pass ne '********' ) {
						# then we submitted a new 
						#    password, so save it
						my $dbPass;
						eval { $dbPass = $db->getPassword($procID) };
						if ( $@ ) {
							$self->addbadmessage($r->maketext("Error getting old set-proctor password from the database: [_1].  No update to the password was done.", $@));
						} else {
							$dbPass->password(cryptPassword($pass));
							$db->putPassword($dbPass);
						}
					}

				} else {
					$setRecord->restricted_login_proctor('Yes');
					my $procUser = $db->newUser();
					$procUser->user_id($procID);
					$procUser->last_name("Proctor");
					$procUser->first_name("Login");
					$procUser->student_id("loginproctor");
					$procUser->status($ce->status_name_to_abbrevs('Proctor'));
					my $procPerm = $db->newPermissionLevel;
					$procPerm->user_id($procID);
					$procPerm->permission($ce->{userRoles}->{login_proctor});
					my $procPass = $db->newPassword;
					$procPass->user_id($procID);
					$procPass->password(cryptPassword($pass));
					# put these into the database
					eval { $db->addUser($procUser) };
					if ( $@ ) { 
						$self->addbadmessage($r->maketext("Error adding set-level proctor: [_1]", $@));
					} else {
						$db->addPermissionLevel($procPerm);
						$db->addPassword($procPass);
					}

					# and set the restricted_login_proctor
					#    set field
					$db->putGlobalSet( $setRecord );
				}

			} else {
				# if the parameter isn't set, or if the assignment
				#    type is not 'proctored_gateway', then we need to be 
				#    sure that there's no set-level proctor defined
				if ( $setRecord->restricted_login_proctor eq 'Yes' ) {

					$setRecord->restricted_login_proctor('No');
					$db->deleteUser( "set_id:$setID" );
					$db->putGlobalSet( $setRecord );

				}
			}
		}
		
		#####################################################################
		# Save problem information
		#####################################################################

		# DBFIXME use a WHERE clause, iterator?
		my @problemIDs = sort { $a <=> $b } $db->listGlobalProblems($setID);;
		my @problemRecords = $db->getGlobalProblems(map { [$setID, $_] } @problemIDs);
		foreach my $problemRecord (@problemRecords) {
			my $problemID = $problemRecord->problem_id;
			die $r->maketext("Global problem [_1] for set [_2] not found.", $problemID, $setID) unless $problemRecord;
			
			if ($forUsers) {
				# Since we're editing for specific users, we don't allow the GlobalProblem record to be altered on that same page
				# So we only need to make changes to the UserProblem record and only then if we are overriding a value
				# in the GlobalProblem record or for fields unique to the UserProblem record.
								
				my @userIDs = @editForUser;

				my @userProblemRecords;
				if ( ! $editingSetVersion ) {
					my @userProblemIDs = map { [$_, $setID, $problemID] } @userIDs;
					# DBFIXME where clause? iterator?
					@userProblemRecords = $db->getUserProblems(@userProblemIDs);
				} else {
					## (we know that we're only editing for one user)
					@userProblemRecords =
						( $db->getMergedProblemVersion( $userIDs[0], $setID, $editingSetVersion, $problemID ) );
				}

				foreach my $record (@userProblemRecords) {

					my $changed = 0; # keep track of any changes, if none are made, avoid unnecessary db accesses
					foreach my $field ( @{ PROBLEM_FIELDS() } ) {
						next unless canChange($forUsers, $field);

						my $override = $r->param("problem.$problemID.$field.override");
						if (defined $override && $override eq $field) {

							my $param = $r->param("problem.$problemID.$field");
							$param = defined $properties{$field}->{default} ? $properties{$field}->{default} : "" unless defined $param && $param ne "";
							my $unlabel = $undoLabels{$field}->{$param};
							$param = $unlabel if defined $unlabel;
												#protect exploits with source_file
							if ($field eq 'source_file') {
								# add message
								if ( $param =~ /\.\./ || $param =~ /^\// ) {
									$self->addbadmessage( $r->maketext("Source file paths cannot include .. or start with /: your source file path was modified.") );
								}
								$param =~ s|\.\.||g;    # prevent access to files above template
								$param =~ s|^/||;       # prevent access to files above template
							}

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
						$param = defined $properties{$field}->{default} ? $properties{$field}->{default} : "" unless defined $param && $param ne "";
						my $unlabel = $undoLabels{$field}->{$param};
						$param = $unlabel if defined $unlabel;
											#protect exploits with source_file
						if ($field eq 'source_file') {
							# add message
							if ( $param =~ /\.\./ || $param =~ /^\// ) {
								$self->addbadmessage( $r->maketext("Source file paths cannot include .. or start with /: your source file path was modified."));
							}
							$param =~ s|\.\.||g;    # prevent access to files above template
							$param =~ s|^/||;       # prevent access to files above template
						}

						$changed ||= changed($record->$field, $param);
						$record->$field($param);
					}
					if ( ! $editingSetVersion ) {
						$db->putUserProblem($record) if $changed;
					} else {
						$db->putProblemVersion($record) if $changed;
					}
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
					$param = defined $properties{$field}->{default} ? $properties{$field}->{default} : "" unless defined $param && $param ne "";
					my $unlabel = $undoLabels{$field}->{$param};
					$param = $unlabel if defined $unlabel;
					
					#protect exploits with source_file
					if ($field eq 'source_file') {
						# add message
						if ( $param =~ /\.\./ || $param =~ /^\// ) {
							$self->addbadmessage( $r->maketext("Source file paths cannot include .. or start with /: your source file path was modified.") );
						}
						$param =~ s|\.\.||g;    # prevent access to files above template
						$param =~ s|^/||;       # prevent access to files above template
					}
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
					# DBFIXME where clause, iterator
					my @userIDs = $db->listProblemUsers($setID, $problemID);
					my @userProblemIDs = map { [$_, $setID, $problemID] } @userIDs;
					my @userProblemRecords = $db->getUserProblems(@userProblemIDs);
					foreach my $record (@userProblemRecords) {
						my $changed = 0; # keep track of any changes, if none are made, avoid unnecessary db accesses
						foreach my $field ( keys %useful ) {
							next unless canChange($forUsers, $field);

							my $param = $r->param("problem.$problemID.$field");
							$param = defined $properties{$field}->{default} ? $properties{$field}->{default} : "" unless defined $param && $param ne "";
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
		
		# Mark the specified problems as correct for all users (not applicable when editing a set
		#    version, because this only shows up when editing for users or editing the
		#    global set/problem, not for one user)
		foreach my $problemID ($r->param('markCorrect')) {
			# DBFIXME where clause, iterator
			my @userProblemIDs = map { [$_, $setID, $problemID] } ($forUsers ? @editForUser : $db->listProblemUsers($setID, $problemID));
			# if the set is not a gateway set, this requires going through the
			#    user_problems and resetting their status; if it's a gateway set,
			#    then we have to go through every *version* of every user_problem.
			#    it may be that there is an argument for being able to get() all
			#    problem versions for all users in one database call.  The current
			#    code may be slow for large classes.
			if ( $setRecord->assignment_type !~ /gateway/ ) {
				my @userProblemRecords = $db->getUserProblems(@userProblemIDs);
				foreach my $record (@userProblemRecords) {
					if (defined $record && ($record->status eq "" || $record->status < 1)) {
						$record->status(1);
						$record->attempted(1);
						$db->putUserProblem($record);
					}
				}
			} else {
				my @userIDs = ( $forUsers ) ? @editForUser : $db->listProblemUsers($setID, $problemID);
				foreach my $uid ( @userIDs ) {
					my @versions = $db->listSetVersions( $uid, $setID );
					my @userProblemVersionIDs = 
						map{ [ $uid, $setID, $_, $problemID ]} @versions;
					my @userProblemVersionRecords = $db->getProblemVersions(@userProblemVersionIDs);
					foreach my $record (@userProblemVersionRecords) { 
						if (defined $record && ($record->status eq "" || $record->status < 1)) {
							$record->status(1);
							$record->attempted(1);
							$db->putProblemVersion($record);
						}
					}
				}
			}
		}
		
		# Delete all problems marked for deletion (not applicable when editing
		#    for users)
		foreach my $problemID ($r->param('deleteProblem')) {
			$db->deleteGlobalProblem($setID, $problemID);

			# if its a jitar set we have to delete all of the child problems
			if ($setRecord->assignment_type eq 'jitar') {
			    my @ids = $db->listGlobalProblems($setID);
			    my @problemSeq = jitar_id_to_seq($problemID);
			  ID: foreach my $id (@ids) {
			      my @seq = jitar_id_to_seq($id);
			      #check and see if this is a child
			      next unless $#seq > $#problemSeq;
			      for (my $i = 0; $i<=$#problemSeq; $i++) {
				  next ID unless $seq[$i] == $problemSeq[$i];
			      }
			      $db->deleteGlobalProblem($setID,$id);
			  }
			    
			}
		}
		
		# Change problem_ids from regular style to jitar style if appropraite.  (not
		# applicable when editing for users)
		# this is a very long operaiton because we are shuffling the whole database around
		if ($oldAssignmentType ne $setRecord->assignment_type() &&(
		    $oldAssignmentType eq 'jitar' ||
		    $setRecord->assignment_type eq 'jitar')) {

		    my %newProblemNumbers;
		    my @ids = $db->listGlobalProblems($setID);
		    my $i = 1;    
		    foreach my $id (@ids) {
		
			if ($setRecord->assignment_type eq 'jitar') {
			    $newProblemNumbers{$id} = seq_to_jitar_id(($id));
			} else {
			    $newProblemNumbers{$id} = $i;
			    $i++;
			}
		    }

		    #we dont want to confuse the script by changing the problem
		    #ids out from under it so remove the params
		    foreach my $id (@ids) {
			$r->param("prob_num_".$id,"");
		    }

		    handle_problem_numbers($self,\%newProblemNumbers, $db, $setID);
		    
		}
		
		##################################################################
		# reorder problems
		##################################################################

		my %newProblemNumbers = ();
		my $prevNum = 0;
		my @prevSeq = (0);


		for my $jj (sort { $a <=> $b } $db->listGlobalProblems($setID)) {

		    if ($setRecord->assignment_type eq 'jitar') {
			my @idSeq;
			my $id = $jj;
			
			next unless $r->param('prob_num_'.$id);
			
			unshift @idSeq, $r->param('prob_num_'.$id);
			while (defined $r->param('prob_parent_id_'.$id)) {
			    $id = $r->param('prob_parent_id_'.$id);
			    unshift @idSeq, $r->param('prob_num_'.$id);
			}

			$newProblemNumbers{$jj} = seq_to_jitar_id(@idSeq);
						
		    } else {
		      $newProblemNumbers{$jj} = $r->param('prob_num_' . $jj);
		    }
		  }
		
		handle_problem_numbers($self,\%newProblemNumbers, $db, $setID) unless defined $r->param('undo_changes');

		
		#####################################################################
		# Make problem numbers consecutive if required
		#####################################################################


		if ($r->param('force_renumber')) {

		  my %newProblemNumbers = ();
		  my $prevNum = 0;
		  my @prevSeq = (0);
		
		  for my $jj (sort { $a <=> $b } $db->listGlobalProblems($setID)) {
		    
		    if ($setRecord->assignment_type eq 'jitar') {
		      my @idSeq;
		      my $id = $jj;
		      
		      next unless $r->param('prob_num_'.$id);
		      
		      unshift @idSeq, $r->param('prob_num_'.$id);
		      while (defined $r->param('prob_parent_id_'.$id)) {
			$id = $r->param('prob_parent_id_'.$id);
			unshift @idSeq, $r->param('prob_num_'.$id);
		      }
		      
		      # we dont really care about the content of idSeq
		      # in this case, just the length
		      my $depth = $#idSeq;
		      
		      if ($depth <= $#prevSeq) {
			@prevSeq = @prevSeq[ 0 .. $depth ];
			$prevSeq[$#prevSeq]++;
		      } else {
			$prevSeq[$#prevSeq+1] = 1;
		      }
		      
		      $newProblemNumbers{$jj} = seq_to_jitar_id(@prevSeq);
						
		    } else {
		      $prevNum++;
		      $newProblemNumbers{$jj} = $prevNum;
		    }
		  }
		
		  handle_problem_numbers($self,\%newProblemNumbers, $db, $setID) unless defined $r->param('undo_changes');

		}

		#####################################################################
		# Add blank problem if needed
		#####################################################################
		if (defined($r->param("add_blank_problem") ) and $r->param("add_blank_problem") == 1) {
		   # get number of problems to add and clean the entry
		    my $newBlankProblems = (defined($r->param("add_n_problems")) ) ? $r->param("add_n_problems") :1;
		    $newBlankProblems = int($newBlankProblems);
		    my $MAX_NEW_PROBLEMS = 20;
		    my @ids = $self->r->db->listGlobalProblems($setID);

		    if ($setRecord->assignment_type eq 'jitar') {
			for (my $i=0; $i <= $#ids; $i++) {
			    my @seq = jitar_id_to_seq($ids[$i]);
			    $ids[$i] = $seq[0];
			    #this strips off the depth 0 problem numbers if its a jitar set
			}
		    }

		    my $targetProblemNumber = WeBWorK::Utils::max(@ids);

		    if ($newBlankProblems >=1 and $newBlankProblems <= $MAX_NEW_PROBLEMS ) {
				foreach my $newProb (1..$newBlankProblems) {
						$targetProblemNumber++;
						##################################################
						# make local copy of the blankProblem
						##################################################
						my $blank_file_path       =  $ce->{webworkFiles}->{screenSnippets}->{blankProblem};
						my $problemContents       =  WeBWorK::Utils::readFile($blank_file_path);
						my $new_file_path         =  "set$setID/".BLANKPROBLEM();
						my $fullPath              =  WeBWorK::Utils::surePathToFile($ce->{courseDirs}->{templates},'/'.$new_file_path);
						local(*TEMPFILE);
						open(TEMPFILE, ">$fullPath") or warn $r->maketext("Can't write to file [_1]", $fullPath);
						print TEMPFILE $problemContents;
						close(TEMPFILE);
						
						#################################################
						# Update problem record
						#################################################
						my $problemRecord  = $self->addProblemToSet(
								   setName        => $setID,
								   sourceFile     => $new_file_path, 
								   problemID      => 
						    $setRecord->assignment_type eq 'jitar' ? 
						    seq_to_jitar_id(($targetProblemNumber)) : 
						    $targetProblemNumber, #added to end of set
						);

						$self->assignProblemToAllSetUsers($problemRecord);
						$self->addgoodmessage($r->maketext("Added [_1] to [_2] as problem [_3]", $new_file_path, $setID, $targetProblemNumber)) ;
				}
			} else {
				$self->addbadmessage($r->maketext("Could not add [_1] problems to this set.  The number must be between 1 and [_2]", $newBlankProblems, $MAX_NEW_PROBLEMS));
			}
		}
		
		# Sets the specified header to "defaultHeader" so that the default file will get used.
		foreach my $header ($r->param('defaultHeader')) {
			$setRecord->$header("defaultHeader");
		}
	}	
	
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
	my ($self, $filePath, $headerType) = @_;

	my $r = $self->r;
	my $ce = $r->ce;

	return $r->maketext("No source filePath specified") unless $filePath;
	return $r->maketext("Problem source is drawn from a grouping set") if $filePath =~ /^group/;
	
	if ( $filePath eq "defaultHeader" ) {
		if ($headerType eq 'set_header') {
		  $filePath = $ce->{webworkFiles}{screenSnippets}{setHeader};
		} elsif  ($headerType eq 'hardcopy_header') {
			$filePath = $ce->{webworkFiles}{hardcopySnippets}{setHeader};
		}	else	{
			return $r->maketext("Invalid headerType [_1]", $headerType);	
		}	
	} else {
	#	$filePath = $ce->{courseDirs}->{templates} . '/' . $filePath unless $filePath =~ m|^/|; # bug: 1725 allows access to all files e.g. /etc/passwd
		$filePath = $ce->{courseDirs}->{templates} . '/' . $filePath ; # only filePaths in template directory can be accessed 
	}
    
	my $fileError;
	return "" if -e $filePath && -f $filePath && -r $filePath;
	return $r->maketext("This source file is not readable!") if -e $filePath && -f $filePath;
	return $r->maketext("This source file is a directory!") if -d $filePath;
	return $r->maketext("This source file does not exist!") unless -e $filePath;
	return $r->maketext("This source file is not a plain file!");
}

#Make sure restrictor sets exist
sub check_sets {
	my ($self,$db,$sets_string) = @_;
	my @proposed_sets = split(/\s*,\s*/,$sets_string);
	foreach(@proposed_sets) {
	  $self->addbadmessage("Error: $_ is not a valid set name in restricted release list!") unless $db->existsGlobalSet($_);
	}
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

	## we're now allowing setID to come in as setID,v# to edit a set
	##    version; catch this first
	my $editingSetVersion = 0;
	my $fullSetID = $setID;
	if ( $setID =~ /,v(\d+)$/ ) {
	    $editingSetVersion = $1;
	    $setID =~ s/,v(\d+)$//;
	}

	my $setRecord   = $db->getGlobalSet($setID) or die $r->maketext("No record for global set [_1].", $setID);

	my $userRecord = $db->getUser($userID) or die $r->maketext("No record for user [_1].", $userID);
	# Check permissions
	return CGI::div({class=>"ResultsWithError"}, $r->maketext("You are not authorized to access the Instructor tools."))
		unless $authz->hasPermissions($userRecord->user_id, "access_instructor_tools");
	
	return CGI::div({class=>"ResultsWithError"}, $r->maketext("You are not authorized to modify problems."))
		unless $authz->hasPermissions($userRecord->user_id, "modify_problem_sets");

	my @editForUser = $r->param('editForUser');

	return CGI::div({class=>"ResultsWithError"}, $r->maketext("Versions of a set can only be edited for one user at a time.")) if ( $editingSetVersion && @editForUser != 1 );

	# Check that every user that we're editing for has a valid UserSet
	my @assignedUsers;
	my @unassignedUsers;
	if (scalar @editForUser) {
		foreach my $ID (@editForUser) {
			# DBFIXME iterator
			if ($db->getUserSet($ID, $setID)) {
				unshift @assignedUsers, $ID;
			} else {
				unshift @unassignedUsers, $ID;
			}
		}
		@editForUser = sort @assignedUsers;
		$r->param("editForUser", \@editForUser);
		
		if (scalar @editForUser && scalar @unassignedUsers) {
			print CGI::div({class=>"ResultsWithError"}, $r->maketext("The following users are NOT assigned to this set and will be ignored: [_1]", CGI::b(join(", ", @unassignedUsers))) );
		} elsif (scalar @editForUser == 0) {
			print CGI::div({class=>"ResultsWithError"}, $r->maketext("None of the selected users are assigned to this set: [_1]", CGI::b(join(", ", @unassignedUsers))));
			print CGI::div({class=>"ResultsWithError"}, $r->maketext("Global set data will be shown instead of user specific data"));
		}		
	}

	# some useful booleans
	my $forUsers    = scalar(@editForUser);
	my $forOneUser  = $forUsers == 1;

	# and check that if we're editing a set version for a user, that
	#    it exists as well
	if ( $editingSetVersion && ! $db->existsSetVersion( $editForUser[0], $setID, $editingSetVersion ) ) {
		return CGI::div({class=>"ResultsWithError"}, $r->maketext("The set-version ([_1], version [_2]) is not assigned to user [_3].", $setID, $editingSetVersion, $editForUser[0]));
	}

	# If you're editing for users, initially their records will be different but
	# if you make any changes to them they will be the same.
	# if you're editing for one user, the problems shown should be his/hers
	my $userToShow        = $forUsers ? $editForUser[0] : $userID;

	# a useful gateway variable
	my $isGatewaySet = ( $setRecord->assignment_type =~ /gateway/ ) ? 1 : 0;
	my $isJitarSet = ( $setRecord->assignment_type eq 'jitar' ) ? 1 : 0;

	# DBFIXME no need to get ID lists -- counts would be fine
	my $userCount        = $db->listUsers();
	my $setCount         = $db->listGlobalSets(); # if $forOneUser;
	my $setUserCount     = $db->countSetUsers($setID);
# if $forOneUser;
	my $userSetCount     = ($forOneUser && @editForUser) ? $db->countUserSets($editForUser[0]) : 0;

	
	my $editUsersAssignedToSetURL = $self->systemLink(
	      $urlpath->newFromModule(
                "WeBWorK::ContentGenerator::Instructor::UsersAssignedToSet", $r, courseID => $courseID, setID => $setID),params=>{pageVersion=> "instructor_set_detail2"});
	my $editSetsAssignedToUserURL = $self->systemLink(
	      $urlpath->newFromModule(
                "WeBWorK::ContentGenerator::Instructor::UserDetail",$r,
                  courseID => $courseID, userID => $editForUser[0])) if $forOneUser;


	my $setDetailPage  = $urlpath -> newFromModule($urlpath->module, $r, courseID => $courseID, setID => $setID);
	my $fullsetDetailPage  = $urlpath -> newFromModule($urlpath->module, $r, courseID => $courseID, setID => $fullSetID);
	my $setDetailURL   = $self->systemLink($fullsetDetailPage, authen=>0);

	my $userCountMessage = CGI::a({href=>$editUsersAssignedToSetURL}, $self->userCountMessage($setUserCount, $userCount));
	my $setCountMessage = CGI::a({href=>$editSetsAssignedToUserURL}, $self->setCountMessage($userSetCount, $setCount)) if $forOneUser;

	$userCountMessage = $r->maketext("The set [_1] is assigned to [_2].", $setID, $userCountMessage);
	$setCountMessage  = $r->maketext("The user [_1] has been assigned [_2].", $editForUser[0], $setCountMessage) if $forOneUser;

	if ($forUsers) {
	    ##############################################
		# calculate links for the users being edited:
		##############################################
		my @userLinks = ();
		foreach my $userID (@editForUser) {
			my $u = $db->getUser($userID);
			my $email_address = $u->email_address;
			my $line = $u->last_name.", " . $u->first_name . "&nbsp;&nbsp;(" .
				CGI::a({-href=>"mailto:$email_address"},"email "). $u->user_id .
				"). ";
			if ( ! $editingSetVersion ) {
				$line .= $r->maketext("Assigned to").' ';
				my $editSetsAssignedToUserURL = $self->systemLink(
					$urlpath->newFromModule(
						"WeBWorK::ContentGenerator::Instructor::UserDetail", $r,
                  				courseID => $courseID, userID => $u->user_id));
            			$line .= CGI::a({href=>$editSetsAssignedToUserURL}, 
                     			$self->setCountMessage($db->countUserSets($u->user_id), 
						$setCount));
			} else {
				my $editSetLink = $self->systemLink( $setDetailPage,
					params=>{effectiveUser=>$u->user_id,
						 editForUser  =>$u->user_id} );
				$line .= $r->maketext("Edit set [_1] for this user.", CGI::a({href=>$editSetLink},$setID));
			}
			unshift @userLinks,$line;
		}
		@userLinks = sort @userLinks;
	
		# handy messages when editing gateway sets
		my $gwmsg = ( $isGatewaySet && ! $editingSetVersion ) ?
			CGI::br() . CGI::em($r->maketext("To edit a specific student version of this set, edit (all of) her/his assigned sets.")) : "";
		my $vermsg = ( $editingSetVersion ) ? ", $editingSetVersion" : "";

		print CGI::table({border=>2,cellpadding=>10}, 
		    CGI::Tr({},
				CGI::td([
					 $r->maketext("Editing problem set [_1] data for these individual students: [_2]", CGI::strong($setID . $vermsg), CGI::br().CGI::strong(join CGI::br(), @userLinks)),
					CGI::a({href=>$self->systemLink($setDetailPage) },$r->maketext("Edit set [_1] data for ALL students assigned to this set.", CGI::strong($setID))) . $gwmsg,
				
				])
			)
		);
	} else {
		print CGI::table({border=>2,cellpadding=>10}, 
		    CGI::Tr({},
				CGI::td([
					$r->maketext("This set [_1] is assigned to [_2].", CGI::strong($setID), $self->userCountMessage($setUserCount, $userCount)) ,
					$r->maketext("Edit [_1] of set [_2].", CGI::a({href=>$editUsersAssignedToSetURL},$r->maketext('individual versions')), $setID),
				
				])
			)
		);
	}

	print CGI::a({name=>"problems"}, "");
	
	my %properties = %{ FIELD_PROPERTIES() };

	my %display_modes = %{WeBWorK::PG::DISPLAY_MODES()};
	my @active_modes = grep { exists $display_modes{$_} } @{$r->ce->{pg}->{displayModes}};
	my $default_header_mode = $r->param('header.displaymode') || $r->maketext('None');
	my $default_problem_mode = $r->param('problem.displaymode') || $r->maketext('None');

	#####################################################################
	# Browse available header/problem files
	#####################################################################
	
	my $templates = $r->ce->{courseDirs}->{templates};
	my $skip = join("|", keys %{ $r->ce->{courseFiles}->{problibs} });

	my @headerFileList = listFilesRecursive(
		$templates,
		qr/header.*\.pg$/i, 		# match these files
		qr/^(?:$skip|svn)$/, 	# prune these directories
		0, 				# match against file name only
		1, 				# prune against path relative to $templates
	);
  @headerFileList = sortByName(undef,@headerFileList);
 
	# Display a useful warning message
	if ($forUsers) {
		print CGI::p(CGI::b($r->maketext("Any changes made below will be reflected in the set for ONLY the student(s) listed above.")));
	} else {
		print CGI::p(CGI::b($r->maketext("Any changes made below will be reflected in the set for ALL students.")));
	}

	print CGI::start_form({id=>"problem_set_form", name=>"problem_set_form", method=>"POST", action=>$setDetailURL});
	print $self->hiddenEditForUserFields(@editForUser);
	print $self->hidden_authen_fields;
	print CGI::input({type=>"hidden", id=>"hidden_course_id", name=>"courseID", value=>$courseID});
	print CGI::input({type=>"hidden", id=>"hidden_set_id", name=>"setID", value=>$setID});
	print CGI::input({type=>"submit", id=>"submit_changes_1", name=>"submit_changes", value=>$r->maketext("Save Changes")});
	print CGI::input({type=>"submit", name=>"undo_changes", value => $r->maketext("Reset Form")});

	# spacing
	print CGI::p();
	
	#####################################################################
	# Display general set information
	#####################################################################

	print CGI::start_table({border=>1, cellpadding=>4});
	print CGI::Tr({}, CGI::th({}, [
		$r->maketext("General Information"),
	]));
	
	# this is kind of a hack -- we need to get a user record here, so we can
	# pass it to FieldTable, so FieldTable can pass it to FieldHTML, so
	# FieldHTML doesn't have to fetch it itself.
	my $userSetRecord = $db->getUserSet($userToShow, $setID);

	my $templateUserSetRecord;
	# send in the set version if we're editing for versions
	if ( $editingSetVersion ) {
		$templateUserSetRecord = $userSetRecord;
		$userSetRecord = $db->getSetVersion( $userToShow, $setID, $editingSetVersion );
	}
	
	print CGI::Tr({}, CGI::td({}, [
		$self->FieldTable($userToShow, $setID, undef, $setRecord, $userSetRecord),
	]));

	print CGI::end_table();	

	#datepicker scripts.  
	# we try to provide the date picker scripts with the global set
	# if we aren't looking at a specific students set and the merged
	# one otherwise. 
	if ($ce->{options}->{useDateTimePicker}) {
	    my $tempSet; 
	    if ($forUsers) {
		$tempSet = $db->getMergedSet($userToShow, $setID); 
	    } else {
		$tempSet = $setRecord;
	    }
	    
	    print CGI::start_script({-type=>"text/javascript"}),"\n";
	    print q!$(".ui-datepicker").draggable();!,"\n";
	    print WeBWorK::Utils::DatePickerScripts::date_scripts($ce, $tempSet),"\n";	
	    print CGI::end_script();
	}

	# spacing
	print CGI::start_p();

	####################################################################
	# Display Field for putting in a set description
	####################################################################
	print CGI::h4($r->maketext("Set Description"));
	if ($forOneUser) {
	    print CGI::hidden({type=>'text',
			      name=>"set.$setID.description",
			      id=>"set.$setID.description",
			      value=>$setRecord->description(),
			     });
	    print $setRecord->description ? $setRecord->description : $r->maketext("No Description");
	} else {
	    print CGI::textarea({name=>"set.$setID.description",
				 id=>"set.$setID.description",
				 value=>$setRecord->description(),
				 rows=>5,
				 cols=>62,});
	}
	print CGI::end_p();
	
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
			$r->maketext("Headers"),
			$r->maketext("Data"),
					  ]));

		my %error;
		my $this_set = $db->getMergedSet($userToShow, $setID);
		my $guaranteed_set = $this_set;
		if ( ! $guaranteed_set ) { 
			# in the header loop we need to have a set that 
			#    we know exists, so if the getMergedSet failed
			#    (that is, the set isn't assigned to the 
			#    the current user), we get the global set instead
			# $guaranteed_set = $db->getGlobalSet( $setID );
			$guaranteed_set = $setRecord;
		}

		foreach my $headerType (@headers) {

			my $headerFile = $r->param("set.$setID.$headerType") || $setRecord->{$headerType};

			$headerFile = 'defaultHeader' unless $headerFile =~/\S/; # (some non-white space character required)

			$error{$headerType} = $self->checkFile($headerFile,$headerType);

			
		}
		
		foreach my $headerType (@headers) {
	
			my $editHeaderPage = $urlpath->new(type => 'instructor_problem_editor2_withset_withproblem', args => { courseID => $courseID, setID => $setID, problemID => 0 });
			my $editHeaderLink = $self->systemLink($editHeaderPage, params => { file_type => $headerType, make_local_copy => 1 });

			my $viewHeaderPage = $urlpath->new(type => $headerModules{$headerType}, args => { courseID => $courseID, setID => $setID });	
			my $viewHeaderLink = $self->systemLink($viewHeaderPage);
			
			# this is a bit of a hack; the set header isn't shown
			#    for gateway tests, and we run into trouble trying to 
			#    edit/view it in this context, so we don't show this 
			#    field for gateway tests
			if ( $headerType eq 'set_header' && 
		     	     $guaranteed_set->assignment_type =~ /gateway/ ) {
				print CGI::Tr({}, CGI::td({}, 
					      [ $r->maketext("Set Header"), 
					     	$r->maketext("Set headers are not used in display of gateway tests.")]));
				next;
			}

			print CGI::Tr({}, CGI::td({}, [
				CGI::start_table({border => 0, cellpadding => 0}) . 
					CGI::Tr({}, CGI::td({}, $r->maketext($properties{$headerType}->{name}))) . 
					CGI::Tr({}, CGI::td({}, CGI::a({class=>"psd_edit", href => $editHeaderLink, target=>"WW_Editor", 'data-toggle'=>"tooltip", 'data-original-title'=>$r->maketext("Edit Header"), 'data-placement'=>"top"}, $r->maketext("Edit")).CGI::a({class=>"psd_view", href => $viewHeaderLink, target=>"WW_View",'data-toggle'=>"tooltip", 'data-placement'=>"top",'data-original-title'=>$r->maketext("Open in New Window")}, $r->maketext("View")))) .
				CGI::end_table(),

				comboBox({
					name => "set.$setID.$headerType",
					request => $r,
					default => $r->param("set.$setID.$headerType") || $setRecord->{$headerType}  || "defaultHeader",
					multiple => 0,
					values => ["defaultHeader", @headerFileList],
					labels => { "defaultHeader" => $r->maketext("Use Default Header File") },
				})
						  ]));
		}
		
		print CGI::end_table();
	} else {
		print CGI::p(CGI::b($r->maketext("Screen and Hardcopy set header information can not be overridden for individual students.")));
	}

	# spacing
	print CGI::p();


	#####################################################################
	# Display problem information
	#####################################################################

        my @problemIDList = sort {$a <=> $b} $db->listGlobalProblems($setID);
	
	# DBFIXME use iterators instead of getting all at once
	
	# get global problem records for all problems in one go
	my %GlobalProblems;
	my @globalKeypartsRef = map { [$setID, $_] } @problemIDList;
	# DBFIXME shouldn't need to get key list here
	@GlobalProblems{@problemIDList} = $db->getGlobalProblems(@globalKeypartsRef);
	
	# if needed, get user problem records for all problems in one go
	my (%UserProblems, %MergedProblems);
	if ($forOneUser) {
		my @userKeypartsRef = map { [$editForUser[0], $setID, $_] } @problemIDList;
		# DBFIXME shouldn't need to get key list here
		@UserProblems{@problemIDList} = $db->getUserProblems(@userKeypartsRef);
		if ( ! $editingSetVersion ) {
			@MergedProblems{@problemIDList} = $db->getMergedProblems(@userKeypartsRef);
		} else {
			my @userversionKeypartsRef = map { [$editForUser[0], $setID, $editingSetVersion, $_] } @problemIDList;
			@MergedProblems{@problemIDList} = $db->getMergedProblemVersions(@userversionKeypartsRef);
		}
	}
	
	if (scalar @problemIDList) {
	    # create rows for problems.  This is done using divs instead of tables
	    # the spacing and formatting is done via bootstrap.  Bootstrap classes are added
	    # in the problemsetdetail2.js file

	    print CGI::h2($r->maketext("Problems"));
	    print CGI::div(CGI::div({id=>"psd_toolbar"}, ($forOneUser ? '' : CGI::a({href=>"#", id=>"psd_renumber"}, $r->maketext("Renumber Problems"))).
		CGI::a({href=>"#", id=>"psd_render_all"},
		       $r->maketext("Render All")).
		CGI::a({href=>"#", id=>"psd_hide_all"},
		       $r->maketext("Hide All")).
		($isJitarSet ? CGI::a({href=>"#", id=>"psd_expand_all"},
		       $r->maketext("Expand All")) : '').
		($isJitarSet ? CGI::a({href=>"#", id=>"psd_collapse_all"},
		       $r->maketext("Collapse All")) : '')).
		       CGI::span($r->maketext("Display Mode:")) . 
			      CGI::popup_menu(-name => "problem.displaymode",
					      -id => "problem_displaymode",
					      -values => \@active_modes, -default => $default_problem_mode));
		


	    print CGI::start_div({id=>"problemset_detail_list"});
	    
	    my %shownYet;
	    my $repeatFile;
	    my @problemRow;

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
		
		# when we're editing a set version, we want to be sure to
		#    use the merged problem in the edit, because we could
		#    be using problem groups (for which the problem is generated
		#    and then stored in the problem version)
		my $problemToShow = ( $editingSetVersion ) ?
		    $MergedProblems{$problemID} : $UserProblems{$problemID};
		
		my ( $editProblemPage, $editProblemLink, $viewProblemPage,
		     $viewProblemLink );
		if ( $isGatewaySet ) {
		    $editProblemPage = $urlpath->new(type =>'instructor_problem_editor2_withset_withproblem', args => { courseID => $courseID, setID => $fullSetID, problemID => $problemID });
		    $editProblemLink = $self->systemLink($editProblemPage, params => { make_local_copy => 0 });
		    $viewProblemPage =
			$urlpath->new(type =>'gateway_quiz',
				      args => { courseID => $courseID,
						setID => "Undefined_Set",
						problemID => "1" } );
		    
		    my $seed = $problemToShow ? $problemToShow->problem_seed : "";
		    my $file = $problemToShow ? $problemToShow->source_file : 
			$GlobalProblems{$problemID}->source_file;
		    
		    $viewProblemLink =
			$self->systemLink( $viewProblemPage,
					   params => { effectiveUser =>
							   ($forOneUser ? $editForUser[0] : $userID),
							   problemSeed => $seed,
							   sourceFilePath => $file });
		} else {
		    $editProblemPage = $urlpath->new(type => 'instructor_problem_editor2_withset_withproblem', args => { courseID => $courseID, setID => $fullSetID, problemID => $problemID });
		    $editProblemLink = $self->systemLink($editProblemPage, params => { make_local_copy => 0 });
		    # FIXME: should we have an "act as" type link here when editing for multiple users?		
		    $viewProblemPage = $urlpath->new(type => 'problem_detail', args => { courseID => $courseID, setID => $setID, problemID => $problemID });
		    $viewProblemLink = $self->systemLink($viewProblemPage, params => { effectiveUser => ($forOneUser ? $editForUser[0] : $userID)});
		}
		
		
		my $problemFile = $r->param("problem.$problemID.source_file") || $problemRecord->source_file;
		$problemFile =~ s|^/||;
		$problemFile =~ s|\.\.||g;
		# warn of repeat problems
		if (defined $shownYet{$problemFile}) {
		    my $prettyID = $shownYet{$problemFile};
		    $prettyID = join('.',jitar_id_to_seq($prettyID)) if
			$isJitarSet;
		    $repeatFile = $r->maketext("This problem uses the same source file as number [_1].", $prettyID);
		} else {
		    $shownYet{$problemFile} = $problemID;
		    $repeatFile = "";
		}
		
		my $error = $self->checkFile($problemFile, undef);
		my $this_set = $db->getMergedSet($userToShow, $setID);

		my @problem_html;
		if (!$error && $r->param('auto_render')) {
		    @problem_html = renderProblems(
			r=> $r, 
			user => $db->getUser($userToShow),
			displayMode=> $default_problem_mode,
			problem_number=> $problemID,
			this_set => $this_set,
			problem_seed => $forOneUser ? $problemRecord->problem_seed : 0,
			problem_list => [$problemFile],     #  [$problemRecord->source_file],
			);
		}

		# we want to show the "Try It" and "Edit It" links if there's a 
		#    well defined problem to view; this is when we're editing a 
		#    homework set, or if we're editing a gateway set version, or 
		#    if we're editing a gateway set and the problem is not a 
		#    group problem		
		# we also want "grade problem" links for problems which
		# have essay questions.  
		
		my $showLinks = ( ! $isGatewaySet || 
				  ( $editingSetVersion || $problemFile !~ /^group/ ));
		
		my $gradingLink = "";
		if ($showLinks) {
		    
		    if ($problemRecord->flags =~ /essay/) {
			my $gradeProblemPage = $urlpath->new(type => 'instructor_problem_grader', args => { courseID => $courseID, setID => $fullSetID, problemID => $problemID });
			$gradingLink = CGI::a({class=>"pdr_grader", href => $self->systemLink($gradeProblemPage),'data-toggle'=>"tooltip", 'data-placement'=>"top",'data-original-title'=>$r->maketext("Grade Problem")}, $r->maketext("Grade"));
		    }
		    
		}
		
		my $problemNumber = $problemID;
		my $lastProblemNumber = $problemID;
		my $parentID = '';
                my $collapseButton = '';
		if ($isJitarSet) {
		    my @seq = jitar_id_to_seq($problemNumber);
		    $problemNumber = join('.',@seq);
		    $lastProblemNumber = pop @seq;
		    $parentID = seq_to_jitar_id(@seq) if @seq;
                    $collapseButton = CGI::span({class=>"pdr_collapse",
						"data-expand-text"=>$r->maketext("Expand"),
						"data-collapse-text"=>$r->maketext("Collapse")},"");
		}
	
		my $pdr_block_1 =  CGI::div({class=>"pdr_block_1"},
			CGI::start_table({border => 0, cellpadding => 1}) .
			CGI::Tr({}, CGI::td({}, CGI::span({class=>"pdr_handle",id=>"pdr_handle_$problemID",'data-move-text'=>$r->maketext('Move'), 'is-jitar' => $isJitarSet}, $problemNumber).$collapseButton.
					    CGI::input({type=>"hidden", name=>"prob_num_$problemID", id=>"prob_num_$problemID", value=>$lastProblemNumber}).
					    CGI::input({type=>"hidden", name=>"prob_parent_id_$problemID", id=>"prob_parent_id_$problemID", value=>$parentID})) .	      
             	        CGI::Tr({}, CGI::td({}, 
					    CGI::a({href=>"#", class=>"pdr_render", id=>"pdr_render_$problemID",'data-toggle'=>"tooltip", 'data-placement'=>"top",'data-original-title'=>$r->maketext("Render Problem")}, $r->maketext('Render')).
					    ($showLinks ? CGI::a({class=>"psd_edit", href => $editProblemLink, target=>"WW_Editor",'data-toggle'=>"tooltip", 'data-placement'=>"top",'data-original-title'=>$r->maketext("Edit Problem")}, $r->maketext("Edit")) : "")  . 
					    ($showLinks ? CGI::a({class=>"psd_view", href => $viewProblemLink, target=>"WW_View",'data-toggle'=>"tooltip", 'data-placement'=>"top",'data-original-title'=>$r->maketext("Open in New Window")}, $r->maketext("View")) : "") .
					    $gradingLink )). 
			  ($forUsers ? "" : CGI::Tr({}, CGI::td({}, CGI::checkbox({name => "deleteProblem", value => $problemID, label => $r->maketext("Delete it?")})))) .
			  ($forOneUser ? "" : CGI::Tr({}, CGI::td({}, CGI::checkbox({name => "markCorrect", id => "problem.".$problemID.".mark_correct", value => $problemID, label => $r->maketext("Mark Correct?")})))) .
				CGI::end_table()));
		my $pdr_block_2 = CGI::div({class=>"pdr_block_2"}, $self->FieldTable($userToShow, $setID, $problemID, $GlobalProblems{$problemID}, $problemToShow, $setRecord->assignment_type()));

		my @source_file_string = $self->FieldHTML(
						     $userToShow,
						     $setID,
						     $problemID,
						     $GlobalProblems{$problemID}, # pass previously fetched global record to FieldHTML --sam
						     $problemToShow, # pass previously fetched user record to FieldHTML --sam
						     "source_file"
		    );

		$source_file_string[3] = CGI::br().CGI::input({type=>'hidden',id=>"problem_".$problemID."_default_source_file",value=>$GlobalProblems{$problemID}->source_file()}).$source_file_string[3];

		my $pdr_block_3 = CGI::div({class=>"pdr_block_3"}, 
					   join ('',@source_file_string) .
					   CGI::br() .
					   ($repeatFile ? CGI::div({class=>"ResultsWithError", style=>"font-weight: bold"}, $repeatFile) : '') .
					   CGI::div({class=> "psr_render_area", id=>"psr_render_area_$problemID"}, ($error ? CGI::div({class=>"ResultsWithError", style=>"font-weight: bold"}, $error) :  $problem_html[0]->{body_text})
					   ));
		
		push @problemRow, CGI::div({class=>"problem_detail_row"}, 
					   $pdr_block_1.
					   $pdr_block_2.
					   $pdr_block_3 );
	    }
	    
	    
	    # If a jitar set then print nested lists, otherwise print an unordered list. 
	    if ($isJitarSet) {
		my $nestedIDHash = {};

		for (my $i=0; $i<=$#problemIDList; $i++) {
		    my @id_seq = jitar_id_to_seq($problemIDList[$i]);

		    my $hashref = $nestedIDHash;
		    foreach my $num (@id_seq) {
			$hashref->{$num} = {} unless defined $hashref->{$num};
			$hashref = $hashref->{$num};
		    }
		    $hashref->{'row'} = $problemRow[$i];
		    $hashref->{'id'} = $problemIDList[$i];
		}

		# now use recursion to print the nested lists
		print CGI::start_ol({id=>"psd_list", $forUsers ? ('class','disable_renumber') : ()});

		foreach my $id (sort {$a <=> $b} keys %$nestedIDHash) {
		    print_nested_list($nestedIDHash->{$id});
		}
		print CGI::end_ol();

	    } else {
		print CGI::start_ol({id=>"psd_list", $forUsers ? ('class','disable_renumber') : () });
		for (my $i=0; $i<=$#problemIDList; $i++) {
		    print CGI::li({class=>"psd_list_row mjs-nestedSortable-no-nesting", id=>"psd_list_".$problemIDList[$i]} , $problemRow[$i]);
		}
		print CGI::end_ol();
	    }

# print final lines
	    print CGI::checkbox({
		label=> $r->maketext("Automatically render problems on page load"),
		id=>"auto_render", name=>"auto_render", value=>"1", checked=>$r->param('auto_render') ? 1 : ''});
	    
	    print CGI::br();
	    
		print CGI::checkbox({
				  label=> $r->maketext("Force problems to be numbered consecutively from one"),
				  name=>"force_renumber", value=>"1"});
	    print CGI::br();
	} else {
	    print CGI::p(CGI::b($r->maketext("This set doesn't contain any problems yet.")));
	}
	# always allow one to add a new problem, unless we're editing a set version
	if ( ! $editingSetVersion ) {
	    print 	CGI::checkbox({ label=> $r->maketext("Add").' ',
					name=>"add_blank_problem", value=>"1"}
		),CGI::input({
		    name=>"add_n_problems",
		    size=>2,
		    type=>'text',
		    value=>1 },
			     CGI::label($r->maketext("blank problem template(s) to end of homework set"))
		    );
	}
	print CGI::br(),CGI::br(),
	CGI::input({type=>"submit", name=>"submit_changes", id=>"submit_changes_2", value=>$r->maketext("Save Changes")}),
	CGI::input({type=>"submit", name=>"undo_changes", value => $r->maketext("Reset Form")}),
	$r->maketext("(Any unsaved changes will be lost.)");
	
	#my $editNewProblemPage = $urlpath->new(type => 'instructor_problem_editor_withset_withproblem', args => { courseID => $courseID, setID => $setID, problemID =>'new_problem'    });
	#my $editNewProblemLink = $self->systemLink($editNewProblemPage, params => { make_local_copy => 1, file_type => 'blank_problem'  });
    # This next feature isn't fully supported and is causing problems.  Remove for now.  #FIXME
	#print CGI::p( CGI::a({href=>$editNewProblemLink},'Edit'). ' a new blank problem');
	
	print CGI::end_form();
	
	return "";
}

#Tells template to output stylesheet and js for Jquery-UI
sub output_jquery_ui{
	return "";
}

sub output_JS {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $setID   = $r->urlpath->arg("setID");
	my $timezone = $self->{timezone_shortname};
	my $site_url = $ce->{webworkURLs}->{htdocs};

	    print "\n\n<!-- add to header ProblemSetDetail.pm -->";
	print qq!<link rel="stylesheet" media="all" type="text/css" href="$site_url/css/vendor/jquery-ui-themes-1.10.3/themes/smoothness/jquery-ui.css">!,"\n";
	print qq!<link rel="stylesheet" media="all" type="text/css" href="$site_url/css/jquery-ui-timepicker-addon.css">!,"\n";

	print q!<style> 
	.ui-datepicker{font-size:85%} 
	.auto-changed{background-color: #ffffcc} 
	.changed {background-color: #ffffcc}
    </style>!,"\n";

	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/vendor/jquery/modules/jquery.ui.touch-punch.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/DatePicker/jquery-ui-timepicker-addon.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/DatePicker/datepicker.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/AddOnLoad/addOnLoadEvent.js"}), CGI::end_script();
  print "\n";
	# The Base64.js file, which handles base64 encoding and decoding
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/Base64/Base64.js"}), CGI::end_script();
	print qq{
           <link href="$site_url/css/knowlstyle.css" rel="stylesheet" type="text/css" />
           <script type="text/javascript" src="$site_url/js/legacy/vendor/knowl.js"></script>};
	print "\n";
    	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/vendor/jquery/modules/jquery.nestedSortable.js"}), CGI::end_script();
    	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/ProblemSetDetail2/problemsetdetail2.js"}), CGI::end_script();

	print "\n\n<!-- END add to header ProblemSetDetail-->\n\n";
	return "";
}

1;

=head1 AUTHOR

Written by Robert Van Dam, toenail (at) cif.rochester.edu

=cut
