package Caliper::Sensor;
use Mojo::Base -signatures, -async_await;

use Mojo::UserAgent;
use Mojo::Promise;
use Time::HiRes qw(gettimeofday);
use Date::Format;

use WeBWorK::Debug qw(debug);
use Caliper::Event;
use Caliper::ResourceIri;

sub new ($class, $c) {
	my $self = {
		c       => $c,
		enabled => $c->ce->{caliper}{enabled},
		host    => $c->ce->{caliper}{host},
		api_key => $c->ce->{caliper}{api_key}
	};
	bless $self, $class;
	return $self;
}

sub caliperEnabled ($self) {
	return $self->{enabled} && exists $self->{host} && exists $self->{api_key};
}

async sub sendEvent ($self, $event_hash) {
	return await $self->sendEvents([$event_hash]);
}

async sub sendEvents ($self, $array_of_events) {
	return 0 unless $self->caliperEnabled;

	my $c = $self->{c};
	for my $event_hash (@$array_of_events) {
		Caliper::Event::add_defaults($c, $event_hash);
	}

	my $ce = $c->ce;
	my $ua = Mojo::UserAgent->new;
	$ua->inactivity_timeout(5);
	$ua->request_timeout(10);

	# Chunk events to prevent size issues (send a maximum of 3 events at a time).
	my $event_chunks = [];
	push(@$event_chunks, [ splice @$array_of_events, 0, 3 ]) while @$array_of_events;

	my @promises;

	for my $event_chunk (@$event_chunks) {
		push(
			@promises,
			$ua->post_p(
				$self->{host},
				{
					Accept         => '*/*',
					Authorization  => 'Bearer ' . $self->{api_key},
					'Content-Type' => 'application/json',
				},
				json => {
					sensor      => Caliper::ResourceIri->new($ce)->webwork,
					sendTime    => formatted_timestamp(time),
					dataVersion => 'http://purl.imsglobal.org/ctx/caliper/v1p2',
					data        => $event_chunk
				}
			)
		);
	}

	my @responses = await Mojo::Promise->all(@promises)->catch(sub {
		my $err = shift;
		$self->log_error(ref $err ? $err->message : $err);
		return;
	});

	for my $response (@responses) {
		my $result = $response->[0]->result;
		if (!$result->is_success) {
			debug('Caliper event post failed. Error Message: ' . $result->message);
			debug($result->body);
			$self->log_error('Caliper event post failed. Error Message: '
					. $result->message
					. "\nResponse Content: "
					. $result->body);
		} else {
			debug('Caliper event post success. Success Message: ' . $result->message);
			debug($result->body);
		}
	}

	return;
}

sub log_error ($self, $error_message) {
	my $ce      = $self->{c}->ce;
	my $logfile = $ce->{caliper}{errorlog};

	my ($sec, $msec) = gettimeofday;
	my $date = time2str("%a %b %d %H:%M:%S.$msec %Y", $sec);
	my $msg  = "[$date] $error_message\n";

	# create if necessary
	unless (-e $logfile) {
		open my $fc, '>', $logfile;
		close $fc;
	}
	# append message
	if (open my $f, '>>', $logfile) {
		print $f $msg;
		close $f;
	} else {
		debug("Error, unable to open caliper error log file '$logfile' in append mode: $!");
	}
	return;
}

sub formatted_timestamp ($time_value) {
	return POSIX::strftime('%Y-%m-%dT%H:%M:%S.000Z', gmtime($time_value));
}

sub formatted_duration ($duration) {
	# Generate the time portion of a ISO 8601 formatted duration.
	my $seconds = $duration % 60;
	my $minutes = int($duration / 60) % 60;
	my $hours   = int($duration / 3600);

	my $output = 'PT';
	$output .= $hours . 'H'   if $hours > 0;
	$output .= $minutes . 'M' if $hours > 0 || $minutes > 0;
	$output .= $seconds . 'S';

	return $output;
}

1;
