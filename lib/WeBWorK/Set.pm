################################################################################
# WeBWorK mod_perl (c) 1995-2002 WeBWorK Team, Univeristy of Rochester
# $Id$
################################################################################

package WeBWorK::Set;

use strict;
use warnings;
use Class::Struct;

struct map { $_ => '$' } our @FIELDS = qw(
	id
	login_id
	set_header
	problem_header
	open_date
	due_date
	answer_date
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
