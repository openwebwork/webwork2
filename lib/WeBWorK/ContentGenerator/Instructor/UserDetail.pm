################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::UserDetail - Detailed User specific information

=cut

use WeBWorK::Utils qw(x);
use WeBWorK::Utils::Instructor qw(assignSetToUser);
use WeBWorK::DB::Utils qw(grok_versionID_from_vsetID_sql);
use WeBWorK::Debug;

# We use the x function to mark strings for localizaton
use constant DATE_FIELDS => {
	open_date            => x('Open:'),
	reduced_scoring_date => x('Reduced:'),
	due_date             => x('Closes:'),
	answer_date          => x('Answer:')
};
use constant DATE_FIELDS_ORDER => [qw(open_date reduced_scoring_date due_date answer_date )];

sub initialize ($c) {
	my $db = $c->db;

	# Make these available in the templates.
	$c->stash->{fields}      = DATE_FIELDS_ORDER();
	$c->stash->{fieldLabels} = DATE_FIELDS();

	return unless $c->authz->hasPermissions($c->param('user'), 'access_instructor_tools');

	my $editForUserID = $c->stash('userID');

	# Get the user whose records are to be modified.
	$c->{userRecord} = $db->getUser($editForUserID);
	return unless $c->{userRecord};

	# Get the list of sets and the global set records and cache them for later use.  This list is sorted by set_id.
	$c->{setRecords} = [ $db->getGlobalSetsWhere({}, 'set_id') ];

	# Check to see if a save form has been submitted
	if ($c->param('save_button') || $c->param('assignAll')) {
		# Check each set to see if it is still assigned.
		my @assignedSets;
		for my $set (@{ $c->{setRecords} }) {
			# Add sets to the assigned list if the parameter is checked or the assign all button is pushed.  (Already
			# assigned sets will be skipped later.)
			my $setID = $set->set_id;
			push @assignedSets, $setID if defined $c->param("set.$setID.assignment");
		}

		# note: assignedSets are those sets that are assigned in the submitted form
		debug('assignedSets', join(' ', @assignedSets));

		my %selectedSets = map { $_ => 1 } @assignedSets;

		# Perform the desired assignments or deletions
		my %userSets = map { $_ => 1 } $db->listUserSets($editForUserID);

		# Go through each possible set
		debug(' parameters ', join(' ', $c->param()));
		for my $setRecord (@{ $c->{setRecords} }) {
			my $setID = $setRecord->set_id;
			# Does the user want this set to be assigned to the selected user?
			if (exists $selectedSets{$setID}) {
				# Assign the set if it isn't assigned already.
				assignSetToUser($db, $editForUserID, $setRecord) if (!$userSets{$setID});

				# Override dates
				my $userSetRecord = $db->getUserSet($editForUserID, $setID);

				# Check to see if new dates meet criteria
				my $rh_dates = $c->checkDates($setRecord, $setID);
				unless ($rh_dates->{error}) {
					# If no error update database
					for my $field (@{ DATE_FIELDS_ORDER() }) {
						if (defined $c->param("set.$setID.$field.override")) {
							$userSetRecord->$field($rh_dates->{$field});
						} else {
							$userSetRecord->$field(undef);    #stop override
						}
					}
					$db->putUserSet($userSetRecord);
				}

				# If the set is a gateway set, also check to see if we're resetting the dates for any of the assigned
				# set versions, or if a version is to be deleted.
				if ($setRecord->assignment_type =~ /gateway/) {
					my @setVer =
						$db->getSetVersionsWhere({ user_id => $editForUserID, set_id => { like => "$setID,v\%" } });
					for my $setVersionRecord (@setVer) {
						my $ver    = $setVersionRecord->version_id;
						my $action = $c->param("set.$setID,v$ver.assignment");
						if (defined $action) {
							if ($action eq 'assigned') {
								# This version is not to be deleted.
								# Check to see if we're resetting the dates for this version.
								my $rh_dates = $c->checkDates($setVersionRecord, "$setID,v$ver");
								unless ($rh_dates->{error}) {
									for my $field (@{ DATE_FIELDS_ORDER() }) {
										if (defined($c->param("set.$setID,v$ver.$field.override"))) {
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
	}

	# Get the rest of the information from the database that is needed for this user.
	# This must be done after saving so that the updated data is obtained.

	# Create a hash of set ids to set records, and a hash of set ids to merged set records for this user.
	$c->{userSetRecords} =
		{ map { $_->set_id => $_ }
			$db->getUserSetsWhere({ user_id => $editForUserID, set_id => { not_like => '%,v%' } }) };
	$c->{mergedSetRecords} = { map { $_->set_id => $_ } $db->getMergedSetsWhere({ user_id => $editForUserID }) };

	# Get all versions and merged versions for gateway sets.
	for my $set (@{ $c->{setRecords} }) {
		next unless $set->assignment_type =~ /gateway/;
		my $setID = $set->set_id;

		$c->{setVersions}{$setID} = [
			$db->getSetVersionsWhere(
				{ user_id => $editForUserID, set_id => { like => "$setID,v\%" } }, 'version_id'
			)
		];
		$c->{mergedVersions}{$setID} = [
			$db->getMergedSetVersionsWhere(
				{ user_id => $editForUserID, set_id => { like => "$setID,v\%" } },
				\grok_versionID_from_vsetID_sql($db->{set_version_merged}->sql->_quote('set_id'))
			)
		];
	}

	return;
}

sub checkDates ($c, $setRecord, $setID) {
	my $error = 0;

	# For each of the dates, use the override date if set.  Otherwise use the value from the global set.
	my %dates;
	for my $field (@{ DATE_FIELDS_ORDER() }) {
		$dates{$field} =
			(defined $c->param("set.$setID.$field.override") && $c->param("set.$setID.$field") ne '')
			? $c->param("set.$setID.$field")
			: $setRecord->$field;
	}

	my ($open_date, $reduced_scoring_date, $due_date, $answer_date) = map { $dates{$_} } @{ DATE_FIELDS_ORDER() };

	unless ($answer_date && $due_date && $open_date) {
		$c->addbadmessage("set $setID has errors in its dates: answer_date |$answer_date|, "
				. "due date |$due_date|, open_date |$open_date|");
		$error = 1;
	}

	if ($answer_date < $due_date || $answer_date < $open_date) {
		$c->addbadmessage("Answers cannot be made available until on or after the due date in set $setID!");
		$error = 1;
	}

	if ($due_date < $open_date) {
		$c->addbadmessage("Answers cannot be due until on or after the open date in set $setID!");
		$error = 1;
	}

	if ($c->ce->{pg}{ansEvalDefaults}{enableReducedScoring}
		&& $setRecord->enable_reduced_scoring
		&& ($reduced_scoring_date < $open_date || $reduced_scoring_date > $due_date))
	{
		$c->addbadmessage("The reduced scoring date should be between the open date and the due date in set $setID!");
		$error = 1;
	}

	# Make sure the dates are not more than 10 years in the future.
	my $cutoff = time + 31_556_926 * 10;
	if ($open_date > $cutoff) {
		$c->addbadmessage("Error: open date cannot be more than 10 years from now in set $setID");
		$error = 1;
	}
	if ($due_date > $cutoff) {
		$c->addbadmessage("Error: due date cannot be more than 10 years from now in set $setID");
		$error = 1;
	}
	if ($answer_date > $cutoff) {
		$c->addbadmessage("Error: answer date cannot be more than 10 years from now in set $setID");
		$error = 1;
	}

	$c->addbadmessage('No date changes were saved!') if ($error);

	return { %dates, error => $error };
}

1;
