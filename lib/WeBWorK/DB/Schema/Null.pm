################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader$
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
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

sub list   { return ();      }
sub exists { return 1;       }
sub add    { return 0;       }
sub get    { return undef;   }
sub gets   { return (undef); }
sub put    { return 0;       }
sub delete { return 1;       }

1;
