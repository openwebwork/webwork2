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

package WeBWorK::ContentGenerator::ProblemSets;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::ProblemSets - Display a list of built problem sets.

=cut

use WeBWorK::Debug;
use WeBWorK::Utils qw(after readFile sortByName path_is_subdir is_restricted format_set_name_display);
use WeBWorK::Localize;

# What do we consider a "recent" problem set?
use constant RECENT => 2 * 7 * 24 * 60 * 60;    # Two-Weeks in seconds

# The "default" data in the course_info.txt file.
use constant DEFAULT_COURSE_INFO_TXT =>
	"Put information about your course here.  Click the edit button above to add your own message.\n";

sub can ($c, $arg) {
	if ($arg eq 'info') {
		my $ce = $c->ce;

		# Only show the info box if the viewer has permission
		# to edit it or if it is not the standard template box.

		my $course_info_path = "$ce->{courseDirs}{templates}/$ce->{courseFiles}{course_info}";

		my $text = DEFAULT_COURSE_INFO_TXT;
		$text = eval { readFile($course_info_path) } if (-f $course_info_path);

		return $c->authz->hasPermissions($c->param('user'), 'access_instructor_tools')
			|| $text ne DEFAULT_COURSE_INFO_TXT;
	}

	return $c->SUPER::can($arg);
}

sub initialize ($c) {
	my $ce    = $c->ce;
	my $authz = $c->authz;

	my $user = $c->param('user');

	if ($authz->hasPermissions($user, 'access_instructor_tools')) {
		my $status_message = $c->param('status_message');
		$c->addmessage($c->tag('p', $c->b($status_message))) if $status_message;
	}

	if ($authz->hasPermissions($user, 'navigation_allowed')) {
		debug('Begin collecting merged sets');

		my @sets = $c->db->getMergedSetsWhere({ user_id => $c->param('effectiveUser') || $user });

		# Remove proctored gateway sets for users without permission to view them
		unless ($authz->hasPermissions($user, 'view_proctored_tests')) {
			@sets = grep { $_->assignment_type !~ /proctored/ } @sets;
		}

		debug('Begin sorting merged sets');

		if (($c->param('sort') || 'status') eq 'status') {
			@sets = sort byUrgency (@sets);
		} else {
			# Assume sort by 'name' if the parameter was not set to status.
			# This way there is no need to worry about an invalid parameter value.
			@sets = sortByName('set_id', @sets);
		}

		$c->stash->{sets} = \@sets;

		debug('End preparing merged sets');
	}

	return unless $ce->{courseFiles}{course_info};

	my $course_info_path = "$ce->{courseDirs}{templates}/$ce->{courseFiles}{course_info}";

	if ($authz->hasPermissions($user, 'access_instructor_tools')) {
		if (defined $c->param('editMode') && $c->param('editMode') eq 'temporaryFile') {
			$course_info_path = $c->param('sourceFilePath');
			$course_info_path = "$ce->{courseDirs}{templates}/$course_info_path"
				unless $course_info_path =~ m!^/!;

			unless (path_is_subdir($course_info_path, $ce->{courseDirs}{templates})) {
				$c->addbadmessage('sourceFilePath is unsafe!');
				return '';
			}

			$c->addmessage($c->tag(
				'p',
				class => 'temporaryFile',
				$c->maketext('Viewing temporary file: [_1]', $course_info_path)
			));
		}
	}

	if (-f $course_info_path) {
		$c->stash->{course_info_contents} = eval { readFile($course_info_path) };
		$c->stash->{course_info_error}    = $@ if $@;
	}

	return;
}

sub info ($c) {
	return $c->include('ContentGenerator/ProblemSets/info');
}

