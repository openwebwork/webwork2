package WeBWorK::DB::Schema::NewSQL::NonVersioned;
use Mojo::Base 'WeBWorK::DB::Schema::NewSQL::Std';

=head1 NAME

WeBWorK::DB::Schema::NewSQL::NonVersioned - provide access to non-versioned sets.

=cut

use constant TABLES => qw(set_user problem_user);

# Override where clause generators that can be used with non-versioned sets or problems so that they
# only match non-versioned sets or problems (those are sets or problems with version_id equal to 0).

sub where_DEFAULT {
	my ($self, $flags) = @_;
	return { version_id => 0 };
}

sub where_user_id_eq {
	my ($self, $flags, $user_id) = @_;
	return { user_id => $user_id, version_id => 0 };
}

sub where_user_id_like {
	my ($self, $flags, $user_id) = @_;
	return { user_id => { LIKE => $user_id }, version_id => 0 };
}

sub where_set_id_eq {
	my ($self, $flags, $set_id) = @_;
	return { set_id => $set_id, version_id => 0 };
}

sub where_set_id_eq_problem_id_eq {
	my ($self, $flags, $set_id, $problem_id) = @_;
	return { set_id => $set_id, problem_id => $problem_id, version_id => 0 };
}

sub where_user_id_eq_set_id_eq {
	my ($self, $flags, $user_id, $set_id) = @_;
	return { user_id => $user_id, set_id => $set_id, version_id => 0 };
}

# Override generic where clause methods to insist on a version_id of 0.

sub conv_where {
	my ($self, $where) = @_;
	$where->{version_id} = 0 if ref($where) eq 'HASH' && !exists $where->{version_id};
	return $self->SUPER::conv_where($where);
}

sub keyparts_to_where {
	my ($self, @keyparts) = @_;
	my $where = $self->SUPER::keyparts_to_where(@keyparts);
	$where->{version_id} = 0 unless exists $where->{version_id};
	return $where;
}

1;
