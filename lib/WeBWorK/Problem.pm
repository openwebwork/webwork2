################################################################################
# WeBWorK mod_perl (c) 1995-2002 WeBWorK Team, Univeristy of Rochester
# $Id$
################################################################################

package WeBWorK::Problem;

use strict;
use warnings;
use Class::Struct;

struct map { $_ => '$' } our @FIELDS = qw(
	id
	set_id
	login_id
	source_file
	value
	max_attempts
	problem_seed
	status
	attempted
	last_answer
	num_correct
	num_incorrect
);

1;
