package WeBWorK::DB::Driver::Null;
use base qw(WeBWorK::DB::Driver);

=head1 NAME

WeBWorK::DB::Driver::Null - a dummy driver.

=cut

use strict;
use warnings;

use constant STYLE => "null";

################################################################################
# common methods
################################################################################

sub connect    { return 0; }
sub disconnect { return 0; }

1;
