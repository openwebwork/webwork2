package WeBWorK::DB::Record::SetLocations;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::SetLocations - represent a record from the set_locations table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		set_id      => { type => "VARCHAR(100) NOT NULL", key => 1 },
		location_id => { type => "VARCHAR(40) NOT NULL",  key => 1 },
	);
}

1;
