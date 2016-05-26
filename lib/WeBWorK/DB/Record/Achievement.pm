################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Record/Set.pm,v 1.22 2007/08/13 22:59:57 sh002i Exp $
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

package WeBWorK::DB::Record::Achievement;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::Achievement - represent a record from the achievement

=cut

use strict;
use warnings;

BEGIN {
	__PACKAGE__->_fields(
		achievement_id            => { type=>"TINYBLOB NOT NULL", key=>1 },
		name                      => { type=>"TEXT" },
		description               => { type=>"TEXT" },
		points                    => { type=>"INT"  },
		test                      => { type=>"TEXT" },
		icon                      => { type=>"TEXT" },
		category                  => { type=>"TEXT" },
  	        enabled                   => { type=>"INT"  },
	        max_counter               => { type=>"INT"  },
	        number                    => { type=>"INT"  },
	        assignment_type           => { type=>"TEXT"  },
	);
}

1;
