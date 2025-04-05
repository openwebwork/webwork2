package WeBWorK::DB::Schema::NewSQL::Versioned;
use Mojo::Base 'WeBWorK::DB::Schema::NewSQL::Std';

=head1 NAME

WeBWorK::DB::Schema::NewSQL::Versioned - provide access to versioned sets and problems.

=cut

use constant TABLES => qw(set_version problem_version);

# Override where clause generators that can be used with versioned sets or problems so that they only match versioned
# sets or problems (those are sets or problems with a version_id that is greater than zero).

sub where_DEFAULT {
	my ($self, $flags) = @_;
	return { version_id => { '>' => 0 } };
}

sub where_user_id_eq {
	my ($self, $flags, $user_id) = @_;
	return { user_id => $user_id, version_id => { '>' => 0 } };
}

sub where_user_id_like {
	my ($self, $flags, $user_id) = @_;
	return { user_id => { LIKE => $user_id }, version_id => { '>' => 0 } };
}

sub where_set_id_eq {
	my ($self, $flags, $set_id) = @_;
	return { set_id => $set_id, version_id => { '>' => 0 } };
}

sub where_user_id_eq_set_id_eq {
	my ($self, $flags, $user_id, $set_id) = @_;
	return { user_id => $user_id, set_id => $set_id, version_id => { '>' => 0 } };
}

sub where_user_id_eq_set_id_eq_version_id_eq {
	my ($self, $flags, $user_id, $set_id, $version_id) = @_;
	if ($version_id >= 1) {
		return { user_id => $user_id, set_id => $set_id, version_id => $version_id };
	} else {
		# nothing matches an invalid version id
		return { -and => \("0==1") };
	}
}

# For problem versions only (set versions don't have a problem_id field).
sub where_user_id_eq_set_id_eq_problem_id_eq {
	my ($self, $flags, $user_id, $set_id, $problem_id) = @_;
	return { user_id => $user_id, set_id => $set_id, version_id => { '>' => 0 }, problem_id => $problem_id };
}

# Override generic where clause methods to insist on version_id's greater than 0.

sub conv_where {
	my ($self, $where) = @_;
	$where->{version_id} = { '>' => 0 } if ref($where) eq 'HASH' && !exists $where->{version_id};
	return $self->SUPER::conv_where($where);
}

sub keyparts_to_where {
	my ($self, @keyparts) = @_;
	my $where = $self->SUPER::keyparts_to_where(@keyparts);
	$where->{version_id} = { '>' => 0 } unless exists $where->{version_id};
	return $where;
}

1;
