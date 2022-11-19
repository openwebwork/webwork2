################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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
use parent qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::ProblemSets - Display a list of built problem sets.

=cut

use strict;
use warnings;

use WeBWorK::Debug;
use WeBWorK::Utils qw(after readFile sortByName path_is_subdir is_restricted format_set_name_display);
use WeBWorK::Localize;

# What do we consider a "recent" problem set?
use constant RECENT => 2 * 7 * 24 * 60 * 60;    # Two-Weeks in seconds

# The "default" data in the course_info.txt file.
use constant DEFAULT_COURSE_INFO_TXT =>
	"Put information about your course here.  Click the edit button above to add your own message.\n";

sub can {
	my ($self, $arg) = @_;

	if ($arg eq 'info') {
		my $r  = $self->r;
		my $ce = $r->ce;

		# Only show the info box if the viewer has permission
		# to edit it or if it is not the standard template box.

		my $course_info_path = "$ce->{courseDirs}{templates}/$ce->{courseFiles}{course_info}";

		my $text = DEFAULT_COURSE_INFO_TXT;
		$text = eval { readFile($course_info_path) } if (-f $course_info_path);

		return $r->authz->hasPermissions($r->param('user'), 'access_instructor_tools')
			|| $text ne DEFAULT_COURSE_INFO_TXT;
	}

	return $self->SUPER::can($arg);
}

sub initialize {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	my $authz  = $r->authz;

	my $user = $r->param('user');

	if ($authz->hasPermissions($user, 'access_instructor_tools')) {
		my $status_message = $r->param('status_message');
		$self->addmessage($r->tag('p', class => 'my-2', $r->b($status_message))) if $status_message;
	}

	if ($authz->hasPermissions($user, 'navigation_allowed')) {
		debug('Begin collecting merged sets');

		my @sets = $r->db->getMergedSetsWhere({ user_id => $r->param('effectiveUser') || $user });

		# Remove proctored gateway sets for users without permission to view them
		unless ($authz->hasPermissions($user, 'view_proctored_tests')) {
			@sets = grep { $_->assignment_type !~ /proctored/ } @sets;
		}

		debug('Begin sorting merged sets');

		if (($r->param('sort') || 'status') eq 'status') {
			@sets = sort byUrgency (@sets);
		} else {
			# Assume sort by 'name' if the parameter was not set to status.
			# This way there is no need to worry about an invalid parameter value.
			@sets = sortByName('set_id', @sets);
		}

		$r->stash->{sets} = \@sets;

		debug('End preparing merged sets');
	}

	return unless $ce->{courseFiles}{course_info};

	my $course_info_path = "$ce->{courseDirs}{templates}/$ce->{courseFiles}{course_info}";

	if ($authz->hasPermissions($user, 'access_instructor_tools')) {
		if (defined $r->param('editMode') && $r->param('editMode') eq 'temporaryFile') {
			$course_info_path = $r->param('sourceFilePath');
			$course_info_path = "$ce->{courseDirs}{templates}/$course_info_path"
				unless $course_info_path =~ m!^/!;

			unless (path_is_subdir($course_info_path, $ce->{courseDirs}{templates})) {
				$self->addbadmessage('sourceFilePath is unsafe!');
				return '';
			}

			$self->addmessage($r->tag(
				'p',
				class => 'temporaryFile my-2',
				$r->maketext('Viewing temporary file: [_1]', $course_info_path)
			));
		}
	}

	if (-f $course_info_path) {
		$r->stash->{course_info_contents} = eval { readFile($course_info_path) };
		$r->stash->{course_info_error}    = $@ if $@;
	}

	return;
}

sub info {
	my ($self) = @_;
	return $self->r->include('ContentGenerator/ProblemSets/info');
}

