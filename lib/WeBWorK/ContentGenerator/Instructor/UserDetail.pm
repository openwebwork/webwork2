################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
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

	return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
		"You are not authorized to edit user specific information.")
		unless $authz->hasPermissions($userID, "access_instructor_tools");

	# Get the list of sets and the global set records and cache them for later use.  This list is sorted by set_id.
	$self->{setRecords} = [ $db->getGlobalSetsWhere({}, 'set_id') ];

	# first check to see if a save form has been submitted
	return '' unless ($r->param('save_button') ||
			  $r->param('assignAll'));

	# As it stands we need to check each set to see if it is still assigned
	# the forms are not currently set up to simply transmit changes

	my @assignedSets = ();
	foreach my $set (@{ $self->{setRecords} }) {
	    # add sets to the assigned list if the parameter is checked or the
	    # assign all button is pushed.  (already assigned sets will be
	    # skipped later)
		my $setID = $set->set_id;
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

	# Perform the desired assignments or deletions
	my %userSets = map { $_ => 1 } $db->listUserSets($editForUserID);

	# Go through each possible set
	debug(" parameters ", join(" ", $r->param()) );
	for my $setRecord (@{ $self->{setRecords} }) {
		my $setID = $setRecord->set_id;
		# Does the user want this set to be assigned to the selected user?
		if (exists $selectedSets{$setID}) {
			# Assign the set if it isn't assigned already.
			$self->assignSetToUser($editForUserID, $setRecord) if (!$userSets{$setID});

			# Override dates
			my $userSetRecord = $db->getUserSet($editForUserID, $setID);

			# Check to see if new dates meet criteria
			my $rh_dates = $self->checkDates($setRecord, $setID);
			unless ($rh_dates->{error}) {
				# If no error update database
				for my $field (keys %{ DATE_FIELDS() }) {
					if (defined $r->param("set.$setID.$field.override")) {
						$userSetRecord->$field($rh_dates->{$field});
					} else {
						$userSetRecord->$field(undef);    #stop override
					}
				}
				$db->putUserSet($userSetRecord);
			}

			# If the set is a gateway set, also check to see if we're resetting the dates for any of the assigned set
			# versions, or if a version is to be deleted.
			if ($setRecord->assignment_type =~ /gateway/) {
				my @setVer =
					$db->getSetVersionsWhere({ user_id => $editForUserID, set_id => { like => "$setID,v\%" } });
				for my $setVersionRecord (@setVer) {
					my $ver = $setVersionRecord->version_id;
					my $action = $r->param("set.$setID,v$ver.assignment");
					if (defined $action) {
						if ($action eq 'assigned') {
							# This version is not to be deleted.
							# Check to see if we're resetting the dates for this version.
							my $rh_dates = $self->checkDates($setVersionRecord, "$setID,v$ver");
							unless ($rh_dates->{error}) {
								for my $field (keys %{ DATE_FIELDS() }) {
									if (defined($r->param("set.$setID,v$ver.$field.override"))) {
										$setVersionRecord->$field($rh_dates->{$field});
									} else {
										$setVersionRecord->$field(undef);
									}
								}
								$db->putSetVersion($setVersionRecord);
							}
						} elsif ($action eq 'delete') {
							# Delete this version.
							$db->deleteSetVersion($editForUserID, $setID, $ver);
						}
					}
				}
			}
		} else {
			# The user asked to NOT have the set assigned to the selected user.
			# Delete the set if set was previously assigned.
			$db->deleteUserSet($editForUserID, $setID) if ($userSets{$setID});
		}
	}

	return '';
}

