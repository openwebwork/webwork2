#!/usr/bin/env perl

=head1 NAME

dump-past-answers.pl: This script dumps past answers from courses into a CSV
file.

=head1 SYNOPSIS

dump-past-answers.pl [options]

    Options:
        -c|--course          Course from which to dump past answers
        -f|--output-file     CSV file name to dump past answers to
        -h|--help            Show this help

The C<course> option can be repeated multiple times to dump past answers from
multiple courses into the same file.  If no courses are given via this option,
then past answers from all courses will be dumped.

If the C<output-file> option is not given then
C<past-answers-$current_unix_time.csv> will be used for the output file name.

=head1 DESCRIPTION

The CSV file that is generated has the following columns:

ID info

    0 - Answer ID
    1 - Course ID
    2 - Student ID
    3 - Set ID
    4 - Problem ID

User Info

    5 - Permission Level
    6 - User Course Status

Set Info

    7 - Set type
    8 - Open Date (unix time)
    9 - Reduced Scoring Date (unix time)
	10 - Due Date (unix time)
    11 - Answer Date (unix time)
    12 - Final Set Grade (percentage)

Problem Info

    13 - Problem Path
    14 - Problem Value
    15 - Problem Max Attempts
    16 - Problem Seed
    17 - Attempted
    18 - Final Incorrect Attempts
    19 - Final Correct Attempts
    20 - Final Status

OPL Info

    21 - Subject
    22 - Chapter
    23 - Section
    24 - Keywords

Answer Info

    25 - Answer timestamp (unix time)
    26 - Attempt Number
    27 - Raw status of attempt (percentage of correct blanks)
    28 - Number of Answer Blanks
    29/30 etc... - The following columns will come in pairs.  The first will be
                   the text of the answer contained in the answer blank
                   and the second will be the binary 0/1 status of the answer
                   blank.  There will be as many pairs as answer blanks.

=cut

use strict;
use warnings;
use feature 'say';

BEGIN {
	use Mojo::File qw(curfile);
	use Env        qw(WEBWORK_ROOT);
	$WEBWORK_ROOT = curfile->dirname->dirname;
}

use lib "$ENV{WEBWORK_ROOT}/lib";

use Getopt::Long qw(:config bundling);
use Pod::Usage;
use Text::CSV;

use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Utils::CourseManagement qw(listCourses);
use WeBWorK::Utils::Tags;

# Get options.
my @courses;
my $output_file = "past-answers-" . time . ".csv";
my $show_help;
GetOptions('c|course=s' => \@courses, 'f|output-file=s' => \$output_file, 'h|help' => \$show_help);

pod2usage(2) if $show_help;

my $minimal_ce = WeBWorK::CourseEnvironment->new({ webwork_dir => $ENV{WEBWORK_ROOT} });
@courses = listCourses($minimal_ce) unless @courses;

