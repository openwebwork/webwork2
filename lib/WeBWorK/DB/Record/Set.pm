################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/DB/Record/Set.pm,v 1.7 2004/03/25 00:27:56 sh002i Exp $
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

package WeBWorK::DB::Record::Set;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Set - represent a record from the set table.

=cut

use strict;
use warnings;

sub KEYFIELDS {qw(
	set_id
)}

sub NONKEYFIELDS {qw(
	set_header
	hardcopy_header
	open_date
	due_date
	answer_date
	published
)}

sub FIELDS {qw(
	set_id
	set_header
	hardcopy_header
	open_date
	due_date
	answer_date
	published
)}

1;
