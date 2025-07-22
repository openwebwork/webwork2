package WeBWorK::DB::Record::Problem;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Problem - represent a record from the problem table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		set_id               => { type => "VARCHAR(100) NOT NULL", key => 1 },
		problem_id           => { type => "INT NOT NULL",          key => 1 },
		source_file          => { type => "TEXT" },
		value                => { type => "INT" },
		max_attempts         => { type => "INT" },
		att_to_open_children => { type => "INT" },
		counts_parent_grade  => { type => "INT" },
		showMeAnother        => { type => "INT" },
		showMeAnotherCount   => { type => "INT" },
		showHintsAfter       => { type => "INT NOT NULL DEFAULT -2" },
		# periodic re-randomization period
		prPeriod => { type => "INT" },
		# periodic re-randomization number of attempts for the current seed
		prCount => { type => "INT" },
		# a field for flags relating to this problem
		flags => { type => "TEXT" },
	);
}

1;
