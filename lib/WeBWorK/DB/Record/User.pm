################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/DB/Record/User.pm,v 1.5 2003/12/09 01:12:32 sh002i Exp $
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

package WeBWorK::DB::Record::User;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::User - represent a record from the user table.

=cut

use strict;
use warnings;

sub KEYFIELDS {qw(
	user_id
)}

sub NONKEYFIELDS {qw(
	first_name
	last_name
	email_address
	student_id
	status
	section
	recitation
	comment
)}

sub FIELDS {qw(
	user_id
	first_name
	last_name
	email_address
	student_id
	status
	section
	recitation
	comment
)}

sub SQL_TYPES {qw(
	BLOB
	TEXT
	TEXT
	TEXT
	TEXT
	TEXT
	TEXT
	TEXT
	TEXT
)}

1;
