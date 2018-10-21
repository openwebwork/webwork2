################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Driver/Null.pm,v 1.5 2006/01/25 23:13:54 sh002i Exp $
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
