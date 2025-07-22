package WeBWorK::File::SetDef;
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

WeBWorK::File::SetDef - utilities for dealing with set definition files.

=cut

use Carp;

use WeBWorK::Debug;
use WeBWorK::Utils             qw(x);
use WeBWorK::Utils::DateTime   qw(formatDateTime getDefaultSetDueDate parseDateTime timeToSec);
use WeBWorK::Utils::Files      qw(surePathToFile);
use WeBWorK::Utils::Instructor qw(assignSetToUser assignSetToAllUsers addProblemToSet);
use WeBWorK::Utils::JITAR      qw(seq_to_jitar_id jitar_id_to_seq);
use WeBWorK::Utils::Sets       qw(format_set_name_display);

our @EXPORT_OK = qw(importSetsFromDef readSetDef exportSetsToDef);

use constant DATE_FORMAT => '%m/%d/%Y at %I:%M%P %Z';

=head2 importSetsFromDef

Usage: C<importSetsFromDef($ce, $db, $setDefFiles, $newSetName, $existingSets, $assign, $startDate)>

Import requested set definition files into the course.

$ce must be a course environment object and $db a database object for the
course.

$setDefFiles must be a reference to an array of set definition file names with
path relative to the course templates directory.

$existingSets must be a reference to an array containing set ids of existing
sets in the course if provided.  If it is not provided, then the list of
existing sets will be obtained from the database.

$assign is either 'all', a user id for a particular user to assign the imported
sets to, or something that evaluates to false.  If it evaluates to false the
imported sets will not be assigned to any users.

$startDate is a date to shift the set dates relative to.

$newSetName is an optional name for the imported set.  This can only be passed
when one set is begin imported.

This returns a reference to an array of set ids of added sets, a reference to an
array of set ids of skipped sets, and a reference to an array of errors that
occurred in the process.  Note that each entry in the array of errors is a
reference to an array whose contents are suitable to be passed directly to
maketext.

=cut

