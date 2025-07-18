package WeBWorK::DB::Record::UserAchievement;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::UserAchievement - represent a record from the achievement table

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		user_id        => { type => "VARCHAR(100) NOT NULL", key => 1 },
		achievement_id => { type => "VARCHAR(100) NOT NULL", key => 1 },
		earned         => { type => "INT" },
		counter        => { type => "INT" },
		frozen_hash    => { type => "MEDIUMBLOB" },
	);
}

1;
