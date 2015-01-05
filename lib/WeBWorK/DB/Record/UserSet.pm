################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Record/UserSet.pm,v 1.21 2007/08/13 22:59:57 sh002i Exp $
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

package WeBWorK::DB::Record::UserSet;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::UserSet - represent a record from the set_user table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		user_id                   => { type=>"TINYBLOB NOT NULL", key=>1 },
		set_id                    => { type=>"TINYBLOB NOT NULL", key=>1 },
		psvn                      => { type=>"INT UNIQUE NOT NULL AUTO_INCREMENT" },
		set_header                => { type=>"TEXT" },
		hardcopy_header           => { type=>"TEXT" },
		open_date                 => { type=>"BIGINT" },
		due_date                  => { type=>"BIGINT" },
		answer_date               => { type=>"BIGINT" },
		reduced_scoring_date       => { type=>"BIGINT" },	    
		visible                   => { type=>"INT" },
		enable_reduced_scoring    => { type=>"INT" },
		assignment_type           => { type=>"TEXT" },
	    description               => { type=>"TEXT" },
		restricted_release	      => { type=>"TEXT" },
		restricted_status	      => { type=>"FLOAT" },
		attempts_per_version      => { type=>"INT" },
		time_interval             => { type=>"INT" },
		versions_per_interval     => { type=>"INT" },
		version_time_limit        => { type=>"INT" },
		version_creation_time     => { type=>"BIGINT" },
		problem_randorder         => { type=>"INT" },
		version_last_attempt_time => { type=>"BIGINT" },
		problems_per_page         => { type=>"INT" },
		hide_score                => { type=>"ENUM('N','Y','BeforeAnswerDate')" },
		hide_score_by_problem     => { type=>"ENUM('N','Y')" },
		hide_work                 => { type=>"ENUM('N','Y','BeforeAnswerDate')" },
		time_limit_cap            => { type=>"ENUM('0','1')" },
		restrict_ip               => { type=>"ENUM('No','RestrictTo','DenyFrom')" },
		relax_restrict_ip         => { type=>"ENUM('No','AfterAnswerDate','AfterVersionAnswerDate')" },
		restricted_login_proctor  => { type=>"ENUM('No','Yes')" },
		hide_hint                 => { type=>"INT" },
	);
}

1;
