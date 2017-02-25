################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authen/Proctor.pm,v 1.5 2007/04/04 15:05:27 glarose Exp $
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

package WeBWorK::Authen::XMLRPC;
use parent "WeBWorK::Authen";

=head1 NAME

WeBWorK::Authen::XMLRPC - Authenticate xmlrpc requests.

=cut

use strict;
use warnings;
use WeBWorK::Debug;

# Instead of being called with an apache request object $r 
# this authentication method gets its data  
# from an HTML data form.  It creates a WeBWorK::Authen::XMLRPC object  
# which fakes the essential properties of the WeBWorK::Request object needed for authentication


# sub new {
# 	my $class = shift;    
# 	my $fake_r = shift;
# 	my $user_authen_module = WeBWorK::Authen::class($ce, "user_module");
#     # runtime_use $user_authen_module;
#     $GENERIC_ERROR_MESSAGE = $fake_r->maketext("Invalid user ID or password.");
# 	my $authen = $user_authen_module->new($fake_r);
# 	return $authen;
# }

# disable cookie functionality for xmlrpc
sub connection {
	return 0;  #indicate that there is no connection
}
sub maybe_send_cookie {}
sub fetchCookie {}
sub sendCookie {}
sub killCookie {}



1;
