package WeBWorK::DB::Record::Depths;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Depths - represent a record from the depths table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		md5   => { type => "CHAR(33) NOT NULL", key => 1 },
		depth => { type => "SMALLINT" },
	);
}

1;