sub body {
	my ($self)        = @_;
	my $r             = $self->r;
	my $urlpath       = $r->urlpath;
	my $db            = $r->db;
	my $ce            = $r->ce;
	my $authz         = $r->authz;
	my $courseID      = $urlpath->arg("courseID");
	my $editForUserID = $urlpath->arg("userID");
	my $userID        = $r->param("user");

	my @editForSets = $r->param("editForSets");

	return CGI::div({ class => 'alert alert-danger p-1' }, "You are not authorized to edit user specific information.")
		unless $authz->hasPermissions($userID, "access_instructor_tools");

	my $UserRecord       = $db->getUser($editForUserID);

	my $userName = $UserRecord->first_name . " " . $UserRecord->last_name;

	# create a message about how many sets have been assigned to this user
	my $setCount = $db->countUserSets($editForUserID);
	my $basicInfoPage = $urlpath->new(
		type => 'instructor_user_list',
		args => {
			courseID => $courseID,
		}
	);
	my $basicInfoUrl = $self->systemLink(
		$basicInfoPage,
		params => {
			visible_users => $editForUserID,
			editMode      => 1,
		}
	);

	print CGI::div(
		{ class => 'text-center my-3' },
		CGI::h2(
			{ class => 'fs-6' },
			$r->maketext(
				"Edit [_1] for  [_2] ([_3]) who has been assigned [_4] sets.",
				CGI::a({ href => $basicInfoUrl }, $r->maketext('class list data')),
				$userName, $editForUserID, $setCount
			)
		)
	);

	my $userDetailPage = $urlpath->new(
		type => 'instructor_user_detail',
		args => {
			courseID => $courseID,
			userID   => $editForUserID,    #FIXME eventually this should be a list??
		}
	);
	my $userDetailUrl = $self->systemLink($userDetailPage, authen => 0);

	########################################
	# Assigned sets form
	########################################

	print CGI::start_form({ method => 'post', action => $userDetailUrl, name => 'UserDetail', id => 'UserDetail' });
	print $self->hidden_authen_fields();

	print CGI::div(
		{ class => 'mb-2' },
		CGI::submit({
			name  => 'assignAll',
			value => $r->maketext('Assign All Sets to Current User'),
			class => 'btn btn-primary'
		})
	);

	# Print warning
	print CGI::div(
		{ class => 'alert alert-danger p-1 mb-2' },
		CGI::div({ class => 'mb-1' }, $r->maketext('Do not uncheck a set unless you know what you are doing.')),
		CGI::div($r->maketext('There is NO undo for unassigning a set.'))
	);
	print CGI::div(
		{ class => 'fs-6 mb-2' },
		$r->maketext(
			'To change status (scores or grades) for this student for one set, click on the individual set link.')
	);
	print CGI::div(
		{ class => 'alert alert-danger p-1 fs-6 mb-2' },
		$r->maketext(
			'When you uncheck a homework set (and save the changes), you destroy all of the data for that set for '
				. 'this student.   If you reassign the set, the student will receive a new version of each problem. '
				. 'Make sure this is what you want to do before unchecking sets.'
		)
	);

	print CGI::div(
		{ class => 'mb-2' },
		CGI::submit({
			name  => 'save_button',
			label => $r->maketext('Save changes'),
			class => 'btn btn-primary'
		})
	);

	print CGI::div({ class => 'table-responsive' });
	print CGI::start_table({ class => 'table table-bordered table-sm font-sm align-middle' });
	print CGI::Tr(CGI::th({ class => 'text-center', colspan => 3 }, "Sets assigned to $userName ($editForUserID)"));
	print CGI::Tr(CGI::th({ class => 'text-center' }, [ 'Assigned', "Edit set for $editForUserID", 'Dates', ]));

	my %UserSetRecords =
		map { $_->set_id => $_ } $db->getUserSetsWhere({ user_id => $editForUserID, set_id => { not_like => '%,v%' } });
	my %MergedSetRecords = map { $_->set_id => $_ } $db->getMergedSetsWhere({ user_id => $editForUserID });

	for my $set (@{ $self->{setRecords} }) {
		my $setID = $set->set_id;

		$self->outputSetRow($set, $UserSetRecords{$setID}, $MergedSetRecords{$setID});

		if ($set->assignment_type =~ /gateway/) {
			my @setVersions =
				$db->getSetVersionsWhere({ user_id => $editForUserID, set_id => { like => "$setID,v\%" } },
					'version_id');
			my @mergedVersions =
				$db->getMergedSetVersionsWhere({ user_id => $editForUserID, set_id => { like => "$setID,v\%" } },
					\"(SUBSTRING(set_id,INSTR(set_id,',v')+2)+0)");
			$self->outputSetRow($set, $setVersions[$_], $mergedVersions[$_], $setVersions[$_]->version_id)
				for (0 .. $#setVersions);
		}
	}

	print CGI::end_table(), CGI::end_div();

	print CGI::submit({
		name  => 'save_button',
		label => $r->maketext('Save changes'),
		class => 'btn btn-primary'
	});

	print CGI::end_form();

	# Print warning
	print CGI::div(
		{ class => 'alert alert-danger p-1 mt-3' },
		'There is NO undo for this function. '
			. 'Do not use it unless you know what you are doing!  When you unassign '
			. 'sets by unchecking set names and clicking save, you destroy all '
			. 'of the data for those sets for this student.'
	);

	return '';
}

sub outputSetRow {
	my ($self, $set, $userSet, $mergedSet, $version) = @_;

	my $urlpath       = $self->r->urlpath;
	my $courseID      = $urlpath->arg('courseID');
	my $editForUserID = $urlpath->arg('userID');
	my $setID         = $set->set_id;

	my $dateFields      = DATE_FIELDS_ORDER();
	my $dateFieldLabels = DATE_FIELDS();

	print CGI::Tr(CGI::td(
		{ align => 'center' },
		[
			CGI::checkbox({
				type            => 'checkbox',
				name            => $version ? "set.$setID,v$version.assignment" : "set.$setID.assignment",
				label           => '',
				value           => 'assigned',
				checked         => defined $mergedSet,
				class           => 'form-check-input',
				labelattributes => { class => 'form-check-label' }
			}),
			defined($mergedSet)
			? CGI::b(CGI::a(
				{
					href => $self->systemLink(
						$urlpath->new(
							type => 'instructor_set_detail',
							args => {
								courseID => $courseID,
								setID    => $setID . ($version ? ",v$version" : '')
							}
						),
						params => {
							effectiveUser => $editForUserID,
							editForUser   => $editForUserID,
						}
					)
				},
				$version ? "$setID (version $version)" : $setID
			))
				. ($version ? CGI::hidden({ name => "set.$setID,v$version.assignment", value => 'delete' }) : '')
			: CGI::b($setID),
			join '',
			$self->DBFieldTable($set, $userSet, $mergedSet, 'set', $setID, $dateFields, $dateFieldLabels),
		]
	));
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
	my ($self, $GlobalRecord, $UserRecord, $MergedRecord, $recordType, $recordID, $fieldsRef, $rh_fieldLabels) = @_;

	return CGI::div({ class => 'alert alert-danger p-1 mb-0' }, "No record exists for $recordType $recordID")
		unless defined $GlobalRecord;

	# modify record name if we're dealing with versioned sets
	my $isVersioned = 0;
	if ($recordType eq 'set'
		&& defined($MergedRecord)
		&& $MergedRecord->assignment_type =~ /gateway/
		&& $MergedRecord->can('version_id'))
	{
		$recordID .= ',v' . $MergedRecord->version_id;
		$isVersioned = 1;
	}
	my $r      = $self->r;
	my $ce     = $r->ce;
	my @fields = @$fieldsRef;
	my @results;
	for my $field (@fields) {
		#Skip reduced credit dates for sets which don't have them
		next
			unless $field ne 'reduced_scoring_date'
			|| ($ce->{pg}{ansEvalDefaults}{enableReducedScoring} && $GlobalRecord->enable_reduced_scoring);

		my $globalValue = $GlobalRecord->$field;
		my $userValue   = defined $UserRecord   ? $UserRecord->$field   : $globalValue;
		my $mergedValue = defined $MergedRecord ? $MergedRecord->$field : $globalValue;

		push @results,
			[
				$r->maketext($rh_fieldLabels->{$field}) . ' ',
				defined $UserRecord
				? CGI::checkbox({
					type    => 'checkbox',
					name    => "$recordType.$recordID.$field.override",
					id      => "$recordType.$recordID.$field.override_id",
					label   => '',
					value   => $field,
					checked => $r->param("$recordType.$recordID.$field.override")
					|| $mergedValue ne $globalValue
					|| ($isVersioned && $field ne 'reduced_scoring_date'),
					class           => 'form-check-input',
					labelattributes => { class => 'form-check-label' }
				})
				: '',
				defined $UserRecord
				? CGI::div(
					{ class => 'input-group input-group-sm flex-nowrap flatpickr' },
					CGI::input({
						name          => "$recordType.$recordID.$field",
						id            => "$recordType.$recordID.${field}_id",
						type          => 'text',
						value         => $userValue ? $self->formatDateTime($userValue, '', '%m/%d/%Y at %I:%M%P') : '',
						data_override => "$recordType.$recordID.$field.override_id",
						placeholder   => x('None Specified'),
						class         => 'form-control w-auto' . ($field eq 'open_date' ? ' datepicker-group' : ''),
						data_enable_datepicker => $ce->{options}{useDateTimePicker},
						data_input             => undef,
						data_done_text         => $self->r->maketext('Done')
					}),
					CGI::a(
						{ class => 'btn btn-secondary btn-sm', data_toggle => undef },
						CGI::i({ class => 'fas fa-calendar-alt' }, '')
					)
				)
				: '',
				$self->formatDateTime($globalValue, '', '%m/%d/%Y at %I:%M%P'),
			];
	}

	my @table;
	for my $row (@results) {
		push @table, CGI::Tr(CGI::td({ class => 'px-1 text-nowrap' }, $row));
	}

	return CGI::table({ class => 'UserDetail-date-table' }, @table);
}

#Tells template to output stylesheet and js for Jquery-UI
sub output_jquery_ui{
	return "";
}

sub output_JS {
	my $self = shift;
	my $site_url = $self->r->ce->{webworkURLs}{htdocs};

	# Print javascript and style for the flatpickr date/time picker.
	print CGI::Link({ rel => 'stylesheet', href => "$site_url/node_modules/flatpickr/dist/flatpickr.min.css" });
	print CGI::Link(
		{ rel => 'stylesheet', href => "$site_url/node_modules/flatpickr/dist/plugins/confirmDate/confirmDate.css" });
	print CGI::script({ src => "$site_url/node_modules/flatpickr/dist/flatpickr.min.js", defer => undef }, '');
	print CGI::script(
		{ src => "$site_url/node_modules/flatpickr/dist/plugins/confirmDate/confirmDate.js", defer => undef }, '');
	print CGI::script({ src => "$site_url/js/apps/DatePicker/datepicker.js", defer => undef }, '');

	# Add javascript specifically for this module.
	print CGI::script({ src => "$site_url/js/apps/UserDetail/userdetail.js", defer => undef }, '');

	return '';

}

1;
