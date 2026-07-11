package Caliper::Entity;
use Mojo::Base -signatures;

use Digest::SHA           qw(sha1_base64);
use Data::Structure::Util qw(unbless);

use WeBWorK::Utils::Tags;
use WeBWorK::Utils::Sets qw(grade_set grade_gateway);
use Caliper::ResourceIri;
use Caliper::Sensor;
use Caliper::Actor;

sub webwork_app ($c) {
	return {
		id      => Caliper::ResourceIri->new($c->ce)->webwork,
		type    => 'SoftwareApplication',
		name    => 'WeBWorK',
		version => $c->ce->{WW_VERSION}
	};
}

sub session ($c, $actor, $session_key) {
	my $session_key_hash = sha1_base64($session_key);
	return {
		id     => Caliper::ResourceIri->new($c->ce)->user_session($session_key_hash),
		type   => 'Session',
		user   => $actor,
		client => Caliper::Entity::client($c, $session_key_hash)
	};
}

sub client ($c, $session_key_hash) {
	return {
		id        => Caliper::ResourceIri->new($c->ce)->user_client($session_key_hash),
		type      => 'SoftwareApplication',
		userAgent => $c->req->headers->user_agent,
		ipAddress => $c->tx->remote_address,
		host      => $c->req->url->to_abs->host
	};
}

sub membership ($c, $actor, $user_id) {
	my $resource_iri = Caliper::ResourceIri->new($c->ce);

	my $user       = $c->db->getUser($user_id);
	my $permission = $c->db->getPermissionLevel($user_id);

	my $roles = [];

	if ($permission->permission == $c->ce->{userRoles}{admin}) {
		push @$roles, 'Administrator';
	} elsif ($permission->permission == $c->ce->{userRoles}{professor}) {
		push @$roles, 'Instructor';
	} elsif ($permission->permission == $c->ce->{userRoles}{ta}) {
		push @$roles, 'Instructor';
		push @$roles, 'Instructor#TeachingAssistant';
	} elsif ($permission->permission == $c->ce->{userRoles}{grade_proctor}) {
		push @$roles, 'Instructor';
		push @$roles, 'Instructor#Grader';
	} elsif ($permission->permission == $c->ce->{userRoles}{login_proctor}) {
		push @$roles, 'Instructor';
		push @$roles, 'Instructor#GuestInstructor';
	} elsif ($permission->permission == $c->ce->{userRoles}{student}) {
		push @$roles, 'Learner';
	}
	# guest and nobody aren't tracked

	return {
		id           => $resource_iri->user_membership($user_id),
		type         => 'Membership',
		member       => $actor,
		organization => $resource_iri->course,
		roles        => $roles,
		status       => $user->status ne 'D' ? 'Active' : 'Inactive'
	};
}

sub course ($c) {
	my $course_entity = {
		id   => Caliper::ResourceIri->new($c->ce)->course,
		type => 'CourseOffering'
	};
	$course_entity->{name} = $c->db->getSettingValue('courseTitle') if $c->db->settingExists('courseTitle');
	return $course_entity;
}

sub problem_set ($c, $set_id) {
	my $resource_iri = Caliper::ResourceIri->new($c->ce);

	my $problem_set = $c->db->getGlobalSet($set_id);

	my $items       = [];
	my @problem_ids = $c->db->listGlobalProblems($set_id);
	for my $problem_id (@problem_ids) {
		push(
			@$items,
			{
				id   => $resource_iri->problem($set_id, $problem_id),
				type => 'AssessmentItem'
			}
		);
	}

	my $problem_set_entity = {
		id            => $resource_iri->problem_set($set_id),
		type          => 'Assessment',
		isPartOf      => Caliper::Entity::course($c),
		name          => $set_id,
		items         => $items,
		dateToStartOn => Caliper::Sensor::formatted_timestamp($problem_set->open_date),
		dateToSubmit  => Caliper::Sensor::formatted_timestamp($problem_set->due_date),
		extensions    => {
			answer_date               => $problem_set->answer_date,
			reduced_scoring_date      => $problem_set->reduced_scoring_date,
			visible                   => $problem_set->visible,
			enable_reduced_scoring    => $problem_set->enable_reduced_scoring,
			description               => $problem_set->description,
			restricted_release        => $problem_set->restricted_release,
			restricted_status         => $problem_set->restricted_status,
			attempts_per_version      => $problem_set->attempts_per_version,
			time_interval             => $problem_set->time_interval,
			versions_per_interval     => $problem_set->versions_per_interval,
			version_time_limit        => $problem_set->version_time_limit,
			version_creation_time     => $problem_set->version_creation_time,
			problem_randorder         => $problem_set->problem_randorder,
			version_last_attempt_time => $problem_set->version_last_attempt_time,
			problems_per_page         => $problem_set->problems_per_page,
			hide_score                => $problem_set->hide_score,
			hide_score_by_problem     => $problem_set->hide_score_by_problem,
			hide_work                 => $problem_set->hide_work,
			time_limit_cap            => $problem_set->time_limit_cap,
			restrict_ip               => $problem_set->restrict_ip,
			relax_restrict_ip         => $problem_set->relax_restrict_ip,
			restricted_login_proctor  => $problem_set->restricted_login_proctor,
			hide_hint                 => $problem_set->hide_hint,
			restrict_prob_progression => $problem_set->restrict_prob_progression
		}
	};

	$problem_set_entity->{description} = $problem_set->description
		if defined $problem_set->description && $problem_set->description ne '';

	return $problem_set_entity;
}

