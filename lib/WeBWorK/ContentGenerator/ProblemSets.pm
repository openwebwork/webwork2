################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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
use WeBWorK::Utils qw(sortByName);
use WeBWorK::Utils::DateTime qw(after);
use WeBWorK::Utils::Files qw(readFile path_is_subdir);
use WeBWorK::Utils::Sets qw(is_restricted format_set_name_display);
use WeBWorK::Localize;

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
		eval { $text = readFile($course_info_path) } if -f $course_info_path;

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
		my $status_message = $c->authen->flash('status_message');
		$c->addmessage($c->tag('p', $c->b($status_message))) if $status_message;
	}

	if ($authz->hasPermissions($user, 'navigation_allowed')) {
		debug('Begin collecting merged sets');

		my @sets = $c->db->getMergedSetsWhere({ user_id => $c->param('effectiveUser') || $user });

		# Remove proctored gateway sets for users without permission to view them
		@sets = grep { $_->assignment_type !~ /proctored/ } @sets
			unless $authz->hasPermissions($user, 'view_proctored_tests');

		# Remove hidden sets unless the user has permission to view hidden sets.
		@sets = grep { $_->visible } @sets
			unless $authz->hasPermissions($user, 'view_hidden_sets');

		debug('Begin sorting merged sets');

		# Cache sort orders.  Javascript uses these to display sets in the correct order.

		# First sort by name and cache the name sort order.
		@sets = sortByName('set_id', @sets);
		$sets[$_]->{name_sort_order} = $_ for 0 .. $#sets;

		# Then sort by urgency and cache that sort order. This is the default display order.
		@sets = sort byUrgency @sets;
		$sets[$_]->{urgency_sort_order} = $_ for 0 .. $#sets;

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

sub getSetStatus ($c, $set) {
	my $ce              = $c->ce;
	my $db              = $c->db;
	my $authz           = $c->authz;
	my $effectiveUser   = $c->param('effectiveUser') || $c->param('user');
	my $canViewUnopened = $authz->hasPermissions($c->param('user'), 'view_unopened_sets');

	my @restricted = $ce->{options}{enableConditionalRelease} ? is_restricted($db, $set, $effectiveUser) : ();

	my $link_is_active = 1;

	# Determine set status.
	my $status_msg;
	my $status         = 'past-due';
	my $other_messages = $c->c;
	if ($c->submitTime < $set->open_date) {
		$status = 'not-open';
		$status_msg =
			$c->maketext('Will open on [_1].', $c->formatDateTime($set->open_date, $ce->{studentDateDisplayFormat}));
		push(@$other_messages, $c->restricted_progression_msg(1, $set->restricted_status * 100, @restricted))
			if @restricted;
		$link_is_active = 0
			unless $canViewUnopened
			|| ($set->assignment_type =~ /gateway/ && $db->countSetVersions($effectiveUser, $set->set_id));
	} elsif ($c->submitTime < $set->due_date) {
		$status = 'open';

		my $enable_reduced_scoring =
			$ce->{pg}{ansEvalDefaults}{enableReducedScoring}
			&& $set->enable_reduced_scoring
			&& $set->reduced_scoring_date
			&& $set->reduced_scoring_date < $set->due_date;

		my $beginReducedScoringPeriod = $c->formatDateTime($set->reduced_scoring_date, $ce->{studentDateDisplayFormat});

		if ($enable_reduced_scoring && $c->submitTime < $set->reduced_scoring_date) {
			$status_msg = $c->maketext('Open. Due [_1].', $beginReducedScoringPeriod);
			push(
				@$other_messages,
				$c->maketext(
					'Afterward reduced credit can be earned until [_1].',
					$c->formatDateTime($set->due_date, $ce->{studentDateDisplayFormat})
				)
			);
		} elsif ($enable_reduced_scoring && $set->reduced_scoring_date && $c->submitTime > $set->reduced_scoring_date) {
			$status     = 'reduced';
			$status_msg = $c->maketext('Due date [_1] has passed.', $beginReducedScoringPeriod);
			push(
				@$other_messages,
				$c->maketext(
					'Reduced credit can still be earned until [_1].',
					$c->formatDateTime($set->due_date, $ce->{studentDateDisplayFormat})
				)
			);
		} else {
			$status_msg =
				$c->maketext('Open. Due [_1].', $c->formatDateTime($set->due_date, $ce->{studentDateDisplayFormat}));
		}

		if (@restricted) {
			$link_is_active = 0 unless $canViewUnopened;
			push(@$other_messages, $c->restricted_progression_msg(0, $set->restricted_status * 100, @restricted));
		} elsif (!$canViewUnopened
			&& $ce->{LTIVersion}
			&& ($ce->{LTIVersion} ne 'v1p3' || !$ce->{LTI}{v1p3}{ignoreMissingSourcedID})
			&& defined $ce->{LTIGradeMode}
			&& $ce->{LTIGradeMode} eq 'homework'
			&& !$set->lis_source_did)
		{
			# The set shouldn't be shown if LTI grade mode is set to homework and a
			# sourced_id is not available to use to send back grades
			# (unless we are using LTI 1.3 and $LTI{v1p3}{ignoreMissingSourcedID} is set)
			push(
				@$other_messages,
				$c->maketext(
					'You must log into this set via your Learning Management System ([_1]).',
					$ce->{LTI}{ $ce->{LTIVersion} }{LMS_url}
					? $c->link_to(
						$ce->{LTI}{ $ce->{LTIVersion} }{LMS_name} => $ce->{LTI}{ $ce->{LTIVersion} }{LMS_url}
						)
					: $ce->{LTI}{ $ce->{LTIVersion} }{LMS_name}
				)
			);
			$link_is_active = 0;
		}
	} elsif ($c->submitTime < $set->answer_date) {
		$status_msg = $c->maketext('Answers available for review on [_1].',
			$c->formatDateTime($set->answer_date, $ce->{studentDateDisplayFormat}));
	} else {
		$status_msg = $c->maketext('Answers available for review.');
	}

	return (
		status         => $status,
		status_msg     => $status_msg,
		other_messages => $other_messages,
		link_is_active => $link_is_active,
		is_restricted  => scalar(@restricted)
	);
}

sub byUrgency {
	my $mytime = time;
	my @a_parts =
		$mytime >= $a->answer_date ? (3, $a->answer_date, $a->due_date)
		: $mytime >= $a->due_date  ? (2, $a->answer_date, $a->due_date)
		: $mytime < $a->open_date  ? (1, $a->open_date, $a->due_date)
		:                            (0, $a->due_date, $a->open_date);
	my @b_parts =
		$mytime >= $b->answer_date ? (3, $b->answer_date, $b->due_date)
		: $mytime >= $b->due_date  ? (2, $b->answer_date, $b->due_date)
		: $mytime < $b->open_date  ? (1, $b->open_date, $b->due_date)
		:                            (0, $b->due_date, $b->open_date);
	while (@a_parts) {
		if (my $returnIt = (shift @a_parts) <=> (shift @b_parts)) { return $returnIt; }
	}
	return $a->set_id cmp $b->set_id;
}

sub restricted_progression_msg ($c, $open, $restriction, @restricted) {
	if (@restricted == 1) {
		return $c->maketext(
			'To access this set you must score at least [_1]% on set [_2].',
			sprintf('%.0f', $restriction),
			$c->tag('span', dir => 'ltr', format_set_name_display($restricted[0]))
		);
	} else {
		return $c->maketext(
			'To access this set you must score at least [_1]% on the following sets: [_2].',
			sprintf('%.0f', $restriction),
			join(', ', map { $c->tag('span', dir => 'ltr', format_set_name_display($_)) } @restricted)
		);
	}
}

1;
