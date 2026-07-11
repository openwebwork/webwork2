package Mojolicious::WeBWorK::Plugin::Caliper;
use Mojo::Base 'Mojolicious::Plugin', -signatures, -async_await;

use Caliper::Sensor;
use Caliper::Entity;

sub register ($plugin, $app, $config) {
	$app->hook(
		user_login => async sub ($c) {
			my $caliper_sensor = Caliper::Sensor->new($c);
			return unless $caliper_sensor->caliperEnabled;
			await $caliper_sensor->sendEvents([ {
				type    => 'SessionEvent',
				action  => 'LoggedIn',
				profile => 'SessionProfile',
				object  => Caliper::Entity::webwork_app($c)
			} ]);
			return;
		}
	);

	$app->hook(
		user_logout => async sub ($c) {
			my $caliper_sensor = Caliper::Sensor->new($c);
			return unless $caliper_sensor->caliperEnabled;
			await $caliper_sensor->sendEvents([ {
				type    => 'SessionEvent',
				action  => 'LoggedOut',
				profile => 'SessionProfile',
				object  => Caliper::Entity::webwork_app($c)
			} ]);
			return;
		}
	);

	$app->hook(
		answer_submitted => async sub ($c) {
			my $ce = $c->ce;
			my $db = $c->db;

			my $caliper_sensor = Caliper::Sensor->new($c);
			if ($caliper_sensor->caliperEnabled
				&& defined $ce->{courseFiles}{logs}{answer_log}
				&& !$c->authz->hasPermissions($c->param('effectiveUser'), 'dont_log_past_answers'))
			{
				my $startTime = $c->param('startTime');
				$c->param('startTime', '');

				my $endTime = time;

				await $caliper_sensor->sendEvents([
					{
						type    => 'AssessmentItemEvent',
						action  => 'Completed',
						profile => 'AssessmentProfile',
						object  => Caliper::Entity::problem_user(
							$c,
							$c->{problem}->set_id,
							0,    # Version is 0 for non-gateway problems.
							$c->{problem}->problem_id,
							$c->{problem}->user_id,
							$c->{pg}
						),
						generated => Caliper::Entity::answer(
							$c,
							$c->{problem}->set_id,
							0,    # Version is 0 for non-gateway problems.
							$c->{problem}->problem_id,
							$c->{problem}->user_id,
							$c->{pg},
							$startTime,
							$endTime
						),
					},
					{
						type      => 'AssessmentEvent',
						action    => 'Submitted',
						profile   => 'AssessmentProfile',
						object    => Caliper::Entity::problem_set($c, $c->{problem}->set_id),
						generated => Caliper::Entity::problem_set_attempt(
							$c,
							$c->{problem}->set_id,
							0,    # Version is 0 for non-gateway problems.
							$c->{problem}->user_id,
							$startTime,
							$endTime
						),
					},
					{
						type    => 'ToolUseEvent',
						action  => 'Used',
						profile => 'ToolUseProfile',
						object  => Caliper::Entity::webwork_app($c)
					}
				]);
			}

			return;
		}
	);

	$app->hook(
		test_answers_submitted => async sub ($c) {
			my $ce = $c->ce;
			my $db = $c->db;

			my $caliper_sensor = Caliper::Sensor->new($c);
			if ($caliper_sensor->caliperEnabled && defined $ce->{courseFiles}{logs}{answer_log}) {
				my $events = [];

				my $setID = $c->stash('setID') =~ s/,v\d+$//r;

				my $startTime = $c->param('startTime');
				$c->param('startTime', '');

				my $endTime = int($c->submitTime);
				if ($c->{submitAnswers} && $c->{will}{recordAnswers}) {
					for my $i (0 .. $#{ $c->stash->{problems} }) {
						my $problem = $c->stash->{problems}[ $c->stash->{probOrder}[$i] ];
						my $pg      = $c->stash->{pg_results}[ $c->stash->{probOrder}[$i] ];
						push(
							@$events,
							{
								type    => 'AssessmentItemEvent',
								action  => 'Completed',
								profile => 'AssessmentProfile',
								object  => Caliper::Entity::problem_user(
									$c,                   $problem->set_id,  $c->{set}->version_id,
									$problem->problem_id, $problem->user_id, $pg
								),
								generated => Caliper::Entity::answer(
									$c,
									$problem->set_id,
									$c->{set}->version_id,
									$problem->problem_id,
									$problem->user_id,
									$pg,
									0,
									0    # Don't track start/end time for gateway problems (multiple answers per page).
								),
							}
						);
					}
					push(
						@$events,
						{
							type      => 'AssessmentEvent',
							action    => 'Submitted',
							profile   => 'AssessmentProfile',
							object    => Caliper::Entity::problem_set($c, $setID),
							generated => Caliper::Entity::problem_set_attempt(
								$c, $setID,
								$c->{set}->version_id,
								$c->param('effectiveUser'),
								$startTime, $endTime
							),
						}
					);
				} else {
					push(
						@$events,
						{
							type      => 'AssessmentEvent',
							action    => 'Paused',
							profile   => 'AssessmentProfile',
							object    => Caliper::Entity::problem_set($c, $setID),
							generated => Caliper::Entity::problem_set_attempt(
								$c, $setID,
								$c->{set}->version_id,
								$c->param('effectiveUser'),
								$startTime, $endTime
							),
						}
					);
				}
				push(
					@$events,
					{
						type    => 'ToolUseEvent',
						action  => 'Used',
						profile => 'ToolUseProfile',
						object  => Caliper::Entity::webwork_app($c)
					}
				);

				await $caliper_sensor->sendEvents($events);
			}

			return;
		}
	);

	return;
}

1;
