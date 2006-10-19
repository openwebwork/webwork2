################################################################################
# WeBWorK Online Homework Delivery System - Moodle Integration
# Copyright (c) 2005 Peter Snoblin <pas@truman.edu>
# $Id$
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

package WeBWorK::DB::Schema::NewSQL::Moodle::PasswordPermission;
use base qw(WeBWorK::DB::Schema::NewSQL::Moodle);

=head1 NAME

WeBWorK::DB::Schema::NewSQL::Moodle::PasswordPermission - Enumerates user
passwords and permission levels from Moodle.

=cut

use strict;
use warnings;
use Carp qw(croak);
use Data::Dumper; $Data::Dumper::Terse = 1; $Data::Dumper::Indent = 0;

# only support particular tables (this overrides the version in NewSQL.pm)
use constant TABLES => qw/password permission/;

################################################################################
# counting/existence
################################################################################

# returns the number of matching rows
sub count_where {
	my ($self, $where) = @_;
	
	#warn "BEGIN: WeBWorK::DB::Schema::Moodle::PasswordPermission::count_where\n";
	#warn "PasswordPermission::count_where: where=", Dumper($where), "\n";
	($where, my $flags) = $self->conv_where($where);
	#warn "PasswordPermission::count_where: where=", Dumper($where), "\n";
	#warn "PasswordPermission::count_where: flags=", Dumper($flags), "\n";
	my ($stmt, @bind_vals) = $self->_course_members_query(undef, $flags, $where);
	
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3); # 3 -- see DBI docs
	$self->debug_stmt($sth, @bind_vals);
	$sth->execute(@bind_vals);
	my ($result) = $sth->fetchrow_array;
	$sth->finish;
	
	return $result;
}

*exists_where = *WeBWorK::DB::Schema::NewSQL::Std::exists_where;

################################################################################
# lowlevel get
################################################################################

*get_fields_where = *WeBWorK::DB::Schema::NewSQL::Std::get_fields_where;
*get_fields_where_i = *WeBWorK::DB::Schema::NewSQL::Std::get_fields_where_i;

# helper, returns a prepared statement handle
sub _get_fields_where_prepex {
	my ($self, $fields, $where, $order) = @_;
	
	#warn "BEGIN: WeBWorK::DB::Schema::Moodle::PasswordPermission::_get_fields_where_prepex\n";
	#warn "PasswordPermission::_get_fields_where_prepex: where=", Dumper($where), "\n";
	($where, my $flags) = $self->conv_where($where);
	#warn "PasswordPermission::_get_fields_where_prepex: where=", Dumper($where), "\n";
	#warn "PasswordPermission::_get_fields_where_prepex: flags=", Dumper($flags), "\n";
	my ($stmt, @bind_vals) = $self->_course_members_query($fields, $flags, $where, $order);
	
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3); # 3: see DBI docs
	$self->debug_stmt($sth, @bind_vals);
	$sth->execute(@bind_vals);	
	return $sth;
}

################################################################################
# getting keyfields (a.k.a. listing)
################################################################################

*list_where = *WeBWorK::DB::Schema::NewSQL::Std::list_where;
*list_where_i = *WeBWorK::DB::Schema::NewSQL::Std::list_where_i;

################################################################################
# getting records
################################################################################

*get_records_where = *WeBWorK::DB::Schema::NewSQL::Std::get_records_where;
*get_records_where_i = *WeBWorK::DB::Schema::NewSQL::Std::get_records_where_i;

################################################################################
# compatibility methods for old API
################################################################################

*get = *WeBWorK::DB::Schema::NewSQL::Std::get;
*gets = *WeBWorK::DB::Schema::NewSQL::Std::gets;

1;
