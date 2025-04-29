package WeBWorK::Utils::CourseManagement::sql_moodle;

=head1 NAME

WeBWorK::Utils::CourseManagement::sql_moodle - create and delete courses using
the sql_moodle database layout. Delegates functionality to
WeBWorK::Utils::CourseManagement::sql_single.

=cut

use strict;
use warnings;
use WeBWorK::Utils::CourseManagement::sql_single;

*archiveCourseHelper   = \&WeBWorK::Utils::CourseManagement::sql_single::archiveCourseHelper;
*unarchiveCourseHelper = \&WeBWorK::Utils::CourseManagement::sql_single::unarchiveCourseHelper;

1;
