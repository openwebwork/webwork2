################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: $
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

package WeBWorK::DB::Record::ProblemLibraryPgfiles;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::ProblemLibraryPgfiles - represent a record from the
   problem library pgfiles table.

=cut

use strict;
use warnings;

sub KEYFIELDS {qw(
	pgfiles_id
	path
)}

sub NONKEYFIELDS {qw(
	servername
)}

sub FIELDS {qw(
	pgfiles_id
	path
	servername
)}

1;
