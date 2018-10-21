################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Record/SetVersion.pm,v 1.2 2007/02/22 01:25:11 sh002i Exp $
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

package WeBWorK::DB::Record::SetVersion;
use base WeBWorK::DB::Record::UserSet;

=head1 NAME

WeBWorK::DB::Record::SetVersion - represent a record from the virtual 
set_version table.

=cut

use strict;
use warnings;

BEGIN {
	our @ISA;
	my $base = $ISA[0];
	my $field_data = $base->FIELD_DATA;
	my @nonkeyfields = map { $_ => $field_data->{$_} } $base->NONKEYFIELDS;
	__PACKAGE__->_fields(
		user_id    => { type=>"TINYBLOB NOT NULL", key=>1 },
		set_id     => { type=>"TINYBLOB NOT NULL", key=>1 },
		version_id => { type=>"INT NOT NULL", key=>1 },
		@nonkeyfields,
	);
}

1;
