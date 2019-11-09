package Caliper::Event;

##### Library Imports #####
use strict;
use warnings;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Debug;
use Data::Dumper;
use Data::UUID;

use Caliper::Actor;
use Caliper::Sensor;

# Constructor
sub add_defaults
{
	my ($r, $event_hash) = @_;
	my $ce = $r->{ce};
	my $db = $r->{db};
	my $ug = new Data::UUID;

	my $user_id = $r->param('user');
	my $session_key = $r->param('key');
	my $uuid = $ug->create_str;
	my $actor = Caliper::Actor::generate_actor($ce, $db, $user_id);

	if (!exists($event_hash->{'@context'})) {
		$event_hash->{'@context'} = 'http://purl.imsglobal.org/ctx/caliper/v1p2';
	}
	$event_hash->{'id'} = 'urn:uuid:' . $uuid;
	$event_hash->{'actor'} = $actor;
	$event_hash->{'session'} = Caliper::Entity::session($ce, $db, $actor, $session_key);
	$event_hash->{'edApp'} = Caliper::Entity::webwork_app($ce, $db);
	$event_hash->{'group'} = Caliper::Entity::course($ce, $db);
	$event_hash->{'membership'} = Caliper::Entity::membership($ce, $db, $actor, $user_id);
	if (!exists($event_hash->{'eventTime'})) {
		$event_hash->{'eventTime'} = Caliper::Sensor::formatted_timestamp(time());
	}

	if (!exists($event_hash->{'extensions'})) {
		$event_hash->{'extensions'} = ();
	}
	if (defined($ENV{HTTP_REFERER})) {
		$event_hash->{'extensions'}{'referer'} = $ENV{HTTP_REFERER};
	}
}

1;
