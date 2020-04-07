package Caliper::Entity;

##### Library Imports #####
use strict;
use warnings;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Debug;
use Data::Dumper;
use WeBWorK::Utils::Tags;
use Digest::SHA qw(sha1_base64);

use Caliper::ResourceIri;
use Caliper::Sensor;
use Caliper::Actor;
use WeBWorK::Utils qw(grade_set grade_gateway);

sub webwork_app
{
	my ($ce, $db) = @_;
	my $resource_iri = Caliper::ResourseIri->new($ce);

	# $ce doesn't have WW_VERSION when doing login/logout for some reason
	my $webwork_dir  = $WeBWorK::Constants::WEBWORK_DIRECTORY;
	my $seed_ce = new WeBWorK::CourseEnvironment({ webwork_dir => $webwork_dir });
	my $ww_version = $seed_ce->{WW_VERSION}||"unknown";

	return {
		'id' => $resource_iri->webwork(),
		'type' => 'SoftwareApplication',
		'name' => 'WeBWorK',
		'version' => $ww_version,
	};
}

sub session
{
	my ($ce, $db, $actor, $session_key) = @_;
	my $resource_iri = Caliper::ResourseIri->new($ce);
	my $session_key_hash = sha1_base64($session_key);

	return {
		'id' => $resource_iri->user_session($session_key_hash),
		'type' => 'Session',
		'user' => $actor,
		'client' => Caliper::Entity::client($ce, $db, $session_key_hash),
	};
}

sub client
{
	my ($ce, $db, $session_key_hash) = @_;
	my $resource_iri = Caliper::ResourseIri->new($ce);

	my $ip_address = '';
	if ($ENV{HTTP_X_FORWARDED_FOR}) {
		$ip_address = $ENV{HTTP_X_FORWARDED_FOR};
	} elsif ($ENV{REMOTE_ADDR}) {
		$ip_address = $ENV{REMOTE_ADDR};
	} elsif ($ENV{HTTP_CLIENT_IP}) {
		$ip_address = $ENV{HTTP_CLIENT_IP};
	}

	return {
		'id' => $resource_iri->user_client($session_key_hash),
		'type' => 'SoftwareApplication',
		'userAgent' => $ENV{HTTP_USER_AGENT},
		'ipAddress' => $ip_address,
		'host' => $ENV{HTTP_HOST},
	};
}

sub membership
{
	my ($ce, $db, $actor, $user_id) = @_;
	my $resource_iri = Caliper::ResourseIri->new($ce);

	my $user = $db->getUser($user_id);
	my $permission = $db->getPermissionLevel($user_id);

	my $roles = [];
	my $status = '';

	if ($user->status() ne 'D') {
		$status = 'Active';
	} else {
		$status = 'Inactive';
	}

	if ($permission->permission() == $ce->{userRoles}{admin}) {
		push @$roles, 'Administrator';
	} elsif ($permission->permission() == $ce->{userRoles}{professor}) {
		push @$roles, 'Instructor';
	} elsif ($permission->permission() == $ce->{userRoles}{ta}) {
		push @$roles, 'Instructor';
		push @$roles, 'Instructor#TeachingAssistant';
	} elsif ($permission->permission() == $ce->{userRoles}{grade_proctor}) {
		push @$roles, 'Instructor';
		push @$roles, 'Instructor#Grader';
	} elsif ($permission->permission() == $ce->{userRoles}{login_proctor}) {
		push @$roles, 'Instructor';
		push @$roles, 'Instructor#GuestInstructor';
	} elsif ($permission->permission() == $ce->{userRoles}{student}) {
		push @$roles, 'Learner';
	}
	# guest and nobody aren't tracked

	return {
		'id' => $resource_iri->user_membership($user_id),
		'type' => 'Membership',
		'member' => $actor,
		'organization' => $resource_iri->course(),
		'roles' => $roles,
		'status' => $status,
	};
}

