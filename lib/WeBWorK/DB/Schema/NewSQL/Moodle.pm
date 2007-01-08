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
#use Data::Dumper; $Data::Dumper::Terse = 1; $Data::Dumper::Indent = 0;

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
# where clauses
################################################################################

sub where_user_id_eq {
	my ($self, $flags, $user_id) = @_;
	$flags->{match_username} = $user_id;
	return {};
}

sub where_user_id_like {
	my ($self, $flags, $user_id) = @_;
	$flags->{match_username_like} = $user_id;
	return {};
}

sub where_password_eq {
	my ($self, $flags, $password) = @_;
	$flags->{match_password} = $password;
	return {};
}

sub where_permission_eq {
	my ($self, $flags, $permission) = @_;
	$flags->{match_permission} = $permission;
	return {};
}

sub where_permission_in_range {
	my ($self, $flags, $min, $max) = @_;
	$flags->{match_permission_min} = $min;
	$flags->{match_permission_max} = $max;
	return {};
}

################################################################################
# list of users in this course
################################################################################

use constant USER_TABLE => 'user';
use constant ROLE_ASSIGNMENT_TABLE => 'role_assignments';
use constant ROLE_TABLE => 'role';

# FIXME instead of hardcoding roleids, get it from a hash in the schema params
sub _role_to_permission {
	my ($self) = @_;
	
	my $guest = $self->{params}{"guestPermissionLevel"};
	my $student = $self->{params}{"studentPermissionLevel"};
	my $teacher = $self->{params}{"teacherPermissionLevel"};
	my $admin = $self->{params}{"adminPermissionLevel"};
	
	return "CASE " . $self->sql->_quote(ROLE_ASSIGNMENT_TABLE.".roleid")
		. " WHEN 1 THEN $admin"   # administrator
		. " WHEN 2 THEN $admin"   # course creator
		. " WHEN 3 THEN $admin"   # editing teacher
		. " WHEN 4 THEN $teacher" # teacher
		. " WHEN 5 THEN $student" # student
		. " WHEN 6 THEN $guest"   # guest
		. " ELSE -1 END"; # FIXME default should be defined in schema params instead
}

# Moodle 1.7 note: This method is slightly abused to generate SQL to enumerate all users in the course,
# regardless of type (i.e. permission level). This is possible because Moodle 1.7 maintains a single list
# of course participants in the many-to-many role_assignments table, which maps a user to a (course,role)
# pair.

# This change to the Moodle database format simplifies all three tables significantly:
#   * Getting permission level records is basically SELECTing all the role_assignments records that have
#     the corrent instanceid (i.e. courseid), and substituting permission levels for roleids.
#   * Getting user or password records is basically the SELECT above joined with the user table to get the
#     rest of the fields. (The hoary section/recitation voodoo is probably still necessary though.)

# FIXME We might want to separate the 1.7 functionality into a separate method that would replace the
# call to _course_members_query().