sub write_past_answers_csv {
	my $outFH = shift;

	my $csv = Text::CSV->new({ binary => 1, eol => "\n" }) or die "Cannot use CSV: " . Text::CSV->error_diag();

	# Cache OPL tag data when it is looked up instead of looking up each file every time it appears as the source file
	# for a past answer.  This considerably speeds up this script.
	my %OPL_tag_data;

	for my $courseID (@courses) {
		next if $courseID eq ($minimal_ce->{admin_course_id} // 'admin') || $courseID eq 'modelCourse';

		my $ce = WeBWorK::CourseEnvironment->new({ webwork_dir => $ENV{WEBWORK_ROOT}, courseName => $courseID });
		my $db = WeBWorK::DB->new($ce->{dbLayout});

		my %permissionLabels = reverse %{ $ce->{userRoles} };

		unless (defined $ce && defined $db) {
			warn("Unable to load course environment and database for $courseID");
			next;
		}

		say "Dumping past answers for $courseID";

		# Get all past answers for this course sorted by answer_id and organize them by user, set, and problem.
		my %pastAnswers;
		for ($db->getPastAnswersWhere({}, 'answer_id')) {
			push(@{ $pastAnswers{ $_->user_id }{ $_->set_id }{ $_->problem_id } }, $_);
		}

		my @row;

		$row[1] = $courseID;

		my @users = $db->getUsersWhere({ user_id => { not_like => 'set_id:%' } });

		for my $user (@users) {
			my $userID = $user->user_id;

			$row[2] = $userID;
			$row[5] = $permissionLabels{ $db->getPermissionLevel($userID)->permission };
			$row[6] = $ce->status_abbrev_to_name($user->{status});

			my @sets;
			for ($db->getMergedSetsWhere({ user_id => $userID }, 'set_id')) {
				if (defined $_->assignment_type && $_->assignment_type =~ /gateway/) {
					my $setID    = $_->set_id;
					my @versions = $db->listSetVersions($userID, $setID);
					for my $version (@versions) {
						push(@sets, $db->getUserSet($userID, "$setID,v$version"));
					}
				} else {
					push(@sets, $_);
				}
			}

			for my $set (@sets) {
				my $setID = $set->set_id;

				$row[3]  = $setID;
				$row[7]  = $set->assignment_type;
				$row[8]  = $set->open_date;
				$row[9]  = $set->reduced_scoring_date;
				$row[10] = $set->due_date;
				$row[11] = $set->answer_date;

				my @problems =
					$set->assignment_type =~ /gateway/
					? $db->getMergedProblemVersionsWhere({ user_id => $userID, set_id => $setID }, 'problem_id')
					: $db->getMergedProblemsWhere({ user_id => $userID, set_id => $setID }, 'problem_id');

				# Compute set score
				my $total   = 0;
				my $correct = 0;
				for my $problem (@problems) {
					$total   += $problem->value;
					$correct += $problem->value * $problem->status;
				}
				$row[12] = $total ? $correct / $total : 0;

				for my $problem (@problems) {
					my $problemID = $problem->problem_id;

					$row[4]  = $problemID;
					$row[13] = $problem->source_file;
					$row[14] = $problem->value;
					$row[15] = $problem->max_attempts;
					$row[16] = $problem->problem_seed;
					$row[17] = $problem->attempted;
					$row[18] = $problem->num_incorrect;
					$row[19] = $problem->num_correct;
					$row[20] = $problem->status;

					# Get OPL tag data.
					if ($row[13]) {
						my $file = "$ce->{courseDirs}{templates}/$row[13]";
						$OPL_tag_data{$file} = WeBWorK::Utils::Tags->new($file)
							if !defined $OPL_tag_data{$file} && -e $file;
						if (defined $OPL_tag_data{$file}) {
							$row[21] = $OPL_tag_data{$file}{DBsubject};
							$row[22] = $OPL_tag_data{$file}{DBchapter};
							$row[23] = $OPL_tag_data{$file}{DBsection};
							$row[24] =
								defined($OPL_tag_data{$file}{keywords})
								? join(',', @{ $OPL_tag_data{$file}{keywords} })
								: '';
						}
					}

					my $attempt_number = 0;
					for my $answer (@{ $pastAnswers{$userID}{$setID}{ $problem->problem_id } }) {
						my $answerID = $answer->answer_id;
						++$attempt_number;

						# If the source file for this answer is different from that of the merged user set,
						# then update the row and get the OPL tag data for this file.
						if ($row[13] ne $answer->source_file) {
							$row[13] = $answer->source_file;
							if ($row[13]) {
								my $file = "$ce->{courseDirs}{templates}/$row[13]";
								$OPL_tag_data{$file} = WeBWorK::Utils::Tags->new($file)
									if !defined $OPL_tag_data{$file} && -e $file;
								if (defined $OPL_tag_data{$file}) {
									$row[21] = $OPL_tag_data{$file}{DBsubject};
									$row[22] = $OPL_tag_data{$file}{DBchapter};
									$row[23] = $OPL_tag_data{$file}{DBsection};
									$row[24] =
										defined($OPL_tag_data{$file}{keywords})
										? join(',', @{ $OPL_tag_data{$file}{keywords} })
										: '';
								}
							}
						}

						# Input answer specific info
						$row[0]  = $answerID;
						$row[16] = $answer->problem_seed
							if defined $answer->problem_seed && $answer->problem_seed ne '';
						$row[25] = $answer->timestamp;
						$row[26] = $attempt_number;

						my @scores  = split('',   $answer->scores);
						my @answers = split("\t", $answer->answer_string, -1);

						# Skip answer processing if the number of scores isn't the same as the number of answers.
						next if $#scores != $#answers;

						my $num_blanks = scalar(@scores);

						# Compute the raw status
						my $score = 0;
						for (@scores) { $score += $_ }
						$row[27] = $num_blanks ? $score / $num_blanks : 0;

						$row[28] = $num_blanks;

						for (my $i = 0; $i < $num_blanks; $i++) {
							$row[ 29 + 2 * $i ] = $answers[$i];
							$row[ 30 + 2 * $i ] = $scores[$i];
						}

						$csv->print($outFH, \@row) or warn "Couldn't print row";
					}
				}
			}
		}
	}

	return;
}

say "Dumping answer data to $output_file";
open(my $outFH, '>:encoding(UTF-8)', $output_file) or die("Couldn't open file $output_file");
write_past_answers_csv($outFH);
close($outFH) or die("Couldn't close $output_file");
say 'Done dumping data';