sub importSetsFromDef ($ce, $db, $setDefFiles, $existingSets = undef, $assign = '', $startDate = 0, $newSetName = '') {
	my $minDate = 0;

	# Restrict to filenames that contain at least one non-whitespace character.
	my @setDefFiles = grep {/\S/} @$setDefFiles;

	croak '$newSetName should not be passed when importing multiple set definitions files.'
		if $newSetName && @setDefFiles > 1;

	# Get the list of existing sets for the course if that was not provided.
	$existingSets = [ $db->listGlobalSets ] unless (ref($existingSets) eq 'ARRAY');

	# Get a list of set ids of existing sets in the course.  This is used to
	# ensure that an imported set does not already exist.
	my %allSets = map { $_ => 1 } @$existingSets;

	my (@added, @skipped, @errors);

	for my $set_definition_file (@setDefFiles) {
		debug("$set_definition_file: reading set definition file");

		# Read the data from the set definition file.
		my ($setData, $readErrors) = readSetDef($ce, $set_definition_file);
		push(@errors, @$readErrors) if @$readErrors;

		# Use the original name if a new name was not specified.
		$setData->{setID} = $newSetName if $newSetName;

		my $prettySetID = format_set_name_display($setData->{setID});

		if ($allSets{ $setData->{setID} }) {
			# This set already exists!
			push @skipped, $setData->{setID};
			push @errors,  [ x('The set [_1] already exists.', $prettySetID) ];
			next;
		}

		# Keep track of which as the earliest open date.
		if ($minDate > $setData->{openDate} || $minDate == 0) {
			$minDate = $setData->{openDate};
		}

		debug("$set_definition_file: adding set");
		# Add the data to the set record
		my $newSetRecord = $db->newGlobalSet;
		$newSetRecord->set_id($setData->{setID});
		$newSetRecord->set_header($setData->{screenHeaderFile});
		$newSetRecord->hardcopy_header($setData->{paperHeaderFile});
		$newSetRecord->open_date($setData->{openDate});
		$newSetRecord->due_date($setData->{dueDate});
		$newSetRecord->answer_date($setData->{answerDate});
		$newSetRecord->visible(1);
		$newSetRecord->reduced_scoring_date($setData->{reducedScoringDate});
		$newSetRecord->enable_reduced_scoring($setData->{enableReducedScoring});
		$newSetRecord->description($setData->{description});
		$newSetRecord->email_instructor($setData->{emailInstructor});
		$newSetRecord->restrict_prob_progression($setData->{restrictProbProgression});

		# Gateway/version data.  These are all initialized to '' by readSetDef.
		# So for non-gateway/versioned sets they'll just be stored as NULL.
		$newSetRecord->assignment_type($setData->{assignmentType});
		$newSetRecord->attempts_per_version($setData->{attemptsPerVersion});
		$newSetRecord->time_interval($setData->{timeInterval});
		$newSetRecord->versions_per_interval($setData->{versionsPerInterval});
		$newSetRecord->version_time_limit($setData->{versionTimeLimit});
		$newSetRecord->problem_randorder($setData->{problemRandOrder});
		$newSetRecord->problems_per_page($setData->{problemsPerPage});
		$newSetRecord->hide_score($setData->{hideScore});
		$newSetRecord->hide_score_by_problem($setData->{hideScoreByProblem});
		$newSetRecord->hide_work($setData->{hideWork});
		$newSetRecord->time_limit_cap($setData->{capTimeLimit});
		$newSetRecord->restrict_ip($setData->{restrictIP});
		$newSetRecord->relax_restrict_ip($setData->{relaxRestrictIP});

		# Create the set
		eval { $db->addGlobalSet($newSetRecord) };
		if ($@) {
			push @skipped, $setData->{setID};
			push @errors,  [ x('Error creating set [_1]: [_2]'), $prettySetID, $@ ];
			next;
		}

		push @added, $setData->{setID};

		# Add locations to the set_locations table
		if ($setData->{restrictIP} ne 'No' && $setData->{restrictLocation}) {
			if ($db->existsLocation($setData->{restrictLocation})) {
				if (!$db->existsGlobalSetLocation($setData->{setID}, $setData->{restrictLocation})) {
					my $newSetLocation = $db->newGlobalSetLocation;
					$newSetLocation->set_id($setData->{setID});
					$newSetLocation->location_id($setData->{restrictLocation});
					eval { $db->addGlobalSetLocation($newSetLocation) };
					if ($@) {
						push
							@errors,
							[
								x('Error adding IP restriction location "[_1]" for set [_2]: [_3]'),
								$setData->{restrictLocation},
								$prettySetID, $@
							];
					}
				} else {
					# This should never happen.
					push
						@errors,
						[
							x('IP restriction location "[_1]" for set [_2] already exists.'),
							$setData->{restrictLocation}, $prettySetID
						];
				}
			} else {
				push
					@errors,
					[
						x(
							'IP restriction location "[_1]" for set [_2] does not exist. '
							. 'IP restrictions have been ignored.'
						),
						$setData->{restrictLocation},
						$prettySetID
					];
				$newSetRecord->restrict_ip('No');
				$newSetRecord->relax_restrict_ip('No');
				eval { $db->putGlobalSet($newSetRecord) };
				# Ignore error messages here. If the set was added without error before,
				# we assume (ha) that it will be added again without trouble.
			}
		}

		debug("$set_definition_file: adding problems to database");
		# Add problems
		my $freeProblemID = WeBWorK::Utils::max(grep {$_} map { $_->{problem_id} } @{ $setData->{problemData} }) + 1;
		for my $rh_problem (@{ $setData->{problemData} }) {
			addProblemToSet(
				$db, $ce->{problemDefaults},
				setName           => $setData->{setID},
				sourceFile        => $rh_problem->{source_file},
				problemID         => $rh_problem->{problem_id} || $freeProblemID++,
				value             => $rh_problem->{value},
				maxAttempts       => $rh_problem->{max_attempts},
				showMeAnother     => $rh_problem->{showMeAnother},
				showHintsAfter    => $rh_problem->{showHintsAfter},
				prPeriod          => $rh_problem->{prPeriod},
				attToOpenChildren => $rh_problem->{attToOpenChildren},
				countsParentGrade => $rh_problem->{countsParentGrade}
			);
		}

		if ($assign eq 'all') {
			assignSetToAllUsers($db, $ce, $setData->{setID});
		} elsif ($assign) {
			assignSetToUser($db, $assign, $newSetRecord);
		}
	}

	# If there is a start date we have to reopen all of the sets that were added and shift the dates.
	if ($startDate) {
		# The shift for all of the dates is from the min date to the start date
		my $dateShift = $startDate - $minDate;

		for my $setID (@added) {
			my $setRecord = $db->getGlobalSet($setID);
			$setRecord->open_date($setRecord->open_date + $dateShift);
			$setRecord->reduced_scoring_date($setRecord->reduced_scoring_date + $dateShift);
			$setRecord->due_date($setRecord->due_date + $dateShift);
			$setRecord->answer_date($setRecord->answer_date + $dateShift);
			$db->putGlobalSet($setRecord);
		}
	}

	return \@added, \@skipped, \@errors;
}

