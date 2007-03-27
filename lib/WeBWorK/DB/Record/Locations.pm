################################################################################# WeBWorK Online Homework Delivery System
# Copyright 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Record/Locations.pm,v 1.00 2007/03/01 15:49:14 dglin $
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
package WeBWorK::DB::Record::Locations;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Locations - represent a record from the locations table.

=cut

use strict;
use warnings;

BEGIN { 
	__PACKAGE__->_fields(
		location_id => { type=>"TINYBLOB NOT NULL", key=>1 },
		description => { type=>"TEXT" },
	);
}

1;
