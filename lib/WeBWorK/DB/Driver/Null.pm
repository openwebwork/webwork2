################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Driver::Null;

=head1 NAME

WeBWorK::DB::Driver::Null - a dummy driver.

=cut

use strict;
use warnings;
use GDBM_File;
use Carp;

use constant STYLE => "dummy";

################################################################################
# static functions
################################################################################

sub style() {
	return STYLE;
}

################################################################################
# constructor
################################################################################

sub new($$$) {
	my ($proto, $source, $params) = @_;
	my $class = ref($proto) || $proto;
	my $self = {
		hash   => {},
		source => $source,
		params => $params,
	};
	bless $self, $class;
	return $self;
}

################################################################################
# common methods
################################################################################

sub connect    { return 0; }
sub disconnect { return 0; }

1;
