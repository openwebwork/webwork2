################################################################################
# WeBWorK mod_perl (c) 1995-2002 WeBWorK Team, Univeristy of Rochester
# $Id$
################################################################################

package WeBWorK::User;

use strict;
use warnings;
use Class::Struct;

struct map { $_ => '$' } our @FIELDS = qw(
	id
	first_name
	last_name
	email_address
	student_id
	status
	section
	recitation
	comment
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
