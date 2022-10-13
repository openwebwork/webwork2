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

package WeBWorK::Authen::RPC;
use parent 'WeBWorK::Authen';

=head1 NAME

WeBWorK::Authen::RPC - Authenticate xmlrpc requests.

=head1 DESCRIPTION

Instead of being called with a Mojolicious controller object this authentication
method gets its data from the request GET or POST parameters.  Note that the
WeBWorK::Authen module actually does this, so that is not a distinction of this
module.  The only actual distinction is that this module disables cookies.

This module should actually be deleted and cookies should only be sent by the
WeBWorK::Authen module when there is a browser to handle it.

This is typically used in combination with a WeBWorK::FakeRequest object which
fakes the essential properties of the WeBWorK::Request object needed for
authentication.

=cut

use strict;
use warnings;

# disable cookie functionality for xmlrpc
sub maybe_send_cookie { }
sub fetchCookie       { }
sub sendCookie        { }
sub killCookie        { }

1;
