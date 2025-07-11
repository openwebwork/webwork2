package WeBWorK::DB::Record::LTILaunchData;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::LTILaunchData - represent a record from the lti_launch_data table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		state     => { type => "VARCHAR(200) NOT NULL", key => 1 },
		nonce     => { type => "TEXT NOT NULL" },
		timestamp => { type => "BIGINT" },
		data      => { type => "TEXT NOT NULL DEFAULT ('{}')" }
	);
}

1;
