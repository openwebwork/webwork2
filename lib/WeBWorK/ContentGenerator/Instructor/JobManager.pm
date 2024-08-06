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
# FOR A PARTICULAR PURPOSE.	 See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::ContentGenerator::Instructor::JobManager;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::JobManager - Minion job queue job management

=cut

use WeBWorK::Utils qw(x);

use constant ACTION_FORMS => [ [ filter => x('Filter') ], [ sort => x('Sort') ], [ delete => x('Delete') ] ];

# All tasks added in the Mojolicious::WeBWorK module need to be listed here.
use constant TASK_NAMES => {
	lti_mass_update        => x('LTI Mass Update'),
	send_instructor_email  => x('Send Instructor Email'),
	send_achievement_email => x('Send Achiement Email')
};

# This constant is not used.  It is here so that gettext adds these strings to the translation files.
use constant JOB_STATES => [ x('inactive'), x('active'), x('finished'), x('failed') ];

use constant FIELDS => [
	[ id       => x('Id') ],
	[ courseID => x('Course Id') ],
	[ task     => x('Task') ],
	[ created  => x('Created') ],
	[ started  => x('Started') ],
	[ finished => x('Finished') ],
	[ state    => x('State') ],
];

use constant SORT_SUBS => {
	id       => { ASC => \&byJobID,        DESC => \&byDescJobID },
	courseID => { ASC => \&byCourseID,     DESC => \&byDescCourseID },
	task     => { ASC => \&byTask,         DESC => \&byDescTask },
	created  => { ASC => \&byCreatedTime,  DESC => \&byDescCreatedTime },
	started  => { ASC => \&byStartedTime,  DESC => \&byDescStartedTime },
	finished => { ASC => \&byFinishedTime, DESC => \&byDescFinishedTime },
	state    => { ASC => \&byState,        DESC => \&byDescState }
};

