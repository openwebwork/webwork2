################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader:
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

package WeBWorK::ContentGenerator::Instructor::UserDetail;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::UserDetail - Detailed User specific information

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Utils qw(sortByName x);
use WeBWorK::Debug;

# We use the x function to mark strings for localizaton
use constant DATE_FIELDS => {   open_date    => x("Open:"),
                                reduced_scoring_date => x("Reduced:"),
	                            due_date     => x("Closes:"),
	                            answer_date  => x("Answer:")
};
use constant DATE_FIELDS_ORDER =>[qw(open_date reduced_scoring_date due_date answer_date )];
sub initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $urlpath = $r->urlpath;
	my $db = $r->db;
	my $authz = $r->authz;
	my $userID = $r->param("user");
	my $editForUserID = $urlpath->arg("userID");

	return CGI::div({class => "ResultsWithError"}, "You are not authorized to edit user specific information.")
		unless $authz->hasPermissions($userID, "access_instructor_tools");

	# templates for getting field names
	my $userTemplate = $self->{userTemplate} = $db->newUser;
	my $permissionLevelTemplate = $self->{permissionLevelTemplate} = $db->newPermissionLevel;

	# first check to see if a save form has been submitted
	return '' unless ($r->param('save_button') ||
			  $r->param('assignAll'));

	# As it stands we need to check each set to see if it is still assigned
	# the forms are not currently set up to simply transmit changes

	#Get the list of sets and the global set records
	# DBFIXME shouldn't need set IDs to get records
	my @setIDs = $db->listGlobalSets;
	my @setRecords = grep { defined $_ } $db->getGlobalSets(@setIDs);

	my @assignedSets = ();
	foreach my $setID (@setIDs) {
	    # add sets to the assigned list if the parameter is checked or the
	    # assign all button is pushed.  (already assigned sets will be
	    # skipped later)
	    push @assignedSets, $setID if defined($r->param("set.$setID.assignment"));
	}

	# note: assignedSets are those sets that are assigned in the submitted form
	debug("assignedSets", join(" ", @assignedSets));

	my %selectedSets = map { $_ => 1 } @assignedSets;

	#debug ##########################
		#print STDERR ("aSsigned sets", join(" ",@assignedSets));
        #my @params = $r->param();
        #print STDERR " parameters ", join(" ", @params);
    ###############

	#Get the user(s) whose records are to be modified
	#  for now: $editForUserID
	# check the user exists?  Is this necessary?
	my $editUserRecord = $db->getUser($editForUserID);
	die "record not found for $editForUserID.\n" unless $editUserRecord;

	#Perform the desired assignments or deletions
	my %userSets = map { $_ => 1 } $db->listUserSets($editForUserID);

	# go through each possible set
	debug(" parameters ", join(" ", $r->param()) );
	foreach my $setRecord (@setRecords) {
		my $setID = $setRecord->set_id;
		# does the user want it to be assigned to the selected user
		if (exists $selectedSets{$setID}) {
		    # change by glarose, 2007/02/07: only assign set if the
		    # user doesn't already have the set assigned.
			$self->assignSetToUser($editForUserID, $setRecord) if ( ! $userSets{$setID} );

			#override dates
			my $userSetRecord = $db->getUserSet($editForUserID, $setID);
			# get the dates
			#do checks to see if new dates meet criteria
			my $rh_dates = $self->checkDates($setRecord,$setID);
			unless  ( $rh_dates->{error} ) { #returns 1 if error
				# if no error update database
				foreach my $field (keys %{DATE_FIELDS()}) {
					if (defined $r->param("set.$setID.$field.override")) {
						$userSetRecord->$field($rh_dates->{$field});
					} else {
						$userSetRecord->$field(undef); #stop override
					}
				}
				$db->putUserSet($userSetRecord);
			}

			# if the set is a gateway set, also check to see if we're
			#    resetting the dates for any of the assigned set versions
			if ( $setRecord->assignment_type =~ /gateway/ ) {
				my @setVer = $db->listSetVersions( $editForUserID,
								   $setID );
				foreach my $ver ( @setVer ) {
					my $setVersionRecord =
						$db->getSetVersion( $editForUserID,
								    $setID, $ver );
					my $rh_dates = $self->checkDates($setVersionRecord,
									 "$setID,v$ver");
					unless ( $rh_dates->{error} ) {
						foreach my $field ( keys %{DATE_FIELDS()} ) {
							if ( defined( $r->param("set.$setID,v$ver.$field.override") ) ) {
								$setVersionRecord->$field($rh_dates->{$field});
							} else {
								$setVersionRecord->$field(undef);
							}
						}
						$db->putSetVersion( $setVersionRecord );
					}
				}
			}

		} else {
			# user asked to NOT have the set assigned to the selected user
			# debug("deleteUserSet($editForUserID, $setID)");
		    # change by glarose, 2007/02/07: only do delete if user
		    # had the set previously assigned
			$db->deleteUserSet($editForUserID, $setID) if ( $userSets{$setID} );
			# debug("done deleteUserSet($editForUserID, $setID)");
		}
	}

	return '';



}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $urlpath = $r->urlpath;
	my $db = $r->db;
	my $ce = $r->ce;
	my $authz = $r->authz;
	my $courseID = $urlpath->arg("courseID");
	my $editForUserID = $urlpath->arg("userID");
	my $userID = $r->param("user");

	my @editForSets = $r->param("editForSets");

	return CGI::div({class => "ResultsWithError"}, "You are not authorized to edit user specific information.")
		unless $authz->hasPermissions($userID, "access_instructor_tools");

	my $UserRecord = $db->getUser($editForUserID);
	my $PermissionRecord = $db->getPermissionLevel($editForUserID);
	my @UserSetIDs = $db->listUserSets($editForUserID);

	my $userName = $UserRecord->first_name . " " . $UserRecord->last_name;

	# templates for getting field names
	my $userTemplate = $self->{userTemplate};
	my $permissionLevelTemplate = $self->{permissionLevelTemplate};

	# This table can be consulted when display-ready forms of field names are needed.
	my %prettyFieldNames = map { $_ => $_ }
		$userTemplate->FIELDS();


	my @dateFields         = @{DATE_FIELDS_ORDER()};
	my $rh_dateFieldLabels =  DATE_FIELDS();


	# create a link to the SetsAssignedToUser page
