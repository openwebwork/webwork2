package Caliper::Actor;

##### Library Imports #####
use strict;
use warnings;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Debug;
use Data::Dumper;

use Caliper::ResourceIri;

sub generate_anonymous_actor
{
	return {
		'id' => 'http://purl.imsglobal.org/caliper/Person',
		'type' => 'Person',
	};
}

sub generate_default_actor
{
	my ($ce, $db, $user) = @_;
	my $resource_iri = Caliper::ResourseIri->new($ce);

	return {
		'id' => $resource_iri->actor_homepage($user->user_id()),
		'type' => 'Person',
		'name' => $user->first_name() . " " . $user->last_name(),
	};
}

sub generate_actor
{
	my ($ce, $db, $user_id) = @_;

	if (!defined($user_id)) {
		return Caliper::Entity::generate_anonymous_actor();
	} else {
		my $user = $db->getUser($user_id);

		if (defined($ce->{caliper}{custom_actor_generator})) {
			return $ce->{caliper}{custom_actor_generator}($ce, $db, $user);
		} else {
			return Caliper::Entity::generate_default_actor($ce, $db, $user);
		}
	}
}

1;