sub initialize ($c) {
	$c->stash->{taskNames}   = TASK_NAMES();
	$c->stash->{actionForms} = ACTION_FORMS();
	$c->stash->{fields} =
		$c->stash->{courseID} eq $c->ce->{admin_course_id} ? FIELDS() : [ grep { $_ ne 'courseID' } @{ FIELDS() } ];
	$c->stash->{jobs}               = {};
	$c->stash->{visibleJobs}        = {};
	$c->stash->{selectedJobs}       = {};
	$c->stash->{sortedJobs}         = [];
	$c->stash->{primarySortField}   = $c->param('primarySortField')   || 'created';
	$c->stash->{primarySortOrder}   = $c->param('primarySortOrder')   || 'ASC';
	$c->stash->{secondarySortField} = $c->param('secondarySortField') || 'task';
	$c->stash->{secondarySortOrder} = $c->param('secondarySortOrder') || 'ASC';
	$c->stash->{ternarySortField}   = $c->param('ternarySortField')   || 'state';
	$c->stash->{ternarySortOrder}   = $c->param('ternarySortOrder')   || 'ASC';

	return unless $c->authz->hasPermissions($c->param('user'), 'access_instructor_tools');

	# Get a list of all jobs.  If this is not the admin course, then restrict to the jobs for this course.
	my $jobs = $c->minion->jobs;
	while (my $job = $jobs->next) {
		# Get the course id from the job arguments for backwards compatibility with jobs before the job manager was
		# added and the course id was moved to the notes.
		unless (defined $job->{notes}{courseID}) {
			if (ref($job->{args}[0]) eq 'HASH' && defined $job->{args}[0]{courseName}) {
				$job->{notes}{courseID} = $job->{args}[0]{courseName};
			} else {
				$job->{notes}{courseID} = $job->{args}[0];
			}
		}

		# Copy the courseID from the notes hash directly to the job for convenience of access.  Particularly, so that
		# that the filter_handler method can access it the same as for other fields.
		$job->{courseID} = $job->{notes}{courseID};

		$c->stash->{jobs}{ $job->{id} } = $job
			if $c->stash->{courseID} eq $c->ce->{admin_course_id} || $job->{courseID} eq $c->stash->{courseID};
	}

	if (defined $c->param('visible_jobs')) {
		$c->stash->{visibleJobs} = { map { $_ => 1 } @{ $c->every_param('visible_jobs') } };
	} elsif (defined $c->param('no_visible_jobs')) {
		$c->stash->{visibleJobs} = {};
	} else {
		$c->stash->{visibleJobs} = { map { $_ => 1 } keys %{ $c->stash->{jobs} } };
	}

	$c->stash->{selectedJobs} = { map { $_ => 1 } @{ $c->every_param('selected_jobs') // [] } };

	my $actionID = $c->param('action');
	if ($actionID) {
		my $actionHandler = "${actionID}_handler";
		die $c->maketext('Action [_1] not found', $actionID) unless $c->can($actionHandler);
		$c->addgoodmessage($c->$actionHandler);
	}

	# Sort jobs
	my $primarySortSub   = SORT_SUBS()->{ $c->stash->{primarySortField} }{ $c->stash->{primarySortOrder} };
	my $secondarySortSub = SORT_SUBS()->{ $c->stash->{secondarySortField} }{ $c->stash->{secondarySortOrder} };
	my $ternarySortSub   = SORT_SUBS()->{ $c->stash->{ternarySortField} }{ $c->stash->{ternarySortOrder} };

	# byJobID is included to ensure a definite sort order in case the
	# first three sorts do not determine a proper order.
	$c->stash->{sortedJobs} = [
		map  { $_->{id} }
		sort { &$primarySortSub || &$secondarySortSub || &$ternarySortSub || byJobID }
		grep { $c->stash->{visibleJobs}{ $_->{id} } } (values %{ $c->stash->{jobs} })
	];

	return;
}

sub filter_handler ($c) {
	my $ce = $c->ce;

	my $scope = $c->param('action.filter.scope');
	if ($scope eq 'all') {
		$c->stash->{visibleJobs} = { map { $_ => 1 } keys %{ $c->stash->{jobs} } };
		return $c->maketext('Showing all jobs.');
	} elsif ($scope eq 'selected') {
		$c->stash->{visibleJobs} = $c->stash->{selectedJobs};
		return $c->maketext('Showing selected jobs.');
	} elsif ($scope eq 'match_regex') {
		my $regex = $c->param('action.filter.text');
		my $field = $c->param('action.filter.field');
		$c->stash->{visibleJobs} = {};
		for my $jobID (keys %{ $c->stash->{jobs} }) {
			$c->stash->{visibleJobs}{$jobID} = 1 if $c->stash->{jobs}{$jobID}{$field} =~ /^$regex/i;
		}
		return $c->maketext('Showing matching jobs.');
	}

	# This should never happen.  As such it is not translated.
	return 'Not filtering. Unknown filter given.';
}

sub sort_handler ($c) {
	if (defined $c->param('labelSortMethod') || defined $c->param('labelSortOrder')) {
		if (defined $c->param('labelSortOrder')) {
			$c->stash->{ $c->param('labelSortOrder') . 'SortOrder' } =
				$c->stash->{ $c->param('labelSortOrder') . 'SortOrder' } eq 'ASC' ? 'DESC' : 'ASC';
		} elsif ($c->param('labelSortMethod') eq $c->stash->{primarySortField}) {
			$c->stash->{primarySortOrder} = $c->stash->{primarySortOrder} eq 'ASC' ? 'DESC' : 'ASC';
		} else {
			$c->stash->{ternarySortField}   = $c->stash->{secondarySortField};
			$c->stash->{ternarySortOrder}   = $c->stash->{secondarySortOrder};
			$c->stash->{secondarySortField} = $c->stash->{primarySortField};
			$c->stash->{secondarySortOrder} = $c->stash->{primarySortOrder};
			$c->stash->{primarySortField}   = $c->param('labelSortMethod');
			$c->stash->{primarySortOrder}   = 'ASC';
		}

		$c->param('action.sort.primary',         $c->stash->{primarySortField});
		$c->param('action.sort.primary.order',   $c->stash->{primarySortOrder});
		$c->param('action.sort.secondary',       $c->stash->{secondarySortField});
		$c->param('action.sort.secondary.order', $c->stash->{secondarySortOrder});
		$c->param('action.sort.ternary',         $c->stash->{ternarySortField});
		$c->param('action.sort.ternary.order',   $c->stash->{ternarySortOrder});
	} else {
		$c->stash->{primarySortField}   = $c->param('action.sort.primary');
		$c->stash->{primarySortOrder}   = $c->param('action.sort.primary.order');
		$c->stash->{secondarySortField} = $c->param('action.sort.secondary');
		$c->stash->{secondarySortOrder} = $c->param('action.sort.secondary.order');
		$c->stash->{ternarySortField}   = $c->param('action.sort.ternary');
		$c->stash->{ternarySortOrder}   = $c->param('action.sort.ternary.order');
	}

	return $c->maketext(
		'Jobs sorted by [_1] in [plural,_2,ascending,descending] order, '
			. 'then by [_3] in [plural,_4,ascending,descending] order,'
			. 'and then by [_5] in [plural,_6,ascending,descending] order.',
		$c->maketext((grep { $_->[0] eq $c->stash->{primarySortField} } @{ FIELDS() })[0][1]),
		$c->stash->{primarySortOrder} eq 'ASC' ? 1 : 2,
		$c->maketext((grep { $_->[0] eq $c->stash->{secondarySortField} } @{ FIELDS() })[0][1]),
		$c->stash->{secondarySortOrder} eq 'ASC' ? 1 : 2,
		$c->maketext((grep { $_->[0] eq $c->stash->{ternarySortField} } @{ FIELDS() })[0][1]),
		$c->stash->{ternarySortOrder} eq 'ASC' ? 1 : 2
	);
}

sub delete_handler ($c) {
	my $num = 0;
	return $c->maketext('Deleted [quant,_1,job].', $num) if $c->param('action.delete.scope') eq 'none';

	for my $jobID (keys %{ $c->stash->{selectedJobs} }) {
		# If a job was inactive (not yet started) when the page was previously loaded, then it may be selected to be
		# deleted.  By the time the delete form is submitted the job may have started and may now be active. In that
		# case it can not be deleted.
		if ($c->stash->{jobs}{$jobID}{state} eq 'active') {
			$c->addbadmessage(
				$c->maketext('Unable to delete job [_1] as it has transitioned to an active state.', $jobID));
			next;
		}
		delete $c->stash->{jobs}{$jobID};
		delete $c->stash->{visibleJobs}{$jobID};
		delete $c->stash->{selectedJobs}{$jobID};
		$c->minion->job($jobID)->remove;
		++$num;
	}

	return $c->maketext('Deleted [quant,_1,job].', $num);
}

# Sort methods
sub byJobID        { return $a->{id} <=> $b->{id} }
sub byCourseID     { return lc $a->{courseID} cmp lc $b->{courseID} }
sub byTask         { return $a->{task} cmp $b->{task} }
sub byCreatedTime  { return $a->{created} <=> $b->{created} }
sub byStartedTime  { return ($a->{started}  || 0) <=> ($b->{started}  || 0) }
sub byFinishedTime { return ($a->{finished} || 0) <=> ($b->{finished} || 0) }
sub byState        { return $a->{state} cmp $b->{state} }

sub byDescJobID        { local ($b, $a) = ($a, $b); return byJobID(); }
sub byDescCourseID     { local ($b, $a) = ($a, $b); return byCourseID(); }
sub byDescTask         { local ($b, $a) = ($a, $b); return byTask(); }
sub byDescCreatedTime  { local ($b, $a) = ($a, $b); return byCreatedTime(); }
sub byDescStartedTime  { local ($b, $a) = ($a, $b); return byStartedTime(); }
sub byDescFinishedTime { local ($b, $a) = ($a, $b); return byFinishedTime(); }
sub byDescState        { local ($b, $a) = ($a, $b); return byState(); }

1;
