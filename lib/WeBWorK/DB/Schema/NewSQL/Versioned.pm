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

package WeBWorK::DB::Schema::NewSQL::Versioned;
use base qw(WeBWorK::DB::Schema::NewSQL::Std);

=head1 NAME

WeBWorK::DB::Schema::NewSQL::Versioned - provide access to versioned sets.

=cut

use strict;
use warnings;
use WeBWorK::DB::Utils qw/make_vsetID/;

use constant TABLES => qw/vset_user vproblem_user/; # vproblem_user? i think...

################################################################################
# where clause
################################################################################

# Override where clause generators that can be used with versioned sets so that
# they only match versioned sets.

sub where_DEFAULT {
	my ($self, $flags) = @_;
	return {set_id=>{LIKE=>make_vsetID("%","%")}};
}

# replaces where_versionedset_user_id_eq in NewSQL
sub where_user_id_eq {
	my ($self, $flags, $user_id) = @_;
	return {user_id=>$user_id,set_id=>{LIKE=>make_vsetID("%","%")}};
}

sub where_user_id_like {
	my ($self, $flags, $user_id) = @_;
	return {user_id=>{LIKE=>$user_id},set_id=>{LIKE=>make_vsetID("%","%")}};
}

sub where_set_id_eq {
	my ($self, $flags, $set_id) = @_;
	return {set_id=>{LIKE=>make_vsetID($set_id,"%")}};
}

# replaces where_versionedset_user_id_eq_set_id_eq in NewSQL
sub where_user_id_eq_set_id_eq {
	my ($self, $flags, $user_id, $set_id) = @_;
	return {user_id=>$user_id,set_id=>{LIKE=>make_vsetID($set_id,"%")}};
}

# replaces where_versionedset_user_id_eq_set_id_eq_version_id_le in NewSQL
sub where_user_id_eq_set_id_eq_version_id_le {
	my ($self, $flags, $user_id, $set_id, $version_id) = @_;
	if ($version_id >= 1) {
		my @vsetIDs = map { make_vsetID($set_id,$_) } 1 .. $version_id;
		return {user_id=>$user_id,set_id=>\@vsetIDs};
	} else {
		# nothing matches an invalid version id
		return {-and=>\("0==1")};
	}
}

1;
