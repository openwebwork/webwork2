################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::Set;

=head1 NAME

WeBWorK::Set - store information about a problem set.

=cut

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
