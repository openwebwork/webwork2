package WeBWorK::DB::Record::PastAnswer;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::PastAnswers - Represents a past answer

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		answer_id      => { type => "INT AUTO_INCREMENT",    key => 1 },
		user_id        => { type => "VARCHAR(100) NOT NULL", key => 1 },
		set_id         => { type => "VARCHAR(100) NOT NULL", key => 1 },
		problem_id     => { type => "INT NOT NULL",          key => 1 },
		source_file    => { type => "TEXT" },
		timestamp      => { type => "BIGINT" },
		scores         => { type => "TINYTEXT" },
		answer_string  => { type => "VARCHAR(5012)" },
		comment_string => { type => "VARCHAR(5012)" },
		problem_seed   => { type => "INT" },
	);
}

1;
