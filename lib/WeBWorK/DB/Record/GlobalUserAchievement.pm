package WeBWorK::DB::Record::GlobalUserAchievement;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::GlobalUserAchievement - represent a record from the achievement table

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		user_id              => { type => "VARCHAR(100) NOT NULL", key => 1 },
		achievement_points   => { type => "INT" },
		next_level_points    => { type => "INT" },
		level_achievement_id => { type => "VARCHAR(100)" },
		frozen_hash          => { type => "MEDIUMBLOB" },
	);
}

1;
