package Caliper::Event;
use Mojo::Base -signatures;

use UUID::Tiny ':std';

use Caliper::Actor;
use Caliper::Entity;
use Caliper::Sensor;

sub add_defaults ($c, $event_hash) {
	my $user_id = $c->param('user');
	my $actor   = Caliper::Actor::generate_actor($c, $user_id);

	$event_hash->{'@context'} = 'http://purl.imsglobal.org/ctx/caliper/v1p2' unless exists $event_hash->{'@context'};
	$event_hash->{id}         = 'urn:uuid:' . create_uuid_as_string(UUID_V4);
	$event_hash->{actor}      = $actor;
	$event_hash->{session}    = Caliper::Entity::session($c, $actor, $c->param('key') // '');
	$event_hash->{edApp}      = Caliper::Entity::webwork_app($c);
	$event_hash->{group}      = Caliper::Entity::course($c);
	$event_hash->{membership} = Caliper::Entity::membership($c, $actor, $user_id);
	$event_hash->{eventTime}  = Caliper::Sensor::formatted_timestamp(time) unless exists $event_hash->{eventTime};
	$event_hash->{extensions} = ()                                         unless exists $event_hash->{extensions};
	$event_hash->{extensions}{referer} = $c->req->headers->referer if defined $c->req->headers->referer;
	return;
}

1;
