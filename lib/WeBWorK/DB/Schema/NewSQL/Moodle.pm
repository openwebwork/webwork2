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

package WeBWorK::DB::Schema::NewSQL::Moodle;
use base qw(WeBWorK::DB::Schema::NewSQL);

=head1 NAME

WeBWorK::DB::Schema::NewSQL::Moodle - Base class for Moodle schema modules.

=cut

use strict;
use warnings;
use Carp qw(croak);

use constant MOODLE_WEBWORK_BRIDGE_TABLE => 'wwassignment_bridge';

=head1 SUPPORTED PARAMS

This schema pays attention to the following items in the C<params> entry.

=over

=item tablePrefix

The prefix on all moodle tables.

=item courseName

The name of the current WeBWorK course.

=item studentsPermissionLevel

Permission level to assign to students.

=item teachersPermissionLevel

Permission level to assign to teachers.

=item adminsPermissionLevel

Permission level to assign to administrators.

=back

=cut

################################################################################
# constructor for Moodle-specific behavior
################################################################################

sub new {
	my $proto = shift;
	my $self = $proto->SUPER::new(@_);
	
	# prepend tablePrefix to all table names
	my $transform_table;
	if (defined $self->{params}{tablePrefix}) {
		$transform_table = sub {
			my $label = shift;
			return $self->{params}{tablePrefix} . $label;
		};
	}
	
	# add SQL statement generation object
	$self->{sql} = new WeBWorK::DB::Utils::SQLAbstractIdentTrans(
		quote_char => "`",
		name_sep => ".",
		transform_table => $transform_table,
	);
	
	return $self;
}

################################################################################
# list of users in this course
################################################################################

sub _course_members_query {
	my ($self, $fields, $where, $order) = @_;
	
	local our %flags;
	$where = $self->conv_where($where);
	
	my $fields_int = ref $fields ? $fields : ["user_id"];
	my $fields_ext = ref $fields ? "*" : "COUNT(*)";
	
	my @stmt_parts;
	my @bind_vals;
	foreach my $type (["students",1],["teachers",1],["admins",0]) {
		my ($curr_stmt, @curr_bind_vals) = $self->_course_members_type(@$type, \%flags, $fields_int);
		next unless defined $curr_stmt;
		push @stmt_parts, $curr_stmt;
		push @bind_vals, @curr_bind_vals;
	}
	return unless @stmt_parts;
	my $stmt = join(" UNION ", @stmt_parts);
	
	my ($base_where_clause, @base_bind_vals) = $self->sql->where($where, $order);
	if ($base_where_clause =~ /\S/ or not ref $fields) {
		$stmt = "SELECT $fields_ext FROM ($stmt) AS InnerSelect $base_where_clause";
		push @bind_vals, @base_bind_vals;
	}
	
	return $stmt, @bind_vals;
}

sub _course_members_type {
	my ($self, $type, $need_course, $flags, $fields) = @_;
	
	my $permission_level = $self->{params}{$type."PermissionLevel"};
	return if defined $flags->{match_permission} and $flags->{match_permission} != $permission_level;
	return if defined $flags->{match_permission_min} and $flags->{match_permission_min} > $permission_level;
	return if defined $flags->{match_permission_max} and $flags->{match_permission_max} < $permission_level;
	
	my $need_user = defined $flags->{match_username} || defined $flags->{match_password};
	my $type_table = $self->sql->_table("user_$type");
	
	my @fields_out;
	foreach my $field (@$fields) {
		if ($field eq "id") {
			push @fields_out, $self->sql->_quote("userid");
		} elsif ($field eq "user_id") {
			$need_user = 1;
			push @fields_out, $self->sql->_quote("user.username")
				. " AS " . $self->sql->_quote("user_id");
		} elsif ($field eq "password") {
			$need_user = 1;
			push @fields_out, $self->sql->_quote("user.password")
				. " AS " . $self->sql->_quote("password");
		} elsif ($field eq "permission") {
			push @fields_out, $self->dbh->quote($permission_level)
				. " AS " . $self->sql->_quote("permission");
		} else {
			croak "Unrecognized field '$field' in field list";
		}
	}
	my $fields_out = join(",", @fields_out);
	
	my @joins;
	my @where;
	my @bind_vals;
	
	if ($need_course) {
		my $bridge_table = $self->sql->_table($self->MOODLE_WEBWORK_BRIDGE_TABLE);
		my $course_field = $self->sql->_quote("course");
		my $coursename_field = $self->sql->_quote("coursename");
		push @joins, "JOIN $bridge_table ON $bridge_table.$course_field=$type_table.$course_field";
		push @where, "$bridge_table.$coursename_field=?";
		push @bind_vals, $self->courseName;
	}
	
	if ($need_user) {
		my $user_table = $self->sql->_table("user");
		my $id_field = $self->sql->_quote("id");
		my $userid_field = $self->sql->_quote("userid");
		push @joins, "JOIN $user_table ON $user_table.$id_field=$type_table.$userid_field";
		if ($flags->{match_username}) {
			my $username_field = $self->sql->_quote("username");
			push @where, "$user_table.$username_field=?";
			push @bind_vals, $flags->{match_username};
		}
		if ($flags->{match_password}) {
			my $password_field = $self->sql->_quote("password");
			push @where, "$user_table.$password_field=?";
			push @bind_vals, $flags->{match_password};
		}
	}
	
	my $stmt = "SELECT $fields_out FROM $type_table";
	$stmt .= " " . join(" ", @joins) if @joins;
	$stmt .= " WHERE " . join(" AND ", @where) if @where;
	
	return $stmt, @bind_vals;
}

################################################################################
# list of users in this course
################################################################################

sub _course_groups_query {
	my ($self) = @_;
	
	my $stmt = "SELECT " . $self->sql->_quote("groups.id")
		. " FROM " . $self->sql->_table("groups")
		. " JOIN " . $self->sql->_table($self->MOODLE_WEBWORK_BRIDGE_TABLE)
		. " ON " . $self->sql->_quote($self->MOODLE_WEBWORK_BRIDGE_TABLE.".course")
		. "=" . $self->sql->_quote("groups.courseid")
		. " WHERE " . $self->sql->_quote($self->MOODLE_WEBWORK_BRIDGE_TABLE.".coursename")
		. "=?";
	return $stmt, $self->courseName;
}

################################################################################
# utility methods
################################################################################

sub courseName {
	return shift->{params}{courseName};
}

# all the tables that moodle can handle have a single keypart (user_id) so this
# is somewhat easier that it might otherwise be :)
sub keyparts_to_where {
	my ($self, $userID) = @_;
	return defined $userID ? {username=>$userID} : {};
}

sub gen_update_hashes {
	croak "this would have a moodle-specific implementation if modification was supported";
}

*sql = *WeBWorK::DB::Schema::NewSQL::Std::sql;

1;