sub problem ($c, $set_id, $problem_id) {
	my $problem = $c->db->getGlobalProblem($set_id, $problem_id);

	my $tags;

	if ($problem->source_file !~ /^group:/) {
		$tags = unbless(WeBWorK::Utils::Tags->new($c->ce->{courseDirs}{templates} . '/' . $problem->source_file));
		$_ =~ s/(^[\s"']+)|([\s"']+$)//g for @{ $tags->{keywords} };
	}

	return {
		id         => Caliper::ResourceIri->new($c->ce)->problem($set_id, $problem_id),
		type       => 'AssessmentItem',
		name       => "Problem $problem_id",
		isPartOf   => Caliper::Entity::problem_set($c, $set_id),
		keywords   => $tags ? $tags->{keywords} : undef,
		extensions => {
			source_file          => $problem->source_file,
			value                => $problem->value,
			max_attempts         => $problem->max_attempts,
			att_to_open_children => $problem->att_to_open_children,
			counts_parent_grade  => $problem->counts_parent_grade,
			showMeAnother        => $problem->showMeAnother,
			showMeAnotherCount   => $problem->showMeAnotherCount,
			showHintsAfter       => $problem->showHintsAfter,
			prPeriod             => $problem->prPeriod,
			prCount              => $problem->prCount,
			flags                => $problem->flags,
			tags                 => $tags
		}
	};
}

sub problem_user ($c, $set_id, $version_id, $problem_id, $user_id, $pg) {
	my $problem_user =
		$version_id
		? $c->db->getMergedProblemVersion($user_id, $set_id, $version_id, $problem_id)
		: $c->db->getMergedProblem($user_id, $set_id, $problem_id);

	my $tags = WeBWorK::Utils::Tags->new($c->ce->{courseDirs}{templates} . '/' . $problem_user->source_file);
	$_ =~ s/(^[\s"']+)|([\s"']+$)//g for @{ $tags->{keywords} };

	my $correct_answers = [];
	for my $ans_id (@{ $pg->{flags}->{ANSWER_ENTRY_ORDER} // [] }) {
		push @$correct_answers, $pg->{answers}->{$ans_id}->{correct_value};
	}

	return {
		id         => Caliper::ResourceIri->new($c->ce)->problem_user($set_id, $problem_id, $user_id),
		type       => 'AssessmentItem',
		name       => "Problem $problem_id",
		isPartOf   => Caliper::Entity::problem($c, $set_id, $problem_id),
		keywords   => $tags->{keywords},
		extensions => {
			correct_answers      => $correct_answers,
			source_file          => $problem_user->source_file,
			value                => $problem_user->value,
			max_attempts         => $problem_user->max_attempts,
			att_to_open_children => $problem_user->att_to_open_children,
			counts_parent_grade  => $problem_user->counts_parent_grade,
			showMeAnother        => $problem_user->showMeAnother,
			showMeAnotherCount   => $problem_user->showMeAnotherCount,
			showHintsAfter       => $problem_user->showHintsAfter,
			prPeriod             => $problem_user->prPeriod,
			prCount              => $problem_user->prCount,
			flags                => $problem_user->flags,
			tags                 => \%$tags,
			problem_seed         => $problem_user->problem_seed,
			source_text          => $problem_user->status,
			problem_html_text    => $pg->{'body_text'},
			status               => $problem_user->status,
			attempted            => $problem_user->attempted,
			last_answer          => $problem_user->last_answer,
			num_correct          => $problem_user->num_correct,
			num_incorrect        => $problem_user->num_incorrect,
			sub_status           => $problem_user->sub_status
		}
	};
}

sub answer ($c, $set_id, $version_id, $problem_id, $user_id, $pg, $start_time, $end_time) {
	my $last_answer_id =
		$c->db->latestProblemPastAnswer($user_id, ($version_id ? "$set_id,v$version_id" : $set_id), $problem_id);
	my $last_answer = $c->db->getPastAnswer($last_answer_id);
	my @answers     = split(/\t/, $last_answer->answer_string);

	my $pg_answers_hash = {};
	for my $key (keys %{ $pg->{answers} }) {
		my %answer_ref       = %{ $pg->{answers}->{$key} };
		my $unblessed_answer = \%answer_ref;
		$pg_answers_hash->{$key} = $unblessed_answer;
	}

	return {
		id      => Caliper::ResourceIri->new($c->ce)->answer($set_id, $problem_id, $user_id),
		type    => 'FillinBlankResponse',
		attempt => Caliper::Entity::answer_attempt(
			$c, $set_id, $version_id, $problem_id, $user_id, $pg, $start_time, $end_time
		),
		values     => \@answers,
		extensions => {
			source_file     => $last_answer->source_file,
			scores          => $last_answer->scores,
			comment         => $last_answer->comment_string,
			pg_answers_hash => $pg_answers_hash
		}
	};
}

sub answer_attempt ($c, $set_id, $version_id, $problem_id, $user_id, $pg, $start_time, $end_time) {
	my $resource_iri = Caliper::ResourceIri->new($c->ce);

	my $problem_user =
		$version_id
		? $c->db->getMergedProblemVersion($user_id, $set_id, $version_id, $problem_id)
		: $c->db->getMergedProblem($user_id, $set_id, $problem_id);
	my $last_answer_id =
		$c->db->latestProblemPastAnswer($user_id, ($version_id ? "$set_id,v$version_id" : $set_id), $problem_id);
	my $last_answer = $c->db->getPastAnswer($last_answer_id);
	my $attempt     = $version_id ? $version_id : scalar $c->db->listProblemPastAnswers($user_id, $set_id, $problem_id);
	my $score       = $problem_user->status || 0;
	$score = 0 if ($score > 1 || $score < 0);

	my $answer_attempt = {
		id          => $resource_iri->answer_attempt($set_id, $problem_id, $user_id, $last_answer->answer_id),
		type        => 'Attempt',
		assignee    => Caliper::Actor::generate_actor($c, $user_id),
		assignable  => $resource_iri->problem_user($set_id, $problem_id, $user_id),
		count       => $attempt + 0,                                                    # Make sure this is an int
		dateCreated => Caliper::Sensor::formatted_timestamp($last_answer->timestamp),
		extensions  => { attempt_score => $score }
	};

	if ($start_time) {
		$answer_attempt->{startedAtTime} = Caliper::Sensor::formatted_timestamp($start_time);

		if ($end_time) {
			$answer_attempt->{endedAtTime} = Caliper::Sensor::formatted_timestamp($end_time);
			$answer_attempt->{duration}    = Caliper::Sensor::formatted_duration($end_time - $start_time);
		}
	}

	return $answer_attempt;
}

sub problem_set_attempt ($c, $set_id, $version_id, $user_id, $start_time, $end_time) {
	my $resource_iri = Caliper::ResourceIri->new($c->ce);

	my $problem_set_user =
		$version_id
		? $c->db->getMergedSetVersion($user_id, $set_id, $version_id)
		: $c->db->getMergedSet($user_id, $set_id);

	my $attempt = 0;
	if ($version_id) {
		$attempt = $version_id;
	} else {
		my @problem_ids = $c->db->listGlobalProblems($set_id);
		for my $problem_id (@problem_ids) {
			$attempt += scalar $c->db->listProblemPastAnswers($user_id, $set_id, $problem_id);
		}
	}

	my $score      = grade_set($c->db, $problem_set_user, $user_id, $version_id ? 1 : 0);
	my $extensions = { attempt_score => $score, };

	if ($version_id) {
		$extensions->{gateway_score} = grade_gateway($c->db, $problem_set_user->set_id, $user_id);
	}

	my $problem_set_attempt = {
		id         => $resource_iri->problem_set_attempt($set_id, $user_id, $attempt),
		type       => 'Attempt',
		assignee   => Caliper::Actor::generate_actor($c, $user_id),
		assignable => $resource_iri->problem_set($set_id),
		count      => $attempt + 0,                                                      # Make sure this is an int
		extensions => $extensions
	};

	if ($start_time) {
		$problem_set_attempt->{startedAtTime} = Caliper::Sensor::formatted_timestamp($start_time);

		if ($end_time) {
			$problem_set_attempt->{endedAtTime} = Caliper::Sensor::formatted_timestamp($end_time);
			$problem_set_attempt->{duration}    = Caliper::Sensor::formatted_duration($end_time - $start_time);
		}
	}

	return $problem_set_attempt;
}

1;