# 	my $editSetsPath = $urlpath->newFromModule(
# 		"WeBWorK::ContentGenerator::Instructor::SetsAssignedToUser", $r,
# 		courseID => $courseID,
# 		userID => $userID,
# 	);
# 	my $editSetsAssignedToUserURL = $self->systemLink($editSetsPath);

	# create a message about how many sets have been assigned to this user
 	my $setCount = $db->countUserSets($editForUserID);
# 	my $userCountMessage =  CGI::a({href=>$editSetsAssignedToUserURL}, $setCount . " sets.");
# 	$userCountMessage = "The user " . CGI::b($userName . " ($editForUserID)") . " has been assigned " . $userCountMessage;
	my $basicInfoPage = $urlpath->new(type =>'instructor_user_list',
					args =>{
						courseID => $courseID,
	                }
	    );
		my $basicInfoUrl = $self->systemLink($basicInfoPage,
		                                     params =>{visible_users => $editForUserID,
		                                               editMode      => 1,
		                                              }
		);

	print CGI::h4({align=>'center'},$r->maketext("Edit")," ",CGI::a({href=>$basicInfoUrl},$r->maketext('class list data'))," ",$r->maketext("for  [_1] ([_2]) who has been assigned [_3] sets.",$userName, $editForUserID, $setCount));


	print CGI::br();

	my $userDetailPage = $urlpath->new(type =>'instructor_user_detail',
					                       args =>{
						                             courseID => $courseID,
						                             userID   => $editForUserID, #FIXME eventually this should be a list??
	                }
	);
	my $userDetailUrl = $self->systemLink($userDetailPage,authen=>0);

	# DBFIXME all we need here is set IDs
	# DBFIXME do sorting in DB
	my %GlobalSetRecords = map { $_->set_id => $_ } $db->getGlobalSets($db->listGlobalSets());
	my @UserSetRefs = map { [$editForUserID, $_] } sortByName(undef, @UserSetIDs);
	my %UserSetRecords = map { $_->set_id => $_ } $db->getUserSets(@UserSetRefs);
	my @MergedSetRefs = map { [$editForUserID, $_] } sortByName(undef, @UserSetIDs);
	my %MergedSetRecords = map { $_->set_id => $_ } $db->getMergedSets(@MergedSetRefs);

	# get set versions of versioned sets
	my %UserSetVersionRecords;
	my %UserSetMergedVersionRecords;
	foreach my $setid ( keys( %UserSetRecords ) ) {
		if ( $GlobalSetRecords{$setid}->assignment_type =~ /gateway/ ) {
			my @setVersionRefs = map { [$editForUserID, $setid, $_] }
				$db->listSetVersions( $editForUserID, $setid );
			if ( @setVersionRefs ) {
				$UserSetVersionRecords{$setid} = [ $db->getSetVersions(@setVersionRefs) ];
				$UserSetMergedVersionRecords{$setid} = [ $db->getMergedSetVersions(@setVersionRefs) ];
			}
		}
	}

	########################################
	# Assigned sets form
	########################################

	print CGI::start_form( {method=>'post',action=>$userDetailUrl, name=>'UserDetail', id=>'UserDetail'}),"\n";
	print $self->hidden_authen_fields();

	print CGI::div(
	    CGI::submit({name=>"assignAll", value => $r->maketext("Assign All Sets to Current User"),
			 onClick => "\$('input[name*=\"assignment\"]').attr('checked',1);"
			})), , CGI::br();


	########################################
	# Print warning
	########################################
	print CGI::div({-class=>'ResultsWithError'},
		       $r->maketext("Do not uncheck a set unless you know what you are doing."),
		       CGI::br(),
		       $r->maketext("There is NO undo for unassigning a set."));

	print CGI::p($r->maketext("To change status (scores or grades) for this student for one set, click on the individual set link."));

	print CGI::div({-class=>'ResultsWithError'},$r->maketext("When you uncheck a homework set (and save the changes), you destroy all of the data for that set for this student.   If you reassign the set, the student will receive a new version of each problem. Make sure this is what you want to do before unchecking sets."));

	print CGI::p(CGI::submit(-name=>'save_button',-label=>$r->maketext('Save changes'),));

	print CGI::start_table({ border=> 1,cellpadding=>5}),"\n";
	print CGI::Tr(
		CGI::th({align=>'center',colspan=>3}, "Sets assigned to $userName ($editForUserID)")
	),"\n";
	print CGI::Tr(
		CGI::th({ -align => "center"}, [
			"Assigned",
			"Edit set for $editForUserID",
			"Dates",
		])
	),"\n";

	# get a list of sets to show
	# DBFIXME already have this data
	my @setsToShow = sortByName( undef, $db->listGlobalSets() );

	# insert any set versions that we have
	if (@setsToShow) {
	  my $i = $#setsToShow;
	  if ( defined( $UserSetVersionRecords{$setsToShow[$i]} ) ) {
	    push( @setsToShow, map{ $_->set_id . ",v" . $_->version_id }
		  @{$UserSetVersionRecords{$setsToShow[$i]}} );
	  }
	  $i--;
	  my $numit = 0;
	  while ( $i>=0 ) {
	    if ( defined( $UserSetVersionRecords{$setsToShow[$i]} ) ) {
	      splice( @setsToShow, $i+1, 0,
		      map{ $_->set_id . ",v" . $_->version_id }
		      @{$UserSetVersionRecords{$setsToShow[$i]}} );
	    }
	    $i--;
	    $numit++;
	    # just to be safe
		last if $numit >= 150;
	  }
	  warn("Truncated display of sets at 150 in UserDetail.pm.  This is a brake to avoid spiraling into the abyss.  If you really have more than 150 sets in your course, reset the limit at about line 370 in webwork/lib/WeBWorK/ContentGenerator/Instructor/UserDetail.pm.") if ( $numit == 150 );
	}

	foreach my $setID ( @setsToShow ) {
		# catch the versioned sets that we just added
		my $setVersion = 0;
		my $fullSetID = $setID;
		if ( $setID =~ /,v(\d+)$/ ) {
			$setVersion = $1;
			$setID =~ s/,v\d+$//;
		}

		my $GlobalSetRecord = $GlobalSetRecords{$setID};
		my $UserSetRecord = (! $setVersion) ? $UserSetRecords{$setID} :
			$UserSetVersionRecords{$setID}->[$setVersion-1];
		my $MergedSetRecord = (! $setVersion) ?  $MergedSetRecords{$setID} :
			$UserSetMergedVersionRecords{$setID}->[$setVersion-1];
		my $setListPage = $urlpath->new(type =>'instructor_set_detail',
					args =>{
						courseID => $courseID,
						setID    => $fullSetID
	                }
		);
		my $url = $self->systemLink($setListPage,
		                      params =>{effectiveUser => $editForUserID,
		                                editForUser   => $editForUserID,
		});

		my $setName = ( $setVersion ) ? "$setID (version $setVersion)" : $setID;

		print CGI::Tr(
			CGI::td({ -align => "center" }, [
				($setVersion) ? "" : CGI::checkbox({ type => 'checkbox',
								name => "set.$fullSetID.assignment",
								label => '',
								value => 'assigned',
								checked => (defined $MergedSetRecord)}),
				defined($MergedSetRecord) ? CGI::b(CGI::a({href=>$url},$setName, ) ) : CGI::b($setID, ),
				join "\n", $self->DBFieldTable($GlobalSetRecord, $UserSetRecord, $MergedSetRecord, "set", $setID, \@dateFields, $rh_dateFieldLabels),
			])
		),"\n";
	}
	print CGI::end_table(),"\n";
	print CGI::p(CGI::submit(-name=>'save_button',-label=>$r->maketext('Save changes'),));
	print CGI::end_form(),"\n";
	########################################
	# Print warning
	########################################

	CGI::div( {class=>'ResultsWithError'},
				"There is NO undo for this function.
				 Do not use it unless you know what you are doing!  When you unassign
				 sets using this button, or by unchecking their set names, you destroy all
				 of the data for those sets for this student."
	);


	return '';
}

