################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Record::PermissionLevel;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::PermissionLevel - represent a record from the permission
table.

=cut

use strict;
use warnings;

sub KEYFIELDS {qw(
	user_id
)}

sub NONKEYFIELDS {qw(
	permission
)}

sub FIELDS {qw(
	user_id
	permission
)}

1;
