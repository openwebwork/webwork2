################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Record::UserSet;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::UserSet - represent a record from the set_user table.

=cut

use strict;
use warnings;

sub KEYFIELDS($) {qw(
	user_id
	set_id
)}

sub FIELDS($) {qw(
	user_id
	set_id
	psvn
	set_header
	problem_header
	open_date
	due_date
	answer_date
)}

1;
