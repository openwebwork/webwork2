################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::Problem;

=head1 NAME

WeBWorK::Problem - store information about a problem.

=cut

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

sub toString($) {
	my $self = shift;
	my $result;
	foreach (@FIELDS) {
		$result .= "$_ => ";
		$result .= defined $self->$_() ? $self->$_() : "";
		$result .= "\n";
	}
	return $result;
}

1;
