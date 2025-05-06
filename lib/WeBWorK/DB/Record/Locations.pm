package WeBWorK::DB::Record::Locations;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Locations - represent a record from the locations table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		location_id => { type => "VARCHAR(40) NOT NULL", key => 1 },
		description => { type => "TEXT" },
	);
}

1;
