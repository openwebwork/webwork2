################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Record/Setting.pm,v 1.2 2007/07/22 05:25:17 sh002i Exp $
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

package WeBWorK::DB::Record::Setting;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Setting - represent a record from the setting table.

=cut

use strict;
use warnings;

use WeBWorK::Utils::DBUpgrade;

BEGIN {
	__PACKAGE__->_fields(
		name  => { type=>"VARCHAR(240) NOT NULL", key=>1 },
		value => { type=>"TEXT" },
	);
	__PACKAGE__->_initial_records(
		{ name=>"db_version", value=> 3.1415926   # $WeBWorK::Utils::DBUpgrade::THIS_DB_VERSION 
		},
	);
}

1;

