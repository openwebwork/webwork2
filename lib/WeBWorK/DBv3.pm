################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB.pm,v 1.58 2004/10/22 23:06:44 sh002i Exp $
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

package WeBWorK::DBv3;
use base 'Class::DBI::mysql';

use strict;
use warnings;
use WeBWorK::DBv3::Utils;

use constant DSN => "dbi:mysql:wwdbv3";
use constant USER => "wwdbv3";
use constant PASS => "xyzzy";
use constant ATTR => {
	RaiseError => 1,
};
use constant UPGRADE_LOCK => "/tmp/wwdbv3_upgrade.lock";

upgrade_schema(DSN, USER, PASS, ATTR, UPGRADE_LOCK);

__PACKAGE__->connection(DSN, USER, PASS, ATTR);

################################################################################

package WeBWorK::DBv3::Course;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("course");
__PACKAGE__->has_many(statuses => "WeBWorK::DBv3::Status");
__PACKAGE__->has_many(roles => "WeBWorK::DBv3::Role");
__PACKAGE__->has_many(sections => "WeBWorK::DBv3::Section");
__PACKAGE__->has_many(recitations => "WeBWorK::DBv3::Recitation");
__PACKAGE__->has_many(participants  => "WeBWorK::DBv3::Participant");
__PACKAGE__->has_many(abstract_sets => "WeBWorK::DBv3::AbstractSet");

################################################################################

package WeBWorK::DBv3::User;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("user");
__PACKAGE__->has_many(participants => "WeBWorK::DBv3::Participant");

################################################################################

package WeBWorK::DBv3::Status;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("status");
__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");
__PACKAGE__->has_many(participants => "WeBWorK::DBv3::Participant");

################################################################################

package WeBWorK::DBv3::Role;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("role");
__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");
__PACKAGE__->has_many(participants => "WeBWorK::DBv3::Participant");

################################################################################

package WeBWorK::DBv3::Section;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("section");
__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");
__PACKAGE__->has_many(participants => "WeBWorK::DBv3::Participant");
__PACKAGE__->has_many(set_overrides => "WeBWorK::DBv3::SetOverride");
__PACKAGE__->has_many(problem_overrides => "WeBWorK::DBv3::ProblemOverride");

################################################################################

package WeBWorK::DBv3::Recitation;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("recitation");
__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");
__PACKAGE__->has_many(participants => "WeBWorK::DBv3::Participant");
__PACKAGE__->has_many(set_overrides => "WeBWorK::DBv3::SetOverride");
__PACKAGE__->has_many(problem_overrides => "WeBWorK::DBv3::ProblemOverride");

################################################################################

package WeBWorK::DBv3::Participant;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("participant");
__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");
__PACKAGE__->has_a(user => "WeBWorK::DBv3::User");
__PACKAGE__->has_a(status => "WeBWorK::DBv3::Status");
__PACKAGE__->has_a(role => "WeBWorK::DBv3::Role");
__PACKAGE__->has_a(section => "WeBWorK::DBv3::Section");
__PACKAGE__->has_a(recitation => "WeBWorK::DBv3::Recitation");
__PACKAGE__->has_many(set_assignments => "WeBWorK::DBv3::SetAssignment");
__PACKAGE__->has_many(set_overrides => "WeBWorK::DBv3::SetOverride");
__PACKAGE__->has_many(problem_overrides => "WeBWorK::DBv3::ProblemOverride");

################################################################################

package WeBWorK::DBv3::AbstractSet;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("abstract_set");
__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");
__PACKAGE__->has_many(abstract_problems => "WeBWorK::DBv3::AbstractProblem");
__PACKAGE__->has_many(set_assignments => "WeBWorK::DBv3::SetAssignment");

################################################################################

package WeBWorK::DBv3::AbstractProblem;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("abstract_problem");
__PACKAGE__->has_a(abstract_set => "WeBWorK::DBv3::AbstractSet");
__PACKAGE__->has_many(problem_assignments => "WeBWorK::DBv3::ProblemAssignment");

################################################################################

package WeBWorK::DBv3::SetAssignment;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("set_assignment");
__PACKAGE__->has_a(abstract_set => "WeBWorK::DBv3::AbstractSet");
__PACKAGE__->has_a(participant => "WeBWorK::DBv3::Participant");
__PACKAGE__->has_many(problem_assignments => "WeBWorK::DBv3::ProblemAssignment");
__PACKAGE__->has_many(set_overrides => "WeBWorK::DBv3::SetOverride");
__PACKAGE__->has_many(set_versions => "WeBWorK::DBv3::SetVersion");

################################################################################

package WeBWorK::DBv3::ProblemAssignment;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("problem_assignment");
__PACKAGE__->has_a(set_assignment => "WeBWorK::DBv3::SetAssignment");
__PACKAGE__->has_a(abstract_problem => "WeBWorK::DBv3::AbstractProblem");
__PACKAGE__->has_many(problem_overrides => "WeBWorK::DBv3::ProblemOverride");
__PACKAGE__->has_many(problem_versions => "WeBWorK::DBv3::ProblemVersion");

################################################################################

package WeBWorK::DBv3::SetOverride;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("set_override");
__PACKAGE__->has_a(abstract_set => "WeBWorK::DBv3::AbstractSet");
__PACKAGE__->has_a(section => "WeBWorK::DBv3::Section");
__PACKAGE__->has_a(recitation => "WeBWorK::DBv3::Recitation");
__PACKAGE__->has_a(participant => "WeBWorK::DBv3::Participant");

################################################################################

package WeBWorK::DBv3::ProblemOverride;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("problem_override");
__PACKAGE__->has_a(abstract_problem => "WeBWorK::DBv3::AbstractProblem");
__PACKAGE__->has_a(section => "WeBWorK::DBv3::Section");
__PACKAGE__->has_a(recitation => "WeBWorK::DBv3::Recitation");
__PACKAGE__->has_a(participant => "WeBWorK::DBv3::Participant");

################################################################################

package WeBWorK::DBv3::SetVersion;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("set_version");
__PACKAGE__->has_a(set_assignment => "WeBWorK::DBv3::SetAssignment");
__PACKAGE__->has_many(problem_versions => "WeBWorK::DBv3::ProblemVersion");

################################################################################

package WeBWorK::DBv3::ProblemVersion;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("problem_version");
__PACKAGE__->has_a(set_version => "WeBWorK::DBv3::SetVersion");
__PACKAGE__->has_a(problem_assignment => "WeBWorK::DBv3::ProblemAssignment");
__PACKAGE__->has_many(problem_attempts => "WeBWorK::DBv3::ProblemAttempt");

################################################################################

package WeBWorK::DBv3::ProblemAttempt;
use base 'WeBWorK::DBv3';

__PACKAGE__->set_up_table("problem_attempt");
__PACKAGE__->has_a(problem_version => "WeBWorK::DBv3::ProblemVersion");

################################################################################

1;