sub checkDates {
	my $self         = shift;
	my $setRecord    = shift;
	my $setID        = shift;
	my $r            = $self->r;
	my $ce           = $r->ce;
	my %dates = ();
	my $error_undefined_override = 0;
	my $numerical_date=0;
	my $error        = 0;
	foreach my $field (@{DATE_FIELDS_ORDER()}) {  # check that override dates can be parsed and are not blank
		$dates{$field} = $setRecord->$field;
		if (defined  $r->param("set.$setID.$field.override") &&
		    $r->param("set.$setID.$field") ne ''){
			eval{ $numerical_date = $self->parseDateTime($r->param("set.$setID.$field"))};
			unless( $@  ) {
					$dates{$field}=$numerical_date;
			} else {
					$self->addbadmessage("&nbsp;&nbsp;* Badly defined time for set $setID $field. No date changes made:<br/>$@");
					$error = 1;
			}
		}


	}
	return {%dates,error=>1} if $error;    # no point in going on if the dates can't be parsed.

	my ($open_date, $reduced_scoring_date, $due_date, $answer_date) = map { $dates{$_} } @{DATE_FIELDS_ORDER()};

    unless ($answer_date && $due_date && $open_date) {
    	$self->addbadmessage("set $setID has errors in its dates: answer_date |$answer_date|,
    	 due date |$due_date|, open_date |$open_date|");
	}

	if ($answer_date < $due_date || $answer_date < $open_date) {
		$self->addbadmessage("Answers cannot be made available until on or after the due date in set $setID!");
		$error = 1;
	}

	if ($due_date < $open_date) {
		$self->addbadmessage("Answers cannot be due until on or after the open date in set $setID!");
		$error = 1;
	}

	if ($ce->{pg}{ansEvalDefaults}{enableReducedScoring} &&
	    $setRecord->enable_reduced_scoring &&
	    ($reduced_scoring_date < $open_date || $reduced_scoring_date > $due_date)) {
    		$self->addbadmessage("The reduced scoring date should be between the open date and the due date in set $setID!");
		$error = 1;
}


	# make sure the dates are not more than 10 years in the future
	my $curr_time = time;
	my $seconds_per_year = 31_556_926;
	my $cutoff = $curr_time + $seconds_per_year*10;
	if ($open_date > $cutoff) {
		$self->addbadmessage("Error: open date cannot be more than 10 years from now in set $setID");
		$error = 1;
	}
	if ($due_date > $cutoff) {
		$self->addbadmessage("Error: due date cannot be more than 10 years from now in set $setID");
		$error = 1;
	}
	if ($answer_date > $cutoff) {
		$self->addbadmessage("Error: answer date cannot be more than 10 years from now in set $setID");
		$error = 1;
	}


	if ($error) {
		$self->addbadmessage("No date changes were saved!");
	}
	return {%dates,error=>$error};
}

sub DBFieldTable {
	my ($self, $GlobalRecord, $UserRecord, $MergedRecord, $recordType,
	    $recordID, $fieldsRef, $rh_fieldLabels) = @_;

	return CGI::div({class => "ResultsWithError"}, "No record exists for $recordType $recordID") unless defined $GlobalRecord;

	# modify record name if we're dealing with versioned sets
	my $isVersioned = 0;
	if ( $recordType eq "set" && defined($MergedRecord) &&
	     $MergedRecord->assignment_type =~ /gateway/ &&
	     $MergedRecord->can( "version_id" ) ) {
		$recordID .= ",v" . $MergedRecord->version_id;
		$isVersioned = 1;
	}
	my $r = $self->r;
        my $ce = $r->ce;
	my @fields = @$fieldsRef;
	my @results;
	foreach my $field (@fields) {
                #Skip reduced credit dates for sets which don't have them
	        next unless ($field ne 'reduced_scoring_date' ||
			     ($ce->{pg}{ansEvalDefaults}{enableReducedScoring} &&
			      $GlobalRecord->enable_reduced_scoring));

		my $globalValue = $GlobalRecord->$field;
		my $userValue = defined $UserRecord ? $UserRecord->$field : $globalValue;
		my $mergedValue  = defined $MergedRecord ? $MergedRecord->$field : $globalValue;

		push @results,
			[$r->maketext($rh_fieldLabels->{$field}).' ',
			 defined $UserRecord ?
				CGI::checkbox({
					type => "checkbox",
					name => "$recordType.$recordID.$field.override",
					id => "$recordType.$recordID.$field.override_id",
					label => "",
					value => $field,
					checked => ($r->param("$recordType.$recordID.$field.override") || $mergedValue ne $globalValue || ($isVersioned && $field ne 'reduced_scoring_date')) ? 1 : 0
				}) : "",
				defined $UserRecord ?
					(CGI::input({
							name => "$recordType.$recordID.$field",
							id => "$recordType.$recordID.${field}_id",
							type => "text",
							value => $userValue ? $self->formatDateTime($userValue,'','%m/%d/%Y at %I:%M%P') : "",
							onchange => "\$('input[id=\"$recordType.$recordID.$field.override_id\"]').prop('checked', this.value != '')",
							onkeyup => "\$('input[id=\"$recordType.$recordID.$field.override_id\"]').prop('checked', this.value != '')",
							placeholder => x("None Specified"),
							onblur => "if (this.value == '') \$('input[id=\"$recordType.$recordID.$field.override_id\"]').prop('checked',false);",
							size => 25,
							class => $field eq "open_date" ? "datepicker-group" : "",
							data_enable_datepicker => $ce->{options}{useDateTimePicker}
						})
					) : "",
				$self->formatDateTime($globalValue,'','%m/%d/%Y at %I:%M%P'),
			]

	}

	my @table;
	foreach my $row (@results) {
		push @table, CGI::Tr(CGI::td({-align => "center"}, $row));
	}

	return CGI::start_table({class => 'UserDetail-date-table', border=> 0}), @table, CGI::end_table();
}

#Tells template to output stylesheet and js for Jquery-UI
sub output_jquery_ui{
	return "";
}

sub output_JS {
	my $self = shift;
	my $site_url = $self->r->ce->{webworkURLs}{htdocs};

	# Print javaScript and style for dateTimePicker	
	print CGI::Link({ rel => "stylesheet",  href => "$site_url/css/jquery-ui-timepicker-addon.css" });
	print CGI::Link({ rel => "stylesheet",  href => "$site_url/js/apps/DatePicker/datepicker.css" });
	print CGI::script({ src => "$site_url/js/apps/DatePicker/jquery-ui-timepicker-addon.js", defer => undef }, "");
	print CGI::script({ src => "$site_url/js/apps/DatePicker/datepicker.js", defer => undef}, "");

	return "";

}

1;