sub setListRow ($c, $set) {
	my $ce            = $c->ce;
	my $db            = $c->db;
	my $authz         = $c->authz;
	my $user          = $c->param('user');
	my $effectiveUser = $c->param('effectiveUser') || $user;
	my $globalSet     = $db->getGlobalSet($set->set_id);
	my $gwtype        = ($set->assignment_type() =~ /gateway/) ? 1 : 0;
	my $preOpenSets   = $authz->hasPermissions($user, 'view_unopened_sets');

	my @restricted = $ce->{options}{enableConditionalRelease} ? is_restricted($db, $set, $effectiveUser) : ();

	my $courseName = $c->stash('courseID');

	my $display_name = format_set_name_display($set->set_id);

	# Add clock icon if timed gateway
	if ($gwtype && $set->{version_time_limit} > 0 && time < $set->due_date) {
		$display_name = $c->c(
			$c->tag(
				'i',
				class => 'icon far fa-clock',
				title => $c->maketext('Test/quiz with time limit.'),
				data  => { alt => $c->maketext('Test/quiz with time limit.') }
			),
			' ',
			$c->tag('span', $display_name)
		)->join('');
	}

	# This is the link to the set, it has tooltip with the set description.
	my $interactive = $c->link_to(
		$display_name => $c->systemLink($c->url_for('problem_list', setID => $set->set_id)),
		class         => 'set-id-tooltip',
		data          => { bs_toggle => 'tooltip', bs_placement => 'right', bs_title => $globalSet->description }
	);

	# Determine set status.
	my $status = '';
	if (time < $set->open_date) {
		$status = $c->maketext('Will open on [_1].',
			$c->formatDateTime($set->open_date, undef, $ce->{studentDateDisplayFormat}));

		if (@restricted) {
			$status =
				$c->c($status, $c->restricted_progression_msg(1, $set->restricted_status * 100, @restricted))->join('');
		}
		$interactive = $display_name
			unless $preOpenSets || ($gwtype && $db->countSetVersions($effectiveUser, $set->set_id));

	} elsif (time < $set->due_date) {
		$status = $c->set_due_msg($set);

		if (@restricted) {
			$interactive = $display_name unless $preOpenSets;
			$status =
				$c->c($status, $c->restricted_progression_msg(0, $set->restricted_status * 100, @restricted))->join('');
		} elsif (defined $ce->{LTIGradeMode} && $ce->{LTIGradeMode} eq 'homework' && !$set->lis_source_did) {
			# The set shouldn't be shown if the LTI grade mode is set to homework and we don't
			# have a source did to use to send back grades.
			unless ($preOpenSets) {
				$status = $c->c(
					$status,
					$c->tag('br'),
					$c->maketext(
						'You must log into this set via your Learning Management System ([_1]).',
						$ce->{LTI}{ $ce->{LTIVersion} }{LMS_url}
						? $c->link_to(
							$ce->{LTI}{ $ce->{LTIVersion} }{LMS_name} => $ce->{LTI}{ $ce->{LTIVersion} }{LMS_url}
							)
						: $ce->{LTI}{ $ce->{LTIVersion} }{LMS_name}
					)
				)->join('');
				$interactive = $display_name;
			}
		}
	} elsif (time < $set->answer_date) {
		$status = $c->maketext('Closed, answers on [_1].',
			$c->formatDateTime($set->answer_date, undef, $ce->{studentDateDisplayFormat}));
	} elsif ($set->answer_date <= time and time < $set->answer_date + RECENT) {
		$status = $c->maketext('Closed, answers recently available.');
	} else {
		$status = $c->maketext('Closed, answers available.');
	}

	my $control = '';
	if (!$gwtype) {
		if ($authz->hasPermissions($user, 'view_multiple_sets')) {
			$control = $c->check_box(selected_sets => $set->set_id, id => $set->set_id, class => 'form-check-input');
			# Make the interactive be the label for the control.
			$interactive = $c->label_for($set->set_id => $interactive);
		} else {
			if (after($set->open_date) && (!@restricted || after($set->due_date))) {
				$control = $c->link_to(
					$c->tag(
						'i',
						class         => 'hardcopy-tooltip icon far fa-arrow-alt-circle-down fa-lg',
						'aria-hidden' => 'true',
						title         => $c->maketext(
							'Download [_1]',
							$c->tag('span', dir => 'ltr', format_set_name_display($set->set_id))
						),
						data => {
							alt => $c->maketext(
								'Download [_1]',
								$c->tag('span', dir => 'ltr', format_set_name_display($set->set_id))
							),
							bs_toggle    => 'tooltip',
							bs_placement => 'left'
						}
					) => $c->systemLink(
						$c->url_for('hardcopy', setID => $set->set_id),
						params => { selected_sets => $set->set_id }
					),
					class => 'hardcopy-link',
				);
			}
		}
	}

	$status = $c->tag('span', class => $set->visible ? 'font-visible' : 'font-hidden', $status) if $preOpenSets;

	return $c->tag(
		'tr',
		$c->c(
			$c->tag('td', dir => 'ltr', $interactive),
			$c->tag('td', $status),
			$c->tag('td', class => 'hardcopy', $control)
		)->join('')
	);
}

