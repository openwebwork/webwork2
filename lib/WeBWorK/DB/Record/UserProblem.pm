################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/DB/Record/UserProblem.pm,v 1.4 2003/12/09 01:12:32 sh002i Exp $
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

package WeBWorK::DB::Record::UserProblem;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::UserProblem - represent a record from the problem_user
table.

=cut

use strict;
use warnings;

sub KEYFIELDS {qw(
	user_id
	set_id
	problem_id
)}

sub NONKEYFIELDS {qw(
	source_file
	value
	max_attempts
	problem_seed
	status
	attempted
	last_answer
	num_correct
	num_incorrect
)}

sub FIELDS {qw(
	user_id
	set_id
	problem_id
	source_file
	value
	max_attempts
	problem_seed
	status
	attempted
	last_answer
	num_correct
	num_incorrect
)}

# Should value be float instead of text?

sub SQL_TYPES {qw(
	BLOB
	BLOB
	INT
	TEXT
	INT
	INT
	INT
	TEXT
	INT
	TEXT
	INT
	INT
)}


1;