sub course
{
	my ($ce, $db) = @_;
	my $resource_iri = Caliper::ResourseIri->new($ce);

	my $course_entity = {
		'id' => $resource_iri->course(),
		'type' => 'CourseOffering',
	};

	if ($db->settingExists('courseTitle')) {
		$course_entity->{'name'} = $db->getSettingValue('courseTitle');
	}

	return $course_entity;
}

sub problem_set
{
	my ($ce, $db, $set_id) = @_;
	my $resource_iri = Caliper::ResourseIri->new($ce);

	my $problem_set = $db->getGlobalSet($set_id);

	my $items = [];
	my @problem_ids = $db->listGlobalProblems($set_id);
	for my $problem_id (@problem_ids) {
		push(@$items, {
			'id' => $resource_iri->problem($set_id, $problem_id),
			'type' => 'AssessmentItem',
		});
	}

	my $problem_set_entity = {
		'id' => $resource_iri->problem_set($set_id),
		'type' => 'Assessment',
		'isPartOf' => Caliper::Entity::course($ce, $db),
		'name' => $set_id,
		'items' => $items,
		'dateToStartOn' => Caliper::Sensor::formatted_timestamp($problem_set->open_date()),
		'dateToSubmit' => Caliper::Sensor::formatted_timestamp($problem_set->due_date()),
		'extensions' => {
			'answer_date' => $problem_set->answer_date(),
			'reduced_scoring_date' => $problem_set->reduced_scoring_date(),
			'visible' => $problem_set->visible(),
			'enable_reduced_scoring' => $problem_set->enable_reduced_scoring(),
			'description' => $problem_set->description(),
			'restricted_release' => $problem_set->restricted_release(),
			'restricted_status' => $problem_set->restricted_status(),
			'attempts_per_version' => $problem_set->attempts_per_version(),
			'time_interval' => $problem_set->time_interval(),
			'versions_per_interval' => $problem_set->versions_per_interval(),
			'version_time_limit' => $problem_set->version_time_limit(),
			'version_creation_time' => $problem_set->version_creation_time(),
			'problem_randorder' => $problem_set->problem_randorder(),
			'version_last_attempt_time' => $problem_set->version_last_attempt_time(),
			'problems_per_page' => $problem_set->problems_per_page(),
			'hide_score' => $problem_set->hide_score(),
			'hide_score_by_problem' => $problem_set->hide_score_by_problem(),
			'hide_work' => $problem_set->hide_work(),
			'time_limit_cap' => $problem_set->time_limit_cap(),
			'restrict_ip' => $problem_set->restrict_ip(),
			'relax_restrict_ip' => $problem_set->relax_restrict_ip(),
			'restricted_login_proctor' => $problem_set->restricted_login_proctor(),
			'hide_hint' => $problem_set->hide_hint(),
			'restrict_prob_progression' => $problem_set->restrict_prob_progression(),
		}
	};

	if (defined($problem_set->description()) && $problem_set->description() ne '') {
		$problem_set_entity->{'description'} = $problem_set->description();
	}

	return $problem_set_entity;
}

