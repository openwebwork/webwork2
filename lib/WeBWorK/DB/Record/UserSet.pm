################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/DB/Record/UserSet.pm,v 1.7 2004/07/07 14:37:32 gage Exp $
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

package WeBWorK::DB::Record::UserSet;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::UserSet - represent a record from the set_user table.

=cut

use strict;
use warnings;

sub KEYFIELDS {qw(
	user_id
	set_id
)}

sub NONKEYFIELDS {qw(
	psvn
	set_header
	hardcopy_header
	open_date
	due_date
	answer_date
	published
)}

sub FIELDS {qw(
	user_id
	set_id
	psvn
	set_header
	hardcopy_header
	open_date
	due_date
	answer_date
	published
)}

sub SQL_TYPES {(
	"BLOB",
	"BLOB",
	"INT NOT NULL PRIMARY KEY AUTO_INCREMENT",
	"TEXT",
	"TEXT",
	"BIGINT",
	"BIGINT",
	"BIGINT",
	"INT"
)}

1;
