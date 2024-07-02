################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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
package WeBWorK::DB::Record::UserSetLocations;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::UserSetLocations - represent a record from the set_locations_user table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		user_id     => { type => "VARCHAR(100) NOT NULL", key => 1 },
		set_id      => { type => "VARCHAR(100) NOT NULL", key => 1 },
		location_id => { type => "VARCHAR(40) NOT NULL",  key => 1 },
	);
}

1;