sub _course_members_type {
	my ($self, $type, $need_course, $flags, $fields) = @_;
	
	if ($self->{params}{moodle17}) {
		# FIXME for moodle 1.7, we want to convert permission levels back into roleids and then add an
		# expression to the where clause that checks the value of role_assignments.roleid.
		# (role_assignments is the main table for this query under 1.7, so roleid is always accessible)
	} else {
		my $permission_level = $self->{params}{$type."PermissionLevel"};
		return if defined $flags->{match_permission} and $flags->{match_permission} != $permission_level;
		return if defined $flags->{match_permission_min} and $flags->{match_permission_min} > $permission_level;
		return if defined $flags->{match_permission_max} and $flags->{match_permission_max} < $permission_level;
	}
	
	my $need_user = defined $flags->{match_username} || defined $flags->{match_username_like}
		|| defined $flags->{match_password};
	
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
			if ($self->{params}{moodle17}) {
				push @fields_out, $self->_role_to_permission
					. " AS " . $self->sql->_quote("permission");
			} else {
				push @fields_out, $self->dbh->quote($self->{params}{$type."PermissionLevel"})
					. " AS " . $self->sql->_quote("permission");
			}
		} else {
			croak "Unrecognized field '$field' in field list";
		}
	}
	my $fields_out = join(",", @fields_out);
	
	my @joins;
	my @where;
	my @bind_vals;
	
	# use role assignment to find contextid(course) userid and roleid
	# use context table to connect contextid to courseid=instanceid
	# use bridge table to connect courseid to webwork coursename 
	# what we use:
	# user.username   bridge_table.coursename      
	# user.password   
	# role_assignment.roleid (translated to permission)
	# connectors:
	# user.id = role_assignment.userid 
	# bridge_table.courseid = context.instanceid
	# role_assignment.contextid = context.id
	
	if ($need_course) {
		my $bridge_table = $self->sql->_table($self->MOODLE_WEBWORK_BRIDGE_TABLE);
		my $course_field = $self->sql->_quote("course");
		my $coursename_field = $self->sql->_quote("coursename");
		
		if ($self->{params}{moodle17}) {
			my $context_table = $self->sql->_table("context");
			my $id_field = $self->sql->_quote("id");
			my $instanceid_field = $self->sql->quote("instanceid");
			my $role_assignment_table = $self->sql->_table(ROLE_ASSIGNMENT_TABLE);
			my $contextid_field = $self->sql->_quote("contextid");
			push @joins, "JOIN $context_table ON $role_assignment_table.$contextid_field = $context_table.$id_field";
			push @joins, "JOIN $bridge_table ON $bridge_table.$course_field=$context_table.$instanceid_field";
		} else {
			my $type_table = $self->sql->_table("user_$type");
			push @joins, "JOIN $bridge_table ON $bridge_table.$course_field=$type_table.$course_field";
		}
		
		push @where, "$bridge_table.$coursename_field=?";
		#warn "adding $bridge_table.$coursename_field=? to \@where\n";
		push @bind_vals, $self->courseName;
		#warn "adding ", $self->courseName, " to \@bind_vals\n";
	}
	
	# use user table to connect userid with username
	if ($need_user) {
		my $user_table = $self->sql->_table(USER_TABLE);
		my $id_field = $self->sql->_quote("id");
		my $userid_field = $self->sql->_quote("userid");
		
		if ($self->{params}{moodle17}) {
			my $role_assignment_table = $self->sql->_table(ROLE_ASSIGNMENT_TABLE);
			push @joins, "JOIN $user_table ON $user_table.$id_field=$role_assignment_table.$userid_field";
		} else {
			my $type_table = $self->sql->_table("user_$type");
			push @joins, "JOIN $user_table ON $user_table.$id_field=$type_table.$userid_field";
		}
		
		if ($flags->{match_username}) {
			my $username_field = $self->sql->_quote("username");
			push @where, "$user_table.$username_field=?";
			#warn "adding $user_table.$username_field=? to \@where\n";
			push @bind_vals, $flags->{match_username};
			#warn "adding ", $flags->{match_username}, " to \@bind_vals\n";
		}
		if ($flags->{match_username_like}) {
			my $username_field = $self->sql->_quote("username");
			push @where, "$user_table.$username_field LIKE ?";
			push @bind_vals, $flags->{match_username_like};
		}
		if ($flags->{match_password}) {
			my $password_field = $self->sql->_quote("password");
			push @where, "$user_table.$password_field=?";
			#warn "adding $user_table.$password_field=? to \@where\n";
			push @bind_vals, $flags->{match_password};
			#warn "adding ", $flags->{match_password}, " to \@bind_vals\n";
		}
	}
	
	# In Moodle 1.7, the main table is the role_assignments table.
	# In earlier versions, the main table is the user_$type table for the type specified.
	my $main_table = $self->{params}{moodle17}
		? $self->sql->_table(ROLE_ASSIGNMENT_TABLE)
		: $self->sql->_table("user_$type");
	my $stmt = "SELECT $fields_out FROM $main_table";
	$stmt .= " " . join(" ", @joins) if @joins;
	$stmt .= " WHERE " . join(" AND ", @where) if @where;
	
	return $stmt, @bind_vals;
}

