################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::Authen::Basic_TheLastOption;
use base qw/WeBWorK::Authen/;

=head1 NAME

WeBWorK::Authen::Basic_TheLastOption - Use only the functionality in WeBWorK::Authen.

This module provides only the functionality that is in the base
module WeBWor::Authen.  That module supports password
authentication and permits guest logins.  If one wants
to provide those options, then this module should
be the last one in the array of the Authen module hashes.

=cut

1;
