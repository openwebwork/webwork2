################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/DB/Record/ProblemLibraryClassify.pm,v 1.1 2004/05/06 03:01:22 jj Exp $
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

package WeBWorK::DB::Record::ProblemLibraryClassify;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::ProblemLibraryClassify - represent a record from the
   problem library classification table.

=cut

use strict;
use warnings;

sub KEYFIELDS {qw(
	classify_id
	chapter
	section
)}

sub NONKEYFIELDS {qw(
	author
	institution
	filename
	pgfiles_id
)}

sub FIELDS {qw(
	classify_id
	chapter
	section
	author
	institution
	filename
	pgfiles_id
)}

1;
