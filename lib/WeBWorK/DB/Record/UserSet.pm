################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Record/UserSet.pm,v 1.11 2006/07/27 15:49:23 glarose Exp $
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
		user_id                   => { type=>"BLOB", key=>1 },
		set_id                    => { type=>"BLOB", key=>1 },
		# FIXME "NOT NULL PRIMARY KEY AUTO_INCREMENT" isn't part of the type
		# FIXME should be specified symbolically (maybe serial=>1?)
		# FIXME doesn't need to be the primary key -- we never look things up based on psvn
		psvn                      => { type=>"INT NOT NULL PRIMARY KEY AUTO_INCREMENT" },
		set_header                => { type=>"TEXT" },
		hardcopy_header           => { type=>"TEXT" },
		open_date                 => { type=>"BIGINT" },
		due_date                  => { type=>"BIGINT" },
		answer_date               => { type=>"BIGINT" },
		published                 => { type=>"INT" },
		assignment_type           => { type=>"TEXT" },
		attempts_per_version      => { type=>"INT" },
		time_interval             => { type=>"INT" },
		versions_per_interval     => { type=>"INT" },
		version_time_limit        => { type=>"INT" },
		version_creation_time     => { type=>"BIGINT" },
		problem_randorder         => { type=>"INT" },
		version_last_attempt_time => { type=>"BIGINT" },
		problems_per_page         => { type=>"INT" },
	);
}

1;
