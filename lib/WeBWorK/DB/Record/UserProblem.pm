################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Record/UserProblem.pm,v 1.11 2007/08/13 22:59:57 sh002i Exp $
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
		user_id       => { type=>"TINYBLOB NOT NULL", key=>1 },
		set_id        => { type=>"TINYBLOB NOT NULL", key=>1 },
		problem_id    => { type=>"INT NOT NULL", key=>1 },
		source_file   => { type=>"TEXT" },
		# FIXME i think value should be able to hold decimal values...
		value         => { type=>"INT" },
		max_attempts  => { type=>"INT" },
		showMeAnother  => { type=>"INT" },
		showMeAnotherCount  => { type=>"INT" },
		# periodic re-randomization period
		prPeriod => {type => "INT"},
		# periodic re-randomization number of attempts for the current seed
		prCount => {type => "INT"},
		problem_seed  => { type=>"INT" },
		status        => { type=>"FLOAT" },
		attempted     => { type=>"INT" },
		last_answer   => { type=>"TEXT" },
		num_correct   => { type=>"INT" },
		num_incorrect => { type=>"INT" },
		att_to_open_children => { type=>"INT" },
		counts_parent_grade => { type=>"INT" },
		sub_status    => { type=>"FLOAT" },    # A subsidiary status used to implement the reduced scoring period
		# a field for flags which need to be set
		flags => { type=>"TEXT" },
	);
}

1;
