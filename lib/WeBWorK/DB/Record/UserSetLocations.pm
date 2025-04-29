package WeBWorK::DB::Record::UserSetLocations;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::UserSetLocations - represent a record from the set_locations_user table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		user_id     => { type => "VARCHAR(100) NOT NULL", key => 1 },
		set_id      => { type => "VARCHAR(100) NOT NULL", key => 1 },
		location_id => { type => "VARCHAR(40) NOT NULL",  key => 1 },
	);
}

1;
