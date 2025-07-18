package WeBWorK::DB::Record::Achievement;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Achievement - represent a record from the achievement

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		achievement_id  => { type => "VARCHAR(100) NOT NULL", key => 1 },
		name            => { type => "TEXT" },
		description     => { type => "TEXT" },
		points          => { type => "INT" },
		test            => { type => "TEXT" },
		icon            => { type => "TEXT" },
		category        => { type => "TEXT" },
		enabled         => { type => "INT" },
		max_counter     => { type => "INT" },
		number          => { type => "INT" },
		assignment_type => { type => "TEXT" },
		email_template  => { type => "TEXT" },
	);
}

1;
