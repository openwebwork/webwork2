################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Record::Key;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Key - represent a record from the key table.

=cut

use strict;
use warnings;

sub KEYFIELDS($) {qw(
	user_id
)}

sub FIELDS($) {qw(
	user_id
	key
	timestamp
)}

1;
