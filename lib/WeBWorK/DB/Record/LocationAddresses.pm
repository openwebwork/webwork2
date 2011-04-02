################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/bin/readURClassList.pl,v 1.2.2.1 2007/08/13 22:53:39 sh002i Exp $
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
package WeBWorK::DB::Record::LocationAddresses;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::LocationAddresses - represent a record from the location_addresses table.

=cut

use strict;
use warnings;

BEGIN { 
	__PACKAGE__->_fields(
		location_id => { type=>"TINYBLOB NOT NULL", key=> 1 },
		ip_mask     => { type=>"VARCHAR(255)", key=> 1 },
	);
}

1;
