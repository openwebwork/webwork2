package WeBWorK::DB::Driver;

=head1 NAME

WeBWorK::DB::Driver - superclass of database driver modules.

=cut

use strict;
use warnings;

################################################################################
# constructor
################################################################################

sub new($$$) {
	my ($proto, $source, $params) = @_;
	my $class = ref($proto) || $proto;
	my $self  = {
		source => $source,
		params => $params,
	};
	bless $self, $class;
	return $self;
}

1;
