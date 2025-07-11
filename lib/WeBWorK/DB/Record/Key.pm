package WeBWorK::DB::Record::Key;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Key - represent a record from the key table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		user_id   => { type => "VARCHAR(100) NOT NULL", key => 1 },
		key       => { type => "TEXT" },
		timestamp => { type => "BIGINT" },
		session   => { type => "TEXT NOT NULL DEFAULT ('{}')" },
	);
}

1;
