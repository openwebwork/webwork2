################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader$
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

package WeBWorK::DB::Record::Problem;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Problem - represent a record from the problem table.

=cut

use strict;
use warnings;

sub KEYFIELDS {qw(
	set_id
	problem_id
)}

sub NONKEYFIELDS {qw(
	source_file
	value
	max_attempts
)}

sub FIELDS {qw(
	set_id
	problem_id
	source_file
	value
	max_attempts
)}

1;
