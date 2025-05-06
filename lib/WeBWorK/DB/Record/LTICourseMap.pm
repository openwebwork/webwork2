package WeBWorK::DB::Record::LTICourseMap;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::LMSCourseMap - represent a record from the lti_course_map table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		course_id      => { type => "VARCHAR(40) NOT NULL",  key => 1 },
		lms_context_id => { type => "VARCHAR(200) NOT NULL", key => 1 }
	);
}

1;
