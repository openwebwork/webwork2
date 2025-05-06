package WeBWorK::DB::Schema::NewSQL::NonVersioned;
use base qw(WeBWorK::DB::Schema::NewSQL::Std);

=head1 NAME

WeBWorK::DB::Schema::NewSQL::NonVersioned - provide access to non-versioned sets.

=cut

use strict;
use warnings;
use WeBWorK::DB::Utils qw/make_vsetID/;

use constant TABLES => qw/set_user problem_user/;

################################################################################
# where clause
################################################################################

# Override where clause generators that can be used with non-versioned sets so
# that they only match non-versioned sets.

sub where_DEFAULT {
	my ($self, $flags) = @_;
	return { set_id => { NOT_LIKE => make_vsetID("%", "%") } };
}

sub where_user_id_eq {
	my ($self, $flags, $user_id) = @_;
	return { user_id => $user_id, set_id => { NOT_LIKE => make_vsetID("%", "%") } };
}

sub where_user_id_like {
	my ($self, $flags, $user_id) = @_;
	return { user_id => { LIKE => $user_id }, set_id => { NOT_LIKE => make_vsetID("%", "%") } };
}

################################################################################
# override keyparts_to_where to limit scope of where clauses
################################################################################

sub keyparts_to_where {
	my ($self, @keyparts) = @_;

	my $where = $self->SUPER::keyparts_to_where(@keyparts);

	unless (exists $where->{set_id}) {
		$where->{set_id} = { NOT_LIKE => make_vsetID("%", "%") };
	}

	return $where;
}

1;
