################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/CourseManagement/sql_moodle.pm,v 1.2 2006/09/29 19:41:36 sh002i Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::Utils::CourseManagement::sql_moodle;

=head1 NAME

WeBWorK::Utils::CourseManagement::sql_moodle - create and delete courses using
the sql_moodle database layout. Delegates functionality to
WeBWorK::Utils::CourseManagement::sql_single.

=cut

use strict;
use warnings;
use WeBWorK::Utils::CourseManagement::sql_single;

*archiveCourseHelper = \&WeBWorK::Utils::CourseManagement::sql_single::archiveCourseHelper;
*unarchiveCourseHelper = \&WeBWorK::Utils::CourseManagement::sql_single::unarchiveCourseHelper;

1;
