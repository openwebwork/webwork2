package Caliper::ResourceIri;
use Mojo::Base -signatures;

sub new ($class, $ce) {
	my $base_url = $ce->{server_root_url} . $ce->{webwork_url};
	$base_url .= '/' if substr($base_url, -1, 1) ne '/';
	return bless { ce => $ce, base_url => $base_url }, $class;
}

sub getBaseUrl ($self) {
	return $self->{base_url};
}

sub webwork ($self) {
	return $self->getBaseUrl;
}

sub course ($self) {
	return $self->getBaseUrl . $self->{ce}{courseName} . '/';
}

sub actor_homepage ($self, $user_id) {
	return $self->course . 'users/' . $user_id;
}

sub user_session ($self, $session_key_hash) {
	return $self->getBaseUrl . 'session/' . $session_key_hash;
}

sub user_client ($self, $session_key_hash) {
	return $self->user_session($session_key_hash) . '/client';
}

sub user_membership ($self, $user_id) {
	return $self->course . 'instructor/users2/?visible_users=' . $user_id;
}

sub problem_set ($self, $set_id) {
	return $self->course . $set_id . '/';
}

sub problem_set_user ($self, $set_id, $user_id) {
	return $self->problem_set($set_id) . '?effectiveUser=' . $user_id;
}

sub problem ($self, $set_id, $problem_id) {
	return $self->problem_set($set_id) . $problem_id . '/';
}

sub problem_user ($self, $set_id, $problem_id, $user_id) {
	return $self->problem($set_id, $problem_id) . '?effectiveUser=' . $user_id;
}

sub answer ($self, $set_id, $problem_id, $user_id) {
	return $self->problem($set_id, $problem_id) . 'answer/' . '?effectiveUser=' . $user_id;
}

sub answer_attempt ($self, $set_id, $problem_id, $user_id, $answer_id) {
	return $self->answer($set_id, $problem_id, $user_id) . '&answer_id=' . $answer_id;
}

sub problem_set_attempt ($self, $set_id, $user_id, $attempt) {
	return $self->problem_set_user($set_id, $user_id) . '&attempt=' . $attempt;
}

1;
