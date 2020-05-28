package Caliper::ResourseIri;

##### Library Imports #####
use strict;
use warnings;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Debug;
use Data::Dumper;


# Constructor
sub new
{
	my ($class, $ce) = @_;

	# need to use $seed_ce in case of logout
	my $webwork_dir  = $WeBWorK::Constants::WEBWORK_DIRECTORY;
	my $seed_ce = new WeBWorK::CourseEnvironment({ webwork_dir => $webwork_dir });
	my $base_url = $seed_ce->{server_root_url} . $seed_ce->{webwork_url};
	if (defined($seed_ce->{caliper}{base_url}) && $seed_ce->{caliper}{base_url} ne '') {
		$base_url = $seed_ce->{caliper}{base_url};
	}
	if (substr($base_url, -1, 1) ne "/") {
		$base_url .= "/";
	}

	my $self = {
		ce => $ce,
		base_url => $base_url,
	};
	bless $self, $class;
	return $self;
}

sub getBaseUrl
{
	my $self = shift;
	return $self->{base_url};
}

sub webwork
{
	my $self = shift;
	return $self->getBaseUrl();
}

sub course
{
	my $self = shift;
	return $self->getBaseUrl() . $self->{ce}->{"courseName"} . '/';
}

sub actor_homepage
{
	my ($self, $user_id) = @_;
	return $self->course() . 'users/'.$user_id;
}

sub user_session
{
	my ($self, $session_key_hash) = @_;
	return $self->getBaseUrl() . 'session/'. $session_key_hash;
}

sub user_client
{
	my ($self, $session_key_hash) = @_;
	return $self->user_session($session_key_hash) . '/client';
}

sub user_membership
{
	my ($self, $user_id) = @_;
	return $self->course() . 'instructor/users2/?visible_users='.$user_id;
}

sub problem_set
{
	my ($self, $set_id) = @_;
	return $self->course() . $set_id . '/';
}

sub problem_set_user
{
	my ($self, $set_id, $user_id) = @_;
	return $self->problem_set($set_id) . '?effectiveUser=' . $user_id;
}

sub problem
{
	my ($self, $set_id, $problem_id) = @_;
	return $self->problem_set($set_id) . $problem_id . '/';
}

sub problem_user
{
	my ($self, $set_id, $problem_id, $user_id) = @_;
	return $self->problem($set_id, $problem_id) . '?effectiveUser=' . $user_id;
}

sub answer
{
	my ($self, $set_id, $problem_id, $user_id) = @_;
	return $self->problem($set_id, $problem_id) . 'answer/' . '?effectiveUser=' . $user_id;
}

sub answer_attempt
{
	my ($self, $set_id, $problem_id, $user_id, $answer_id) = @_;
	return $self->answer($set_id, $problem_id, $user_id) . '&answer_id=' . $answer_id;
}

sub problem_set_attempt
{
	my ($self, $set_id, $user_id, $attempt) = @_;
	return $self->problem_set_user($set_id, $user_id) . '&attempt=' . $attempt;
}

1;
