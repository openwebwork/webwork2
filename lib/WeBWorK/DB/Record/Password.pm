package WeBWorK::DB::Record::Password;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Password - represent a record from the password table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		user_id    => { type => "VARCHAR(100) NOT NULL", key => 1 },
		password   => { type => "TEXT" },
		otp_secret => { type => "TEXT" }
	);
}

1;
