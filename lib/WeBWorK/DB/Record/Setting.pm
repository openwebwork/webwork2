package WeBWorK::DB::Record::Setting;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Setting - represent a record from the setting table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		name  => { type => "VARCHAR(240) NOT NULL", key => 1 },
		value => { type => "TEXT" },
	);
	__PACKAGE__->_initial_records(
		{
			name  => "db_version",
			value => 3.1415926
		},
	);
}

1;
