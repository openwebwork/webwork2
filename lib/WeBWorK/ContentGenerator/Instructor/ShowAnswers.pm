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

package WeBWorK::ContentGenerator::Instructor::ShowAnswers;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures, -async_await;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ShowAnswers.pm  -- display past answers of students

=cut

use Text::CSV;
use Mojo::File;

use WeBWorK::Utils::JITAR qw(jitar_id_to_seq prob_id_sort);
use WeBWorK::Utils::Rendering qw(renderPG);

use constant PAST_ANSWERS_FILENAME => 'past_answers';

async sub initialize ($c) {
	my $db   = $c->db;
	my $ce   = $c->ce;
	my $user = $c->param('user');

	unless ($c->authz->hasPermissions($user, 'view_answers')) {
		$c->addbadmessage(q{You aren't authorized to view past answers});
		return;
	}

	# The stop acting button doesn't perform a submit action and so these extra parameters are passed so that if an
	# instructor stops acting the current studentID, setID and problemID will be maintained.
	$c->{extraStopActingParams}{selected_users}    = $c->param('selected_users');
	$c->{extraStopActingParams}{selected_sets}     = $c->param('selected_sets');
	$c->{extraStopActingParams}{selected_problems} = $c->param('selected_problems');

	my $selectedUsers    = [ $c->param('selected_users') ]    // [];
	my $selectedSets     = [ $c->param('selected_sets') ]     // [];
	my $selectedProblems = [ $c->param('selected_problems') ] // [];

	my $instructor = $c->authz->hasPermissions($user, 'access_instructor_tools');

	# If not instructor then force table to use current user-id
	$selectedUsers = [$user] if !$instructor;

	return unless $selectedUsers && $selectedSets && $selectedProblems;

	my %records;
	my %prettyProblemNumbers;
	my %fallbackAnswerTypes;

	for my $studentUser (@$selectedUsers) {
		my @sets;

		# search for selected sets assigned to students
		my @allSets = $db->listUserSets($studentUser);
		for my $setName (@allSets) {
			my $set = $db->getMergedSet($studentUser, $setName);
			if (defined($set->assignment_type) && $set->assignment_type =~ /gateway/) {
				my @versions = $db->listSetVersions($studentUser, $setName);
				for my $version (@versions) {
					if (grep {/^$setName,v$version$/} @$selectedSets) {
						$set = $db->getUserSet($studentUser, "$setName,v$version");
						push(@sets, $set);
					}
				}
			} elsif (grep {/^$setName$/} @$selectedSets) {
				push(@sets, $set);
			}

		}

		next unless @sets;

		for my $setRecord (@sets) {
			my @problemNumbers;
			my $setName    = $setRecord->set_id;
			my $isJitarSet = (defined($setRecord->assignment_type) && $setRecord->assignment_type eq 'jitar') ? 1 : 0;

			# search for matching problems
			my @allProblems = $db->listUserProblems($studentUser, $setName);
			next unless @allProblems;
			for my $problemNumber (@allProblems) {
				my $prettyProblemNumber = $problemNumber;
				if ($isJitarSet) {
					$prettyProblemNumber = join('.', jitar_id_to_seq($problemNumber));
				}
				$prettyProblemNumbers{$setName}{$problemNumber} = $prettyProblemNumber;

				if (grep {/^$prettyProblemNumber$/} @$selectedProblems) {
					push(@problemNumbers, $problemNumber);
				}
			}

			next unless @problemNumbers;

			for my $problemNumber (@problemNumbers) {
				my @pastAnswers = $db->getPastAnswersWhere(
					{ user_id => $studentUser, set_id => $setName, problem_id => $problemNumber }, 'answer_id');
				next unless @pastAnswers;

				# Get answer types from the user problem.
				my $problem;
				if ($setRecord->assignment_type =~ /gateway/) {
					my ($unversionedSetID, $versionID) = $setName =~ /^([^,]*),v(\d*)$/;
					$problem =
						$db->getMergedProblemVersion($studentUser, $unversionedSetID, $versionID, $problemNumber);
				} else {
					$problem = $db->getMergedProblem($studentUser, $setName, $problemNumber);
				}
				# If a problem was not found for this user, then it doesn't make sense to show past answers.
				next unless defined $problem;

				my @answerTypes;
				# If $problem->flags ends in a comma, then this is the old type of flags value without answer types.
				@answerTypes = split(',', $problem->flags =~ s/:needs_grading$//r)
					if $problem->flags && $problem->flags !~ /,$/;

				# If the answer types were not saved in the flags for this user, then render the user's problem to
				# figure out what type the answers are.  This is usually only the case for the old type of flags value,
				# which means this is a course restored from a course archive from a previous version of webwork2.
				if (!@answerTypes) {
					if (!defined $fallbackAnswerTypes{$setName}{$problemNumber}) {
						my $set;
						if ($setName =~ /,v[0-9]*$/) {
							my ($unversionedSetID, $versionID) = $setName =~ /^([^,]*),v(\d*)$/;
							$set = $db->getMergedSetVersion($studentUser, $unversionedSetID, $versionID);
						} else {
							$set = $db->getMergedSet($studentUser, $setName);
						}
						my $userRecord = $db->getUser($studentUser);

						next unless defined $set && defined $userRecord;

						my $pg = await renderPG(
							$c,
							$userRecord,
							$set, $problem,
							$set->psvn,
							{},
							{    # translation options
								displayMode              => 'plainText',
								processAnswers           => 1,
								showHints                => 0,
								showSolutions            => 0,
								refreshMath2img          => 0,
								permissionLevel          => 0,
								effectivePermissionLevel => 0,
							},
						);

						for (@{ $pg->{flags}{ANSWER_ENTRY_ORDER} // [] }) {
							push(
								@{ $fallbackAnswerTypes{$setName}{$problemNumber} },
								$pg->{PG_ANSWERS_HASH}{$_}{rh_ans}{type} // 'undefined'
							);
						}
					}
					@answerTypes = @{ $fallbackAnswerTypes{$setName}{$problemNumber} }
						if defined $fallbackAnswerTypes{$setName}{$problemNumber};
				}

				for my $pastAnswer (@pastAnswers) {
					$records{$studentUser}{$setName}{$problemNumber}{ $pastAnswer->answer_id } = {
						time        => $pastAnswer->timestamp,
						seed        => $pastAnswer->problem_seed,
						answers     => [ split(/\t/, $pastAnswer->answer_string) ],
						answerTypes => \@answerTypes,
						scores      => [ split(//, $pastAnswer->scores) ],
						comment     => $pastAnswer->comment_string // ''
					};
				}
			}
		}
	}

	$c->stash->{records}              = \%records;
	$c->stash->{prettyProblemNumbers} = \%prettyProblemNumbers;

	# Prepare a csv if we are an instructor
	if ($instructor && $c->param('createCSV')) {
		my $filename     = PAST_ANSWERS_FILENAME;
		my $scoringDir   = $ce->{courseDirs}->{scoring};
		my $fullFilename = "${scoringDir}/${filename}.csv";
		if (-e $fullFilename) {
			my $i = 1;
			while (-e "${scoringDir}/${filename}_bak$i.csv") { $i++; }    #don't overwrite existing backups
			my $bakFileName = "${scoringDir}/${filename}_bak$i.csv";
			rename $fullFilename, $bakFileName or warn "Unable to rename $filename to $bakFileName";
		}

		$filename .= '.csv';

		if (my $fh = Mojo::File->new($fullFilename)->open('>:encoding(UTF-8)')) {

			my $csv = Text::CSV->new({ eol => "\n" });
			my @columns;

			$columns[0] = $c->maketext('User ID');
			$columns[1] = $c->maketext('Set ID');
			$columns[2] = $c->maketext('Problem Number');
			$columns[3] = $c->maketext('Timestamp');
			$columns[4] = $c->maketext('Scores');
			$columns[5] = $c->maketext('Answers');
			$columns[6] = $c->maketext('Comment');

			$csv->print($fh, \@columns);

			for my $studentID (sort keys %records) {
				$columns[0] = $studentID;
				for my $setID (sort keys %{ $records{$studentID} }) {
					$columns[1] = $setID;
					for my $probNum (sort { $a <=> $b } keys %{ $records{$studentID}{$setID} }) {
						$columns[2] = $prettyProblemNumbers{$setID}{$probNum};
						for my $answerID (sort { $a <=> $b } keys %{ $records{$studentID}{$setID}{$probNum} }) {
							my %record = %{ $records{$studentID}{$setID}{$probNum}{$answerID} };

							$columns[3] = $c->formatDateTime($record{time});
							$columns[4] = join(',',  @{ $record{scores} });
							$columns[5] = join("\t", @{ $record{answers} });
							$columns[6] = $record{comment};

							$csv->print($fh, \@columns);
						}
					}
				}
			}

			$fh->close;
		} else {
			$c->log->warn("Unable to open $fullFilename for writing");
		}
	}

	return;
}

sub getInstructorData ($c) {
	my $db   = $c->db;
	my $ce   = $c->ce;
	my $user = $c->param('user');

	# Get all users except the set level proctors, and restrict to the sections or recitations that are allowed for
	# the user if such restrictions are defined.
	my @users = $db->getUsersWhere({
		user_id => { not_like => 'set_id:%' },
		$ce->{viewable_sections}{$user} || $ce->{viewable_recitations}{$user}
		? (
			-or => [
				$ce->{viewable_sections}{$user}    ? (section    => $ce->{viewable_sections}{$user})    : (),
				$ce->{viewable_recitations}{$user} ? (recitation => $ce->{viewable_recitations}{$user}) : ()
			]
			)
		: ()
	});

	my @GlobalSets = $db->getGlobalSetsWhere({}, 'set_id');

	my @expandedGlobalSetIDs;

	# Process global sets, and find the maximum number of versions for all users for each gateway set.
	for my $globalSet (@GlobalSets) {
		my $setName = $globalSet->set_id;
		if ($globalSet->assignment_type && $globalSet->assignment_type =~ /gateway/) {
			my $maxVersions = 0;
			for my $user (@users) {
				my $versions = $db->countSetVersions($user->user_id, $setName);
				$maxVersions = $versions if ($versions > $maxVersions);
			}
			if ($maxVersions) {
				for (my $i = 1; $i <= $maxVersions; $i++) {
					push @expandedGlobalSetIDs, "$setName,v$i";
				}
			}
		} else {
			push @expandedGlobalSetIDs, $setName;
		}
	}

	@expandedGlobalSetIDs = sort @expandedGlobalSetIDs;

	my %all_problems;

	# Determine which problems to show.
	for my $globalSet (@GlobalSets) {
		my @problems = $db->listGlobalProblems($globalSet->set_id);
		if ($globalSet->assignment_type && $globalSet->assignment_type eq 'jitar') {
			@problems = map { join('.', jitar_id_to_seq($_)) } @problems;
		}

		@all_problems{@problems} = (1) x @problems;
	}

	return (
		users                => \@users,
		expandedGlobalSetIDs => \@expandedGlobalSetIDs,
		globalProblemIDs     => [ prob_id_sort keys %all_problems ],
		filename             => PAST_ANSWERS_FILENAME . '.csv'
	);
}

1;
