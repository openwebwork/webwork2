package WeBWorK::DB::Record::UserProblem;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::UserProblem - represent a record from the problem_user
table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		user_id     => { type => "VARCHAR(100) NOT NULL", key => 1 },
		set_id      => { type => "VARCHAR(100) NOT NULL", key => 1 },
		problem_id  => { type => "INT NOT NULL",          key => 1 },
		source_file => { type => "TEXT" },
		# FIXME i think value should be able to hold decimal values...
		value              => { type => "INT" },
		max_attempts       => { type => "INT" },
		showMeAnother      => { type => "INT" },
		showMeAnotherCount => { type => "INT" },
		showHintsAfter     => { type => "INT" },
		# periodic re-randomization period
		prPeriod => { type => "INT" },
		# periodic re-randomization number of attempts for the current seed
		prCount              => { type => "INT" },
		problem_seed         => { type => "INT" },
		status               => { type => "FLOAT" },
		attempted            => { type => "INT" },
		last_answer          => { type => "TEXT" },
		num_correct          => { type => "INT" },
		num_incorrect        => { type => "INT" },
		att_to_open_children => { type => "INT" },
		counts_parent_grade  => { type => "INT" },
		# A subsidiary status used to implement the reduced scoring period
		sub_status => { type => "FLOAT" },
		# a field for flags which need to be set
		flags => { type => "TEXT" },
		# additional stored data for this problem, internally uses JSON:
		problem_data => { type => "MEDIUMTEXT" },
	);
}

1;
