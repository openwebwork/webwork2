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

package WeBWorK::Constants;
use base qw(Exporter);

=head1 NAME

WeBWorK::Constants - provide constant values for other WeBWorK modules.

=cut

use strict;
use warnings;

our @EXPORT    = qw();
our @EXPORT_OK = qw(SECRET);

use constant SECRET => 'fkjOPIiSUfeT6dm5pevSrM1xgFmsex7.Z/.6Wjcxqb9Pi4Zm9JUGygwv^FdG8^yth^*KbDFWMXiLtNDggWNA370llFj68JxNKMCyCeSJxCHRfU2P6br10HtPS!NvcaJ7';
