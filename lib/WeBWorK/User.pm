################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::User;

=head1 NAME

WeBWorK::User - store information about a user.

=cut

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
