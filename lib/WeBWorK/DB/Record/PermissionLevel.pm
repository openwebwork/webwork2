################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Record/PermissionLevel.pm,v 1.10 2006/10/02 15:04:27 sh002i Exp $
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

package WeBWorK::DB::Record::PermissionLevel;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::PermissionLevel - represent a record from the permission
table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		user_id    => { type=>"TINYBLOB NOT NULL", key=>1 },
		permission => { type=>"INT" },

	);
}

1;
