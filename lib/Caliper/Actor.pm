package Caliper::Actor;
use Mojo::Base -signatures;

use Caliper::ResourceIri;

sub generate_default_actor ($c, $user) {
	return {
		id   => Caliper::ResourceIri->new($c->ce)->actor_homepage($user->user_id),
		type => 'Person',
		name => $user->full_name
	};
}

sub generate_actor ($c, $user_id) {
	return { id => 'http://purl.imsglobal.org/caliper/Person', type => 'Person' } unless defined $user_id;

	my $user =
		$user_id eq $c->authen->{user_id}                   ? $c->authen->{user}
		: $user_id eq $c->authen->{effective_user}->user_id ? $c->authen->{effective_user}
		:                                                     $c->db->getUser($user_id);

	return $c->ce->{caliper}{custom_actor_generator}($c->ce, $c->db, $user)
		if ref $c->ce->{caliper}{custom_actor_generator} eq 'CODE';

	return generate_default_actor($c, $user);
}

1;
