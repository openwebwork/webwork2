################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Record::User;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::User - represent a record from the user table.

=cut

use strict;
use warnings;

sub KEYFIELDS($) {qw(
	id
)}

sub FIELDS($) {qw(
	id
	first_name
	last_name
	email_address
	student_id
	status
	section
	recitation
	comment
)}

1;
