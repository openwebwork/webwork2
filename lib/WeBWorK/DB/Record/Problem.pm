################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
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
