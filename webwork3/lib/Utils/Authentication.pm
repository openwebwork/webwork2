package Utils::Authentication;
use base qw(Exporter);
use v5.10;

use WeBWorK::CourseEnvironment;
use WeBWork::DB;
use Data::Dump qw/dump/;

our @EXPORT    = ();
our @EXPORT_OK = qw/setCourseEnvironment setCookie/;

our $PERMISSION_ERROR = "You don't have the necessary permissions.";





# not sure what the purpose of this is.  perhaps delete?

sub checkCourse {
	my $course_id = session 'course' || params->{course_id};

	send_error("The course has not been defined.  You may need to authenticate again",401)
			unless defined($course_id);

	setCourseEnvironment($course_id);
}
