package WeBWorK::DB::Record::PermissionLevel;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::PermissionLevel - represent a record from the permission
table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		user_id    => { type => "VARCHAR(100) NOT NULL", key => 1 },
		permission => { type => "INT" },
	);
}

1;