=head2 readSetDef

Usage: C<readSetDef($ce, $fileName)>

Read and parse a set definition file.

$ce must be a course environment object for the course.

$filename should be the set definition file with path relative to the course
templates directory.

Returns a reference to a hash containing the information from the set definition
file and a reference to an array of errors in the file.  See C<%data> and
C<%data{problemData}> for details on the contents of the return set definition
file data.  Also note that each entry in the array of errors is a reference to
an array whose contents are suitable to be passed directly to maketext.

=cut

sub readSetDef ($ce, $fileName) {
	my $filePath = "$ce->{courseDirs}{templates}/$fileName";

	my %data = (
		setID                   => 'Invalid Set Definition Filename',
		problemData             => [],
		paperHeaderFile         => '',
		screenHeaderFile        => '',
		openDate                => '',
		dueDate                 => '',
		answerDate              => '',
		reducedScoringDate      => '',
		assignmentType          => 'default',
		enableReducedScoring    => '',
		attemptsPerVersion      => '',
		timeInterval            => '',
		versionsPerInterval     => '',
		versionTimeLimit        => '',
		problemRandOrder        => '',
		problemsPerPage         => '',
		hideScore               => 'N',
		hideScoreByProblem      => 'N',
		hideWork                => 'N',
		capTimeLimit            => 0,
		restrictIP              => 'No',
		restrictLocation        => '',
		relaxRestrictIP         => 'No',
		description             => '',
		emailInstructor         => '',
		restrictProbProgression => ''
	);

	my @errors;

	$data{setID} = $2 if ($fileName =~ m|^(.*/)?set([.\w-]+)\.def$|);

	if (my $setFH = Mojo::File->new($filePath)->open('<')) {
		my $listType = '';

		# Read and check set data
		while (my $line = <$setFH>) {
			chomp $line;
			$line =~ s|(#.*)||;                 # Don't read past comments
			unless ($line =~ /\S/) { next; }    # Skip blank lines
			$line =~ s/^\s*|\s*$//;             # Trim spaces
			$line =~ m|^(\w+)\s*=?\s*(.*)|;

			my $item  = $1 // '';
			my $value = $2;

			if ($item eq 'setNumber') {
				next;
			} elsif (defined $data{$item}) {
				$data{$item} = $value if defined $value;
			} elsif ($item eq 'problemList' || $item eq 'problemListV2') {
				$listType = $item;
				last;
			} else {
				push(@errors, [ x('Invalid line in file "[_1]": ||[_2]||'), $fileName, $line ]);
			}
		}

		# Change <n>'s to new lines in the set description.
		$data{description} =~ s/<n>/\n/g;

		# Check and format dates
		for (qw(openDate dueDate answerDate)) {
			$data{$_} = eval { parseDateTime($data{$_}, $ce->{siteDefaults}{timezone}) };
			push(@errors, [ x('Invalid [_1] in file: [_2]', $_, $@) ]) if $@;
		}

		unless (defined $data{openDate}
			&& defined $data{dueDate}
			&& defined $data{answerDate}
			&& $data{openDate} <= $data{dueDate}
			&& $data{dueDate} <= $data{answerDate})
		{
			$data{dueDate}  = getDefaultSetDueDate($ce) unless defined $data{dueDate};
			$data{openDate} = $data{dueDate} - 60 * $ce->{pg}{assignOpenPriorToDue}
				if !defined $data{openDate} || $data{openDate} > $data{dueDate};
			$data{answerDate} = $data{dueDate} + 60 * $ce->{pg}{answersOpenAfterDueDate}
				if !defined $data{answerDate} || $data{dueDate} > $data{answerDate};

			push(
				@errors,
				[
					x(
						'The open date, due date, and answer date in "[_1]" are not in chronological order. '
							. 'Default values will be used for dates that are out of order.'
					),
					$fileName
				]
			);
		}

		if ($data{enableReducedScoring} eq 'Y') {
			$data{enableReducedScoring} = 1;
		} elsif ($data{enableReducedScoring} eq 'N') {
			$data{enableReducedScoring} = 0;
		} elsif ($data{enableReducedScoring} ne '') {
			push(
				@errors,
				[
					x('The value for enableReducedScoring in "[_1]" is not valid. It will be replaced with "N".'),
					$fileName
				]
			);
			$data{enableReducedScoring} = 0;
		} else {
			$data{enableReducedScoring} = 0;
		}

		# Validate reduced scoring date
		if ($data{reducedScoringDate}) {
			if ($data{reducedScoringDate} =~ m+12/31/1969+ || $data{reducedScoringDate} =~ m+01/01/1970+) {
				# Set the reduced scoring date to 0 for values which seem to roughly correspond to epoch 0.
				$data{reducedScoringDate} = 0;
			} else {
				$data{reducedScoringDate} =
					eval { parseDateTime($data{reducedScoringDate}, $ce->{siteDefaults}{timezone}) };
				push(@errors, [ x('Invalid date format for set [_1] in file: [_2]', 'reducedScoringDate', $@) ]) if $@;
			}
		}

		if ($data{reducedScoringDate}) {
			if ($data{reducedScoringDate} < $data{openDate} || $data{reducedScoringDate} > $data{dueDate}) {
				$data{reducedScoringDate} = $data{dueDate} - 60 * $ce->{pg}{ansEvalDefaults}{reducedScoringPeriod};

				# If reduced scoring is enabled for the set, then add an error regarding this issue.
				# Otherwise let it go.
				if ($data{enableReducedScoring}) {
					push(
						@errors,
						[
							x(
								'The reduced credit date in "[_1]" is not between the open date and close date. '
									. 'The default value will be used.'
							),
							$fileName
						]
					);
				}
			}
		} else {
			$data{reducedScoringDate} = $data{dueDate} - 60 * $ce->{pg}{ansEvalDefaults}{reducedScoringPeriod};
		}

		# Convert Gateway times into seconds.
		$data{timeInterval}     = timeToSec($data{timeInterval})     if ($data{timeInterval});
		$data{versionTimeLimit} = timeToSec($data{versionTimeLimit}) if ($data{versionTimeLimit});

		# Check that the values for hideScore and hideWork are valid.
		for (qw(hideScore hideWork)) {
			if ($data{$_} ne 'N' && $data{$_} ne 'Y' && $data{$_} ne 'BeforeAnswerDate') {
				push(
					@errors,
					[
						x('The value for the [_1] option in "[_2]" is not valid. It will be replaced with "N".'),
						$_, $fileName
					]
				);
				$data{$_} = 'N';
			}
		}

		if ($data{hideScoreByProblem} ne 'N' && $data{hideScoreByProblem} ne 'Y') {
			push(
				@errors,
				[
					x(
						'The value for the hideScoreByProblem option in "[_1]" is not valid. '
							. 'It will be replaced with "N".',
						$fileName
					)
				]
			);
			$data{hideScoreByProblem} = 'N';
		}

		if ($data{capTimeLimit} ne '0' && $data{capTimeLimit} ne '1') {
			push(
				@errors,
				[
					x(
						'The value for the capTimeLimit option in "[_1]" is not valid. It will be replaced with "0".'),
					$fileName
				]
			);
			$data{capTimeLimit} = '0';
		}

		if ($data{restrictIP} ne 'No' && $data{restrictIP} ne 'DenyFrom' && $data{restrictIP} ne 'RestrictTo') {
			push(
				@errors,
				[
					x('The value for the restrictIP option in "[_1]" is not valid. It will be replaced with "No".'),
					$fileName
				]
			);
			$data{restrictIP}       = 'No';
			$data{restrictLocation} = '';
			$data{relaxRestrictIP}  = 'No';
		}

		if ($data{relaxRestrictIP} ne 'No'
			&& $data{relaxRestrictIP} ne 'AfterAnswerDate'
			&& $data{relaxRestrictIP} ne 'AfterVersionAnswerDate')
		{
			push(
				@errors,
				[
					x(
						'The value for the relaxRestrictIP option in "[_1]" is not valid. '
							. 'It will be replaced with "No".'
					),
					$fileName
				]
			);
			$data{relaxRestrictIP} = 'No';
		}

		# Validation of restrictLocation requires a database call. That is deferred until the set is added.

		# Read and check list of problems for the set

		# NOTE: There are two versions of problemList, the first is an unlabeled list which may or may not contain some
		# newer variables.  This is supported but the unlabeled list is hard to work with.  The new version prints a
		# labeled list of values similar to how its done for the set variables.

		if ($listType eq 'problemList') {
			# The original set definition file type.
			while (my $line = <$setFH>) {
				chomp $line;
				$line =~ s/(#.*)//;                 # Don't read past comments
				unless ($line =~ /\S/) { next; }    # Skip blank lines

				# Commas are valid in filenames, so we have to handle commas
				# using backslash escaping. So \X will be replaced with X.
				my @line = ();
				my $curr = '';
				for (my $i = 0; $i < length $line; ++$i) {
					my $c = substr($line, $i, 1);
					if ($c eq '\\') {
						$curr .= substr($line, ++$i, 1);
					} elsif ($c eq ',') {
						push @line, $curr;
						$curr = '';
					} else {
						$curr .= $c;
					}
				}
				# Anything left?
				push(@line, $curr) if ($curr);

				# Exract the problem data from the line.
				my ($name, $weight, $attemptLimit, $showMeAnother) = @line;

				# Clean up problem values
				$name =~ s/\s*//g;

				$weight //= '';
				$weight =~ s/[^\d\.]*//g;
				unless ($weight =~ /\d+/) { $weight = $ce->{problemDefaults}{value}; }

				$attemptLimit //= '';
				$attemptLimit =~ s/[^\d-]*//g;
				unless ($attemptLimit =~ /\d+/) { $attemptLimit = $ce->{problemDefaults}{max_attempts}; }

				push(
					@{ $data{problemData} },
					{
						source_file   => $name,
						value         => $weight,
						max_attempts  => $attemptLimit,
						showMeAnother => $showMeAnother // $ce->{problemDefaults}{showMeAnother},
						# Use defaults for these since they are not going to be in the file.
						prPeriod       => $ce->{problemDefaults}{prPeriod},
						showHintsAfter => $ce->{problemDefaults}{showHintsAfter},
					}
				);
			}
		} else {
			# Set definition version 2.
			my $problemData = {};
			while (my $line = <$setFH>) {
				chomp $line;
				$line =~ s|#.*||;                   # Don't read past comments
				unless ($line =~ /\S/) { next; }    # Skip blank lines
				$line =~ s/^\s*|\s*$//g;            # Trim spaces
				$line =~ m|^(\w+)\s*=?\s*(.*)|;

				my $item  = $1 // '';
				my $value = $2;

				if ($item eq 'problem_start') {
					# Initialize the problem data with the defaults.
					$problemData = { source_file => '', problem_id => '', %{ $ce->{problemDefaults} } };
				} elsif (defined $problemData->{$item}) {
					$problemData->{$item} = $value if defined $value;
				} elsif ($item eq 'problem_end') {
					# Clean up and validate values
					push(@errors, [ 'No source_file for problem in "[_1]"', $fileName ])
						unless $problemData->{source_file};

					$problemData->{value} =~ s/[^\d\.]*//g;
					$problemData->{value} = $ce->{problemDefaults}{value}
						unless $problemData->{value} =~ /\d+/;

					$problemData->{max_attempts} =~ s/[^\d-]*//g;
					$problemData->{max_attempts} = $ce->{problemDefaults}{max_attempts}
						unless $problemData->{max_attempts} =~ /\d+/;

					$problemData->{counts_parent_grade} = $ce->{problemDefaults}{counts_parent_grade}
						unless $problemData->{counts_parent_grade} =~ /(0|1)/;
					$problemData->{counts_parent_grade} =~ s/[^\d]*//g;

					$problemData->{showMeAnother} = $ce->{problemDefaults}{showMeAnother}
						unless $problemData->{showMeAnother} =~ /-?\d+/;
					$problemData->{showMeAnother} =~ s/[^\d-]*//g;

					$problemData->{showHintsAfter} = $ce->{problemDefaults}{showHintsAfter}
						unless $problemData->{showHintsAfter} =~ /-?\d+/;
					$problemData->{showHintsAfter} =~ s/[^\d-]*//g;

					$problemData->{prPeriod} = $ce->{problemDefaults}{prPeriod}
						unless $problemData->{prPeriod} =~ /-?\d+/;
					$problemData->{prPeriod} =~ s/[^\d-]*//g;

					$problemData->{att_to_open_children} = $ce->{problemDefaults}{att_to_open_children}
						unless ($problemData->{att_to_open_children} =~ /\d+/);
					$problemData->{att_to_open_children} =~ s/[^\d-]*//g;

					if ($data{assignmentType} eq 'jitar') {
						unless ($problemData->{problem_id} =~ /[\d\.]+/) { $problemData->{problem_id} = ''; }
						$problemData->{problem_id} =~ s/[^\d\.-]*//g;
						$problemData->{problem_id} = seq_to_jitar_id(split(/\./, $problemData->{problem_id}));
					} else {
						unless ($problemData->{problem_id} =~ /\d+/) { $problemData->{problem_id} = ''; }
						$problemData->{problem_id} =~ s/[^\d-]*//g;
					}

					push(@{ $data{problemData} }, $problemData);
				} else {
					push(@errors, [ x('Invalid line in file "[_1]": ||[_2]||'), $fileName, $line ]);
				}
			}
		}

		$setFH->close;
	} else {
		push @errors, [ x(q{Can't open file [_1]}, $filePath) ];
	}

	return (\%data, \@errors);
}

=head2 exportSetsToDef

Usage: C<exportSetsToDef($ce, $db, @filenames)>

Export sets to set definition files.

$ce must be a course environment object and $db a database object for the
course.

@filenames is a list of set ids for the sets to be exported.

=cut

sub exportSetsToDef ($ce, $db, @sets) {
	my (@exported, @skipped, %reason);

SET: for my $set (@sets) {
		my $fileName = "set$set.def";

		# Files can be exported to sub directories but not parent directories.
		if ($fileName =~ /\.\./) {
			push @skipped, $set;
			$reason{$set} = [ x(q{Illegal filename contains '..'}) ];
			next SET;
		}

		my $setRecord = $db->getGlobalSet($set);
		unless (defined $setRecord) {
			push @skipped, $set;
			$reason{$set} = [ x('No record found.') ];
			next SET;
		}
		my $filePath = "$ce->{courseDirs}{templates}/$fileName";

		# Back up existing file
		if (-e $filePath) {
			rename($filePath, "$filePath.bak")
				or do {
					push @skipped, $set;
					$reason{$set} = [ x('Existing file [_1] could not be backed up.'), $filePath ];
					next SET;
				};
		}

		# These dates cannot be created in locale of the course language and need to be in the specified format.  The
		# set import method uses the WeBWorK::Utils::parseDateTime method which does not know how to parse dates in
		# other locales than the hard coded old format.  Furthermore, even modern libraries that parse date/time strings
		# claim not to be able to do so reliably when they are localized.
		my $openDate   = formatDateTime($setRecord->open_date,   DATE_FORMAT(), $ce->{siteDefaults}{timezone}, 'en-US');
		my $dueDate    = formatDateTime($setRecord->due_date,    DATE_FORMAT(), $ce->{siteDefaults}{timezone}, 'en-US');
		my $answerDate = formatDateTime($setRecord->answer_date, DATE_FORMAT(), $ce->{siteDefaults}{timezone}, 'en-US');
		my $reducedScoringDate =
			formatDateTime($setRecord->reduced_scoring_date, DATE_FORMAT(), $ce->{siteDefaults}{timezone}, 'en-US');

		my $description = ($setRecord->description // '') =~ s/\r?\n/<n>/gr;

		my $assignmentType          = $setRecord->assignment_type;
		my $enableReducedScoring    = $setRecord->enable_reduced_scoring ? 'Y' : 'N';
		my $setHeader               = $setRecord->set_header;
		my $paperHeader             = $setRecord->hardcopy_header;
		my $emailInstructor         = $setRecord->email_instructor;
		my $restrictProbProgression = $setRecord->restrict_prob_progression;

		my @problemList = $db->getGlobalProblemsWhere({ set_id => $set }, 'problem_id');

		my $problemList = '';
		for my $problemRecord (@problemList) {
			my $problem_id = $problemRecord->problem_id();

			$problem_id = join('.', jitar_id_to_seq($problem_id)) if ($setRecord->assignment_type eq 'jitar');

			my $source_file       = $problemRecord->source_file();
			my $value             = $problemRecord->value();
			my $max_attempts      = $problemRecord->max_attempts();
			my $showMeAnother     = $problemRecord->showMeAnother();
			my $showHintsAfter    = $problemRecord->showHintsAfter();
			my $prPeriod          = $problemRecord->prPeriod();
			my $countsParentGrade = $problemRecord->counts_parent_grade();
			my $attToOpenChildren = $problemRecord->att_to_open_children();

			# backslash-escape commas in fields
			$source_file    =~ s/([,\\])/\\$1/g;
			$value          =~ s/([,\\])/\\$1/g;
			$max_attempts   =~ s/([,\\])/\\$1/g;
			$showMeAnother  =~ s/([,\\])/\\$1/g;
			$showHintsAfter =~ s/([,\\])/\\$1/g;
			$prPeriod       =~ s/([,\\])/\\$1/g;

			# This is the new way of saving problem information.
			# The labelled list makes it easier to add variables and
			# easier to tell when they are missing.
			$problemList .= "problem_start\n";
			$problemList .= "problem_id           = $problem_id\n";
			$problemList .= "source_file          = $source_file\n";
			$problemList .= "value                = $value\n";
			$problemList .= "max_attempts         = $max_attempts\n";
			$problemList .= "showMeAnother        = $showMeAnother\n";
			$problemList .= "showHintsAfter       = $showHintsAfter\n";
			$problemList .= "prPeriod             = $prPeriod\n";
			$problemList .= "counts_parent_grade  = $countsParentGrade\n";
			$problemList .= "att_to_open_children = $attToOpenChildren\n";
			$problemList .= "problem_end\n";
		}

		# Gateway fields
		my $gwFields = '';
		if ($assignmentType =~ /gateway/) {
			my $attemptsPerV       = $setRecord->attempts_per_version;
			my $timeInterval       = $setRecord->time_interval;
			my $vPerInterval       = $setRecord->versions_per_interval;
			my $vTimeLimit         = $setRecord->version_time_limit;
			my $probRandom         = $setRecord->problem_randorder;
			my $probPerPage        = $setRecord->problems_per_page;
			my $hideScore          = $setRecord->hide_score;
			my $hideScoreByProblem = $setRecord->hide_score_by_problem;
			my $hideWork           = $setRecord->hide_work;
			my $timeCap            = $setRecord->time_limit_cap;
			$gwFields =
				"attemptsPerVersion      = $attemptsPerV\n"
				. "timeInterval            = $timeInterval\n"
				. "versionsPerInterval     = $vPerInterval\n"
				. "versionTimeLimit        = $vTimeLimit\n"
				. "problemRandOrder        = $probRandom\n"
				. "problemsPerPage         = $probPerPage\n"
				. "hideScore               = $hideScore\n"
				. "hideScoreByProblem      = $hideScoreByProblem\n"
				. "hideWork                = $hideWork\n"
				. "capTimeLimit            = $timeCap\n";
		}

		# IP restriction fields
		my $restrictIP     = $setRecord->restrict_ip;
		my $restrictFields = '';
		if ($restrictIP && $restrictIP ne 'No') {
			# Only store the first location
			my $restrictLoc   = ($db->listGlobalSetLocations($setRecord->set_id))[0];
			my $relaxRestrict = $setRecord->relax_restrict_ip;
			$restrictLoc || ($restrictLoc = '');
			$restrictFields =
				"restrictIP              = $restrictIP\n"
				. "restrictLocation        = $restrictLoc\n"
				. "relaxRestrictIP         = $relaxRestrict\n";
		}

		my $fileContents =
			"assignmentType          = $assignmentType\n"
			. "openDate                = $openDate\n"
			. "reducedScoringDate      = $reducedScoringDate\n"
			. "dueDate                 = $dueDate\n"
			. "answerDate              = $answerDate\n"
			. "enableReducedScoring    = $enableReducedScoring\n"
			. "paperHeaderFile         = $paperHeader\n"
			. "screenHeaderFile        = $setHeader\n"
			. $gwFields
			. "description             = $description\n"
			. "restrictProbProgression = $restrictProbProgression\n"
			. "emailInstructor         = $emailInstructor\n"
			. $restrictFields
			. "\nproblemListV2\n"
			. $problemList;

		$filePath = surePathToFile($ce->{courseDirs}->{templates}, $filePath);
		if (open(my $setDefFH, '>:encoding(UTF-8)', $filePath)) {
			print $setDefFH $fileContents;
			close $setDefFH;
			push @exported, $set;
		} else {
			push @skipped, $set;
			$reason{$set} = [ x('Failed to open [_1]'), $filePath ];
		}
	}

	return \@exported, \@skipped, \%reason;
}

1;