sub _course_members_query {
	my ($self, $fields, $flags, $where, $order) = @_;
	#warn "Moodle::_course_members_query: where=", Dumper($where), "\n";
	#warn "Moodle::_course_members_query: flags=", Dumper($flags), "\n";
	
	my $fields_int = ref $fields ? $fields : ["user_id"];
	my $fields_ext = ref $fields ? "*" : "COUNT(*)";
	
	# Moodle 1.7 keeps all participant information in one table so user type (1st argument) isn't needed
	# FIXME does this handle admin users properly?
	my @user_types = $self->{params}{moodle17}
		? ([undef, 1])
		: (["students",1],["teachers",1],["admins",0]);
	
	my @stmt_parts;
	my @bind_vals;
	foreach my $type (@user_types) {
		my ($curr_stmt, @curr_bind_vals) = $self->_course_members_type(@$type, $flags, $fields_int);
		next unless defined $curr_stmt;
		#warn "type=", $type->[0], " curr_stmt=$curr_stmt, curr_bind_vals=@curr_bind_vals\n";
		push @stmt_parts, $curr_stmt;
		push @bind_vals, @curr_bind_vals;
	}
	return unless @stmt_parts;
	#warn "stmt_parts=", join(" | ", @stmt_parts), "\n";
	#warn "bind_vals=@bind_vals\n";
	my $stmt = join(" UNION ", @stmt_parts);
	
	my ($base_where_clause, @base_bind_vals) = $self->sql->where($where, $order);
	#warn "base_where_clause=$base_where_clause\n";
	#warn "base_bind_vals=@base_bind_vals\n";
	if ($base_where_clause =~ /\S/ or not ref $fields) {
		$stmt = "SELECT $fields_ext FROM ($stmt) AS InnerSelect $base_where_clause";
		push @bind_vals, @base_bind_vals;
	}
	
	#warn "in _course_members_query: stmt=$stmt\n";
	#warn "in _course_members_query: bind_vals=@bind_vals\n";
	return $stmt, @bind_vals;
}

################################################################################
# list of users in this course
################################################################################

# FIXME now that we're doing this, can we filter on group names here for section
# and recitation matching?
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
# getto partial inheritance from NewSQL::Std
################################################################################

*exists_where = *WeBWorK::DB::Schema::NewSQL::Std::exists_where;

*get_fields_where = *WeBWorK::DB::Schema::NewSQL::Std::get_fields_where;
*get_fields_where_i = *WeBWorK::DB::Schema::NewSQL::Std::get_fields_where_i;

*list_where = *WeBWorK::DB::Schema::NewSQL::Std::list_where;
*list_where_i = *WeBWorK::DB::Schema::NewSQL::Std::list_where_i;

*get_records_where = *WeBWorK::DB::Schema::NewSQL::Std::get_records_where;
*get_records_where_i = *WeBWorK::DB::Schema::NewSQL::Std::get_records_where_i;

*count = *WeBWorK::DB::Schema::NewSQL::Std::count;
*exists = *WeBWorK::DB::Schema::NewSQL::Std::exists;
*list = *WeBWorK::DB::Schema::NewSQL::Std::list;
*get = *WeBWorK::DB::Schema::NewSQL::Std::get;
*gets = *WeBWorK::DB::Schema::NewSQL::Std::gets;

################################################################################
# utility methods
################################################################################

sub courseName {
	return shift->{params}{courseName};
}

# all the tables that moodle can handle have a single keypart (user_id) so this
# is somewhat easier that it might otherwise be :)
# the return value here will get passed through conv_where later on
sub keyparts_to_where {
	my ($self, $userID) = @_;
	return [user_id_eq=>$userID] if defined $userID;
}

sub gen_update_hashes {
	croak "this would have a moodle-specific implementation if modification was supported";
}

*sql = *WeBWorK::DB::Schema::NewSQL::Std::sql;

1;
