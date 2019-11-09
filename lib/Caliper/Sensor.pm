package Caliper::Sensor;

##### Library Imports #####
use strict;
use warnings;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Debug;
use Data::Dumper;
use JSON;
use Time::HiRes qw/gettimeofday/;
use Date::Format;

use HTTP::Request::Common;
use HTTP::Async;

use Caliper::Event;
use Caliper::ResourceIri;


# Constructor
sub new
{
	my ($class, $ce) = @_;
	my $self = {
		ce => $ce,
		enabled => $ce->{caliper}{enabled},
		host => $ce->{caliper}{host},
		api_key => $ce->{caliper}{api_key}
	};
	bless $self, $class;
	return $self;
}

sub caliperEnabled
{
	my $self = shift;
	return $self->{enabled} && exists $self->{host} && exists $self->{api_key};
}

sub sendEvent
{
	my ($self, $r, $event_hash) = @_;

	return $self->sendEvents($r, [ $event_hash ]);
}

sub sendEvents
{
	my ($self, $r, $array_of_events) = @_;
	return 0 unless $self->caliperEnabled();

	for my $event_hash (@$array_of_events) {
		Caliper::Event::add_defaults($r, $event_hash);
	}

	my $ce = $r->{ce};
	my $resource_iri = Caliper::ResourseIri->new($ce);
	my $async = HTTP::Async->new;

	# chunk events to prevent size issues (send a maximum of 3 events at a time)
	my $event_chunks = [];
	push(@$event_chunks, [ splice @$array_of_events, 0, 3 ]) while @$array_of_events;

	for my $event_chunk (@$event_chunks) {
		my $envelope = {
			'sensor' => $resource_iri->webwork(),
			'sendTime' => Caliper::Sensor::formatted_timestamp(time()),
			'dataVersion' => 'http://purl.imsglobal.org/ctx/caliper/v1p2',
			'data' => $event_chunk,
		};

		my $json_payload = JSON->new->canonical->encode($envelope);
		# debug("Caliper event json_payload: " . $json_payload);

		my $HTTPRequest = HTTP::Request->new('POST', $self->{host}, [
			'Accept' => '*/*',
			'Authorization' => 'Bearer ' . $self->{api_key},
			'Content-Type' => 'application/json',
		], $json_payload);
		$async->add($HTTPRequest);
	}

	while ( my $response = $async->wait_for_next_response ) {
		if (!$response->is_success) {
			debug("Caliper event post failed. Error Message: " . $response->message);
			debug($response->content);
			$self->log_error("Caliper event post failed. Error Message: ". $response->message . "\nResponse Content: ". $response->content);
		} else {
			debug("Caliper event post success. Success Message: " . $response->message);
			debug($response->content);
		}
	}
}

sub log_error
{
	my ($self, $error_message) = @_;
	my $ce = $self->{ce};
	my $logfile = $ce->{caliper}{errorlog};

	my ($sec, $msec) = gettimeofday;
	my $date = time2str("%a %b %d %H:%M:%S.$msec %Y", $sec);
	my $msg = "[$date] $error_message\n";

	# create if necessary
	unless (-e $logfile) {
		open my $fc, ">", $logfile;
		close $fc;
	}
	# append message
	if (open my $f, ">>", $logfile) {
		print $f $msg;
		close $f;
	}
	else {
		debug("Error, unable to open caliper error log file '$logfile' in append mode: $!");
	}
}

sub formatted_timestamp
{
	my ($time_value) = @_;
	# Note: webwork epoch timestamps do not include milliseconds
	return POSIX::strftime("%Y-%m-%dT%H:%M:%S.000Z", gmtime($time_value));
}

sub formatted_duration
{
	my ($duration) = @_;

	# gererate the time portion of a ISO 8601 formatted duration
	my $seconds = $duration % 60;
	my $minutes = int($duration / 60) % 60;
	my $hours = int($duration / 3600);

	my $output = "PT";
	if ($hours > 0) {
		$output .= $hours ."H";
	}
	if ($hours > 0 || $minutes > 0) {
		$output .= $minutes."M";
	}
	$output .= $seconds ."S";

	return $output;
}

1;
