################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Record/Problem.pm,v 1.9 2006/10/02 15:04:27 sh002i Exp $
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

package WeBWorK::DB::Record::Problem;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Problem - represent a record from the problem table.

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		set_id       => { type=>"TINYBLOB NOT NULL", key=>1 },
		problem_id   => { type=>"INT NOT NULL", key=>1 },
		source_file  => { type=>"TEXT" },
		value        => { type=>"INT" },
		max_attempts => { type=>"INT" },
		att_to_open_children => { type=>"INT" },
	        counts_parent_grade => { type=>"INT" },
		showMeAnother => { type=>"INT" },
		showMeAnotherCount => { type=>"INT" },
		# periodic re-randomization period
		prPeriod => {type => "INT"},
		# periodic re-randomization version count
		prCount => {type => "INT"},
		# a field for flags relating to this problem  
	        flags => { type =>"TEXT" },
	);
}

1;
