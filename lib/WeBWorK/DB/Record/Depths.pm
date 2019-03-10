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

package WeBWorK::DB::Record::Depths;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Depths - represent a record from the depths table.

=cut

use strict;
use warnings;

#use WeBWorK::Utils::DBUpgrade;

BEGIN {
	__PACKAGE__->_fields(
		md5   => { type=>"CHAR(33) NOT NULL", key=>1 },
		depth => { type=>"SMALLINT" },
	);

}

1;

