################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Record::UserProblem;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::UserProblem - represent a record from the problem_user
table.

=cut

use strict;
use warnings;

sub FIELDS($) {qw(
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

1;