sub setListRow {
	my ($self, $set) = @_;
	my $r             = $self->r;
	my $ce            = $r->ce;
	my $db            = $r->db;
	my $authz         = $r->authz;
	my $user          = $r->param('user');
	my $effectiveUser = $r->param('effectiveUser') || $user;
	my $urlpath       = $r->urlpath;
	my $globalSet     = $db->getGlobalSet($set->set_id);
	my $gwtype        = ($set->assignment_type() =~ /gateway/) ? 1 : 0;
	my $preOpenSets   = $authz->hasPermissions($user, 'view_unopened_sets');

	my @restricted = $ce->{options}{enableConditionalRelease} ? is_restricted($db, $set, $effectiveUser) : ();

	my $courseName = $urlpath->arg('courseID');

	my $display_name = format_set_name_display($set->set_id);

	# Add clock icon if timed gateway
	if ($gwtype && $set->{version_time_limit} > 0 && time < $set->due_date) {
		$display_name = $r->c(
			$r->tag(
				'i',
				class => 'icon far fa-clock',
				title => $r->maketext('Test/quiz with time limit.'),
				data  => { alt => $r->maketext('Test/quiz with time limit.') }
			),
			' ',
			$r->tag('span', $display_name)
		)->join('');
	}

	# This is the link to the set, it has tooltip with the set description.
	my $interactive = $r->link_to(
		$display_name => $self->systemLink($urlpath->newFromModule(
			'WeBWorK::ContentGenerator::ProblemSet', $r,
			courseID => $courseName,
			setID    => $set->set_id
		)),
		class => 'set-id-tooltip',
		data  => { bs_toggle => 'tooltip', bs_placement => 'right', bs_title => $globalSet->description }
	);

	# Determine set status.
	my $status = '';
	if (time < $set->open_date) {
		$status = $r->maketext('Will open on [_1].',
			$self->formatDateTime($set->open_date, undef, $ce->{studentDateDisplayFormat}));

		if (@restricted) {
			$status =
				$r->c($status, restricted_progression_msg($r, 1, $set->restricted_status * 100, @restricted))->join('');
		}
		$interactive = $display_name
			unless $preOpenSets || ($gwtype && $db->countSetVersions($effectiveUser, $set->set_id));

	} elsif (time < $set->due_date) {
		$status = $self->set_due_msg($set);

		if (@restricted) {
			$interactive = $display_name unless $preOpenSets;
			$status =
				$r->c($status, restricted_progression_msg($r, 0, $set->restricted_status * 100, @restricted))->join('');
		} elsif (defined $ce->{LTIGradeMode} && $ce->{LTIGradeMode} eq 'homework' && !$set->lis_source_did) {
			# The set shouldn't be shown if the LTI grade mode is set to homework and we don't
			# have a source did to use to send back grades.
			unless ($preOpenSets) {
				$status = $r->c(
					$status,
					$r->tag('br'),
					$r->maketext(
						'You must log into this set via your Learning Management System ([_1]).',
						$ce->{LMS_url} ? $r->link_to($ce->{LMS_name} => $ce->{LMS_url}) : $ce->{LMS_name}
					)
				)->join('');
				$interactive = $display_name;
			}
		}
	} elsif (time < $set->answer_date) {
		$status = $r->maketext('Closed, answers on [_1].',
			$self->formatDateTime($set->answer_date, undef, $ce->{studentDateDisplayFormat}));
	} elsif ($set->answer_date <= time and time < $set->answer_date + RECENT) {
		$status = $r->maketext('Closed, answers recently available.');
	} else {
		$status = $r->maketext('Closed, answers available.');
	}

	my $control = '';
	if (!$gwtype) {
		if ($authz->hasPermissions($user, 'view_multiple_sets')) {
			$control = $r->check_box(selected_sets => $set->set_id, id => $set->set_id, class => 'form-check-input');
			# Make the interactive be the label for the control.
			$interactive = $r->label_for($set->set_id => $interactive);
		} else {
			if (after($set->open_date) && (!@restricted || after($set->due_date))) {
				$control = $r->link_to(
					$r->tag(
						'i',
						class         => 'hardcopy-tooltip icon far fa-arrow-alt-circle-down fa-lg',
						'aria-hidden' => 'true',
						title         => $r->maketext(
							'Download [_1]',
							$r->tag('span', dir => 'ltr', format_set_name_display($set->set_id))
						),
						data => {
							alt => $r->maketext(
								'Download [_1]',
								$r->tag('span', dir => 'ltr', format_set_name_display($set->set_id))
							),
							bs_toggle    => 'tooltip',
							bs_placement => 'left'
						}
					) => $self->systemLink(
						$urlpath->newFromModule(
							'WeBWorK::ContentGenerator::Hardcopy', $r,
							courseID => $courseName,
							setID    => $set->set_id
						),
						params => { selected_sets => $set->set_id }
					),
					class => 'hardcopy-link',
				);
			}
		}
	}

	$status = $r->tag('span', class => $set->visible ? 'font-visible' : 'font-hidden', $status) if $preOpenSets;

	return $r->tag(
		'tr',
		$r->c(
			$r->tag('td', dir => 'ltr', $interactive),
			$r->tag('td', $status),
			$r->tag('td', class => 'hardcopy', $control)
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

sub set_due_msg {
	my $self = shift;
	my $set  = shift;

	my $r  = $self->r;
	my $ce = $r->ce;

	my $enable_reduced_scoring =
		$ce->{pg}{ansEvalDefaults}{enableReducedScoring}
		&& $set->enable_reduced_scoring
		&& $set->reduced_scoring_date
		&& $set->reduced_scoring_date < $set->due_date;
	my $reduced_scoring_date = $set->reduced_scoring_date;
	my $beginReducedScoringPeriod =
		$self->formatDateTime($reduced_scoring_date, undef, $ce->{studentDateDisplayFormat});

	my $t = time;

	if ($enable_reduced_scoring && $t < $reduced_scoring_date) {
		return $r->c(
			$r->maketext('Open, due [_1].', $beginReducedScoringPeriod),
			$r->tag('br'),
			$r->maketext(
				'Afterward reduced credit can be earned until [_1].',
				$self->formatDateTime($set->due_date(), undef, $ce->{studentDateDisplayFormat})
			)
		)->join('');
	} else {
		if ($enable_reduced_scoring && $reduced_scoring_date && $t > $reduced_scoring_date) {
			return $r->c(
				$r->maketext('Due date [_1] has passed.', $beginReducedScoringPeriod),
				$r->tag('br'),
				$r->maketext(
					'Reduced credit can still be earned until [_1].',
					$self->formatDateTime($set->due_date(), undef, $ce->{studentDateDisplayFormat})
				)
			)->join('');
		}

		return $r->maketext('Open, closes [_1].',
			$self->formatDateTime($set->due_date(), undef, $ce->{studentDateDisplayFormat}));
	}
}

sub restricted_progression_msg {
	my ($r, $open, $restriction, @restricted) = @_;
	my $status = ' ';

	if (@restricted == 1) {
		$status .= $r->maketext(
			'To access this set you must score at least [_1]% on set [_2].',
			sprintf('%.0f', $restriction),
			$r->tag('span', dir => 'ltr', format_set_name_display($restricted[0]))
		);
	} else {
		$status .= $r->maketext(
			'To access this set you must score at least [_1]% on the following sets: [_2].',
			sprintf('%.0f', $restriction),
			join(', ', map { $r->tag('span', dir => 'ltr', format_set_name_display($_)) } @restricted)
		);
	}

	return $status;
}

1;
