package WeBWorK::DB::Record::LocationAddresses;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::LocationAddresses - represent a record from the location_addresses table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		location_id => { type => "VARCHAR(40) NOT NULL", key => 1 },    # requires up to 256 bytes
		ip_mask     => { type => "VARCHAR(180)", key => 1 },    # was VARCHAR(255), reduced to VARCHAR(180) for utf8mb4
	);
}

1;