sub problem
{
	my ($ce, $db, $set_id, $problem_id) = @_;
	my $resource_iri = Caliper::ResourseIri->new($ce);

	my $problem = $db->getGlobalProblem($set_id, $problem_id);

	my $templateDir = $ce->{courseDirs}->{templates};
	my $tags = WeBWorK::Utils::Tags->new($templateDir.'/'.$problem->source_file());
	my $keywords = $tags->{'keywords'};
	$_ =~ s/(^[\s"']+)|([\s"']+$)//g for @$keywords;

	my %tags_ref = %$tags;
	my $unblessed_tags = \%tags_ref;

	return {
		'id' => $resource_iri->problem($set_id, $problem_id),
		'type' => 'AssessmentItem',
		'name' => 'Problem ' . $problem_id,
		'isPartOf' => Caliper::Entity::problem_set($ce, $db, $set_id),
		'keywords' => $keywords,
		'extensions' => {
			'source_file' => $problem->source_file(),
			'value' => $problem->value(),
			'max_attempts' => $problem->max_attempts(),
			'att_to_open_children' => $problem->att_to_open_children(),
			'counts_parent_grade' => $problem->counts_parent_grade(),
			'showMeAnother' => $problem->showMeAnother(),
			'showMeAnotherCount' => $problem->showMeAnotherCount(),
			'prPeriod' => $problem->prPeriod(),
			'prCount' => $problem->prCount(),
			'flags' => $problem->flags(),
			'tags' => $unblessed_tags,
		},
	};
}

sub problem_user
{
	my ($ce, $db, $set_id, $version_id, $problem_id, $user_id, $pg) = @_;
	my $resource_iri = Caliper::ResourseIri->new($ce);

	my $problem_user = $version_id ?
		$db->getMergedProblemVersion($user_id, $set_id, $version_id, $problem_id) :
		$db->getMergedProblem($user_id, $set_id, $problem_id);

	my $templateDir = $ce->{courseDirs}->{templates};
	my $tags = WeBWorK::Utils::Tags->new($templateDir.'/'.$problem_user->source_file());
	my $keywords = $tags->{'keywords'};
	$_ =~ s/(^[\s"']+)|([\s"']+$)//g for @$keywords;

	my %tags_ref = %$tags;
	my $unblessed_tags = \%tags_ref;

	my $correct_answers = [];
	foreach my $ans_id (@{$pg->{flags}->{ANSWER_ENTRY_ORDER}//[]} ) {
		push @$correct_answers, $pg->{'answers'}->{$ans_id}->{'correct_value'};
	}

	return {
		'id' => $resource_iri->problem_user($set_id, $problem_id, $user_id),
		'type' => 'AssessmentItem',
		'name' => 'Problem ' . $problem_id,
		'isPartOf' => Caliper::Entity::problem($ce, $db, $set_id, $problem_id),
		'keywords' => $keywords,
		'extensions' => {
			'correct_answers' => $correct_answers,
			'source_file' => $problem_user->source_file(),
			'value' => $problem_user->value(),
			'max_attempts' => $problem_user->max_attempts(),
			'att_to_open_children' => $problem_user->att_to_open_children(),
			'counts_parent_grade' => $problem_user->counts_parent_grade(),
			'showMeAnother' => $problem_user->showMeAnother(),
			'showMeAnotherCount' => $problem_user->showMeAnotherCount(),
			'prPeriod' => $problem_user->prPeriod(),
			'prCount' => $problem_user->prCount(),
			'flags' => $problem_user->flags(),
			'tags' => $unblessed_tags,
			'problem_seed' => $problem_user->problem_seed(),
			'source_text' => $problem_user->status(),
			'problem_source_code' => $pg->{'translator'}->{'source'},
			'problem_html_text' => $pg->{'body_text'},
			'status' => $problem_user->status(),
			'attempted' => $problem_user->attempted(),
			'last_answer' => $problem_user->last_answer(),
			'num_correct' => $problem_user->num_correct(),
			'num_incorrect' => $problem_user->num_incorrect(),
			'sub_status' => $problem_user->sub_status(),
		}
	};
}

sub answer
{
	my ($ce, $db, $set_id, $version_id, $problem_id, $user_id, $pg, $start_time, $end_time) = @_;
	my $resource_iri = Caliper::ResourseIri->new($ce);

	my $last_answer_id = $db->latestProblemPastAnswer($ce->{"courseName"}, $user_id, ($version_id ? "$set_id,v$version_id" : $set_id), $problem_id);
	my $last_answer = $db->getPastAnswer($last_answer_id);
	my @answers = split(/\t/, $last_answer->answer_string());

	my $pg_answers_hash = {};
	foreach my $key (keys %{$pg->{'answers'}})
	{
		my %answer_ref = %{$pg->{'answers'}->{$key}};
		my $unblessed_answer = \%answer_ref;
		$pg_answers_hash->{$key} = $unblessed_answer;
	}

	return {
		'id' => $resource_iri->answer($set_id, $problem_id, $user_id),
		'type' => 'FillinBlankResponse',
		'attempt' => Caliper::Entity::answer_attempt($ce, $db, $set_id, $version_id, $problem_id, $user_id, $pg, $start_time, $end_time),
		'values' => \@answers,
		'extensions' => {
			'source_file' => $last_answer->source_file(),
			'scores' => $last_answer->scores(),
			'comment' => $last_answer->comment_string(),
			'pg_answers_hash' => $pg_answers_hash,
		}
	};
}

sub answer_attempt
{
	my ($ce, $db, $set_id, $version_id, $problem_id, $user_id, $pg, $start_time, $end_time) = @_;
	my $resource_iri = Caliper::ResourseIri->new($ce);

	my $problem_user = $version_id ?
		$db->getMergedProblemVersion($user_id, $set_id, $version_id, $problem_id) :
		$db->getMergedProblem($user_id, $set_id, $problem_id);
	my $last_answer_id = $db->latestProblemPastAnswer($ce->{"courseName"}, $user_id, ($version_id ? "$set_id,v$version_id" : $set_id), $problem_id);
	my $last_answer = $db->getPastAnswer($last_answer_id);
	my $attempt = $version_id ? $version_id : scalar $db->listProblemPastAnswers($ce->{"courseName"}, $user_id, $set_id, $problem_id);
    my $score = $problem_user->status || 0;
	$score = 0 if ($score > 1 || $score < 0 );

	my $answer_attempt = {
		'id' => $resource_iri->answer_attempt($set_id, $problem_id, $user_id, $last_answer->answer_id()),
		'type' => 'Attempt',
		'assignee' => Caliper::Actor::generate_actor($ce, $db, $user_id),
		'assignable' => $resource_iri->problem_user($set_id, $problem_id, $user_id),
		'count' => $attempt + 0, #ensure int
		'dateCreated' => Caliper::Sensor::formatted_timestamp($last_answer->timestamp()),
		'extensions' => {
			'attempt_score' => $score,
		}
	};

	if ($start_time) {
		$answer_attempt->{'startedAtTime'} = Caliper::Sensor::formatted_timestamp($start_time);

		if ($end_time) {
			$answer_attempt->{'endedAtTime'} = Caliper::Sensor::formatted_timestamp($end_time);
			$answer_attempt->{'duration'} = Caliper::Sensor::formatted_duration($end_time - $start_time);
		}
	}

	return $answer_attempt;
}

sub problem_set_attempt
{
	my ($ce, $db, $set_id, $version_id, $user_id, $start_time, $end_time) = @_;
	my $resource_iri = Caliper::ResourseIri->new($ce);

	my $problem_set_user = $version_id ?
		$db->getMergedSetVersion($user_id, $set_id, $version_id) :
		$db->getMergedSet($user_id, $set_id);

	my $attempt = 0;
	if ($version_id) {
		$attempt = $version_id;
	} else {
		my @problem_ids = $db->listGlobalProblems($set_id);
		for my $problem_id (@problem_ids) {
			$attempt += scalar $db->listProblemPastAnswers($ce->{"courseName"}, $user_id, $set_id, $problem_id);
		}
	}

	my $score = grade_set($db, $problem_set_user, $problem_set_user->set_id, $user_id, ($version_id ? 1 : 0));
	my $extensions = {
		'attempt_score' => $score,
	};

	if ($version_id) {
		$extensions->{'gateway_score'} = grade_gateway($db, $problem_set_user, $problem_set_user->set_id, $user_id);
	}

	my $problem_set_attempt = {
		'id' => $resource_iri->problem_set_attempt($set_id, $user_id, $attempt),
		'type' => 'Attempt',
		'assignee' => Caliper::Actor::generate_actor($ce, $db, $user_id),
		'assignable' => $resource_iri->problem_set($set_id),
		'count' => $attempt + 0, #ensure int
		'extensions' => $extensions,
	};

	if ($start_time) {
		$problem_set_attempt->{'startedAtTime'} = Caliper::Sensor::formatted_timestamp($start_time);

		if ($end_time) {
			$problem_set_attempt->{'endedAtTime'} = Caliper::Sensor::formatted_timestamp($end_time);
			$problem_set_attempt->{'duration'} = Caliper::Sensor::formatted_duration($end_time - $start_time);
		}
	}

	return $problem_set_attempt;
}

1;
