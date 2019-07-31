################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/RPC/Request.pm,v 1.1 2006/07/28 04:33:28 sh002i Exp $
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

package WeBWorK::RPC::Request;
use base "WeBWorK::Request";

=head1 NAME

WeBWorK::Request - a request to the WeBWorK system, a subclass of
Apache::Request with additional WeBWorK-specific fields.

=cut

use strict;
use warnings;

=head1 CONSTRUCTOR

=over

=item new(@args)

Creates an new WeBWorK::RPC::Request. No underlying Apache[2]::Request is created.

=cut

sub new {
	my ($invocant, @args) = @_;
	my $class = ref $invocant || $invocant;
	return bless {}, $class;
}

=back

=cut

1;
