################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Schema::Null;
use base qw(WeBWorK::DB::Schema);

=head1 NAME

WeBWorK::DB::Schema::Null - a dummy schema with no backend.

=cut

use strict;
use warnings;

use constant TABLES => qw(password permission key user set set_user problem problem_user);
use constant STYLE  => "null";

################################################################################
# table access functions
################################################################################

sub list   { return ();    }
sub exists { return 1;     }
sub add    { return 0;     }
sub get    { return undef; }
sub put    { return 0;     }
sub delete { return 1;     }

1;