sub byname { return $a->set_id cmp $b->set_id; }

sub byUrgency {
	my $mytime = time;
	my @a_parts =
		($a->answer_date + RECENT <= $mytime) ? (4, $a->open_date, $a->due_date, $a->set_id)
		: ($a->answer_date <= $mytime and $mytime < $a->answer_date + RECENT)
		? (3, $a->answer_date, $a->due_date, $a->set_id)
		: ($a->due_date <= $mytime and $mytime < $a->answer_date) ? (2, $a->answer_date, $a->due_date, $a->set_id)
		: ($mytime < $a->open_date)                               ? (1, $a->open_date,   $a->due_date, $a->set_id)
		:                                                           (0, $a->due_date, $a->open_date, $a->set_id);
	my @b_parts =
		($b->answer_date + RECENT <= $mytime) ? (4, $b->open_date, $b->due_date, $b->set_id)
		: ($b->answer_date <= $mytime and $mytime < $b->answer_date + RECENT)
		? (3, $b->answer_date, $b->due_date, $b->set_id)
		: ($b->due_date <= $mytime and $mytime < $b->answer_date) ? (2, $b->answer_date, $b->due_date, $b->set_id)
		: ($mytime < $b->open_date)                               ? (1, $b->open_date,   $b->due_date, $b->set_id)
		:                                                           (0, $b->due_date, $b->open_date, $b->set_id);
	my $returnIt = 0;
	while (scalar(@a_parts) > 1) {
		if ($returnIt = ((shift @a_parts) <=> (shift @b_parts))) {
			return ($returnIt);
		}
	}
	return ($a_parts[0] cmp $b_parts[0]);
}

sub set_due_msg ($c, $set) {
	my $ce = $c->ce;

	my $enable_reduced_scoring =
		$ce->{pg}{ansEvalDefaults}{enableReducedScoring}
		&& $set->enable_reduced_scoring
		&& $set->reduced_scoring_date
		&& $set->reduced_scoring_date < $set->due_date;
	my $reduced_scoring_date      = $set->reduced_scoring_date;
	my $beginReducedScoringPeriod = $c->formatDateTime($reduced_scoring_date, undef, $ce->{studentDateDisplayFormat});

	my $t = time;

	if ($enable_reduced_scoring && $t < $reduced_scoring_date) {
		return $c->c(
			$c->maketext('Open, due [_1].', $beginReducedScoringPeriod),
			$c->tag('br'),
			$c->maketext(
				'Afterward reduced credit can be earned until [_1].',
				$c->formatDateTime($set->due_date(), undef, $ce->{studentDateDisplayFormat})
			)
		)->join('');
	} else {
		if ($enable_reduced_scoring && $reduced_scoring_date && $t > $reduced_scoring_date) {
			return $c->c(
				$c->maketext('Due date [_1] has passed.', $beginReducedScoringPeriod),
				$c->tag('br'),
				$c->maketext(
					'Reduced credit can still be earned until [_1].',
					$c->formatDateTime($set->due_date(), undef, $ce->{studentDateDisplayFormat})
				)
			)->join('');
		}

		return $c->maketext('Open, closes [_1].',
			$c->formatDateTime($set->due_date(), undef, $ce->{studentDateDisplayFormat}));
	}
}

sub restricted_progression_msg ($c, $open, $restriction, @restricted) {
	my $status = ' ';

	if (@restricted == 1) {
		$status .= $c->maketext(
			'To access this set you must score at least [_1]% on set [_2].',
			sprintf('%.0f', $restriction),
			$c->tag('span', dir => 'ltr', format_set_name_display($restricted[0]))
		);
	} else {
		$status .= $c->maketext(
			'To access this set you must score at least [_1]% on the following sets: [_2].',
			sprintf('%.0f', $restriction),
			join(', ', map { $c->tag('span', dir => 'ltr', format_set_name_display($_)) } @restricted)
		);
	}

	return $status;
}

1;
