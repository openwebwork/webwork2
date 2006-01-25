################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Record/Password.pm,v 1.6 2005/06/05 20:25:27 jj Exp $
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

package WeBWorK::DB::Record::Password;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Password - represent a record from the password table.

=cut

use strict;
use warnings;

sub KEYFIELDS {qw(
	user_id
)}

sub NONKEYFIELDS {qw(
	password
)}

sub FIELDS {qw(
	user_id
	password
)}

sub SQL_TYPES {qw(
	BLOB
	TEXT
)}

1;
