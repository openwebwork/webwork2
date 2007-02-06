################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Schema/NewSQL/Merge.pm,v 1.7 2006/10/19 17:37:25 sh002i Exp $
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

package WeBWorK::DB::Schema::NewSQL::NonVersioned;
use base qw(WeBWorK::DB::Schema::NewSQL::Std);

=head1 NAME

WeBWorK::DB::Schema::NewSQL::NonVersioned - provide access to non-versioned sets.

=cut

use strict;
use warnings;
use WeBWorK::DB::Utils qw/make_vsetID/;

use constant TABLES => qw/set_user problem_user/; # problem_user? i think so...

################################################################################
# where clause
################################################################################

# Override where clause generators that can be used with non-versioned sets so
# that they only match non-versioned sets.

sub where_DEFAULT {
	my ($self, $flags) = @_;
	return {set_id=>{NOT_LIKE=>make_vsetID("%","%")}};
}

sub where_user_id_eq {
	my ($self, $flags, $user_id) = @_;
	return {user_id=>$user_id,set_id=>{NOT_LIKE=>make_vsetID("%","%")}};
}

sub where_user_id_like {
	my ($self, $flags, $user_id) = @_;
	return {user_id=>{LIKE=>$user_id},set_id=>{NOT_LIKE=>make_vsetID("%","%")}};
}

1;
