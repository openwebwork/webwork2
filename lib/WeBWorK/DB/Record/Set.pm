################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Record::Set;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Set - represent a record from the set table.

=cut

use strict;
use warnings;

sub KEYFIELDS($) {qw(
	set_id
)}

sub FIELDS($) {qw(
	set_id
	set_header
	problem_header
	open_date
	due_date
	answer_date
)}

1;
