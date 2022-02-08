################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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
