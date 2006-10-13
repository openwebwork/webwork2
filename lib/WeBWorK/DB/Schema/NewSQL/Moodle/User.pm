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

package WeBWorK::DB::Schema::NewSQL::Moodle::User;
use base qw(WeBWorK::DB::Schema::NewSQL::Moodle);

=head1 NAME

WeBWorK::DB::Schema::NewSQL::Moodle::User - Enumerates users from Moodle.

=cut

use strict;
use warnings;
use Carp qw(croak);

# only support the "user" table (this overrides the version in NewSQL.pm)
use constant TABLES => qw(user);

=head1 SUPPORTED PARAMS

This schema pays attention to the following items in the C<params> entry.

=over

=item statusDeletedAbbrevs

Reference to a list of values that represent a deleted user.

=item statusNotDeletedAbbrevs

Reference to a list of values that represent a non-deleted user.

=item statusDeletedDefault

Status value to assign to deleted users.

=item statusNotDeletedDefault

Status value to assign to non-deleted users.

=back

=cut

################################################################################
# constructor for Moodle-specific behavior
################################################################################

sub new {
	my $proto = shift;
	my $self = $proto->SUPER::new(@_);
	
	# generate subquery that returns the userid of each user "in" the course
	$self->{userids_subquery} = [ $self->_userids_subquery($self->courseName) ];
	
	return $self;
}

################################################################################
# where clauses
################################################################################

sub where_status_eq {
	my ($self, $status) = @_;
	if (defined $status) {
		if (grep { $_ eq $status } @{$self->{params}{statusDeletedAbbrevs}}) {
			return {deleted=>{">",0}};
		} elsif (grep { $_ eq $status } @{$self->{params}{statusNotDeletedAbbrevs}}) {
			return {deleted=>{"<=",0}};
		}
	}
	# nothing matches on unknown or undefined status abbrevs
	return {-and=>\("0==1")};
}

sub where_section_eq {
	my ($self, $section) = @_;
	our %flags;
	if (defined $section) {
		$flags{match_section} = 1;
		$flags{match_section_value} = $section;
	} else {
		$flags{match_null_section} = 1;
	}
	return {};
}

sub where_recitation_eq {
	my ($self, $recitation) = @_;
	our %flags;
	if (defined $recitation) {
		$flags{match_recitation} = 1;
		$flags{match_recitation_value} = $recitation;
	} else {
		$flags{match_null_recitation} = 1;
	}
	return {};
}

sub where_section_eq_recitation_eq {
	my $self = shift;
	$self->where_section(shift);
	$self->where_recitation(shift);
	return {};
}

################################################################################
# list of users in this course
################################################################################

sub _per_course_userids_subquery {
	my ($self, $type) = @_;
	
	my $tables = ["user_$type", $self->MOODLE_WEBWORK_BRIDGE_TABLE];
	my $fields = ["user_$type.userid"];
	my $where = $self->sql->_quote("wwassignment_bridge.course")
		."=".$self->sql->_quote("user_$type.course")
		." AND ".$self->sql->_quote("wwassignment_bridge.coursename")
		."=?";
	my $stmt = $self->sql->select($tables, $fields, $where);
}

sub _all_course_userids_subquery {
	my ($self, $type) = @_;
	
	my $tables = ["user_$type"];
	my $fields = ["user_$type.userid"];
	my $stmt = $self->sql->select($tables, $fields);
}

sub _userids_subquery {
	my ($self, $coursename) = @_;
	
	my $stmt = join(" UNION ",
		$self->_per_course_userids_subquery("students"),
		$self->_per_course_userids_subquery("teachers"),
		$self->_all_course_userids_subquery("admins"),
	);
	my @bind_vals = ($coursename)x2;
	return $stmt, @bind_vals;
}

################################################################################
# field conversion
################################################################################

# fields with direct analogs in moodle
our %fields_ww2mdl = (
	user_id => "username",
	first_name => "firstname",
	last_name => "lastname",
	email_address => "email",
	student_id => "idnumber"
);
our %fields_mdl2ww;
@fields_mdl2ww{values %fields_ww2mdl} = keys %fields_ww2mdl;

sub _conv_fields_ww2mdl {
	my ($self, $fields) = @_;
	
	my @result;
	foreach my $field (@$fields) {
		my $q_field = $self->sql->_quote($field);
		if ($field eq "status") {
			my $user_deleted = $self->sql->_quote("deleted");
			my $status_d = $self->dbh->quote($self->{params}{statusDeletedDefault});
			my $status_c = $self->dbh->quote($self->{params}{statusNotDeletedDefault});
			push @result, "IF($user_deleted>0, $status_d, $status_c) AS $q_field";
		} elsif ($field eq "section") {
			my $groups_name = $self->sql->_quote("groups.name");
			push @result, "MIN(IF($groups_name LIKE 'SEC_%',"
				. " SUBSTRING($groups_name, 5), NULL)) AS $q_field";
		} elsif ($field eq "recitation") {
			my $groups_name = $self->sql->_quote("groups.name");
			push @result, "MIN(IF($groups_name LIKE 'SEC_%',"
				. " NULL, $groups_name)) AS $q_field";
		} elsif ($field eq "comment") {
			push @result, "NULL AS $q_field";
		} elsif (exists $fields_ww2mdl{$field}) {
			my $mdl_field = $self->sql->_quote($fields_ww2mdl{$field});
			push @result, "$mdl_field AS $q_field";
		} else {
			croak "Unrecognized field '$field' in field list";
		}
	}
	
	return join(",", @result);
}

sub _conv_order_ww2mdl {
	my ($self, $fields, $order) = @_;
	
	foreach my $field (@$order) {
		if (exists $fields_ww2mdl{$field}) {
			# fields with direct analogs in moodle can sort by real field (faster?)
			$field = $fields_ww2mdl{$field};
		} else {
			# fields that have to be calculated have to sort by the calculated value
			# if the field isn't already included in the field list, add it
			# FIXME -- apparently, we can just put the expression (i.e. "MIN(IF(...))")
			# in the ORDER BY clause, but that would require setting flags and changing
			# the way the order array is handled. this works, but it might be a little
			# slower (and we have to filter out the field in an outer select)
			push @$fields, $field unless grep { $_ eq $field } @$fields;
		}
	}
}

################################################################################
# generate where/having clause fragments for filtering moodle groups
################################################################################

sub _sec_rec_where {
	my ($self, $match_section, $match_recitation, $match_section_value, $match_recitation_value) = @_;
	
	return unless $match_section or $match_recitation;
	
	my $group_name = $self->sql->_quote("groups.name");
	
	my (@where, @bind_vals);
		
	if ($match_section eq "specific") {
		push @where, "$group_name=CONCAT('SEC_',?)";
		push @bind_vals, $match_section_value;
	} else {
		# we need all the recitations, so we can filter on whether they're NULL later
		if ($match_recitation eq "specific") {
			push @where, "$group_name LIKE 'SEC_%'";
		} else {
			# name LIKE 'SEC_%' OR name NOT LIKE 'SEC_%' => matches every record
		}
	}
	
	if ($match_recitation eq "specific") {
		push @where, "$group_name=?";
		push @bind_vals, $match_recitation_value;
	} else {
		# we need all the recitations, so we can filter on whether they're NULL later
		if ($match_section eq "specific") {
			push @where, "$group_name NOT LIKE 'SEC_%'";
		} else {
			# name LIKE 'SEC_%' OR name NOT LIKE 'SEC_%' => matches every record
		}
	}
	
	my $where_clause = "( " . join(" OR ", @where) . " )";
	return $where_clause, @bind_vals;
}

sub _sec_rec_having {
	my ($self, $match_section, $match_recitation) = @_;
	
	return unless $match_section or $match_recitation;
	
	my @having;
	
	my $section = $self->sql->_quote("section");
	my $recitation = $self->sql->_quote("recitation");
	
	if ($match_section eq "specific") {
		push @having, "$section IS NOT NULL";
	} elsif ($match_section eq "none") {
		push @having, "$section IS NULL";
	}
	
	if ($match_recitation eq "specific") {
		push @having, "$recitation IS NOT NULL";
	} elsif ($match_recitation eq "none") {
		push @having, "$recitation IS NULL";
	}
	
	return @having;
}

################################################################################
# inner select statement generation
################################################################################

# i'm doing this kindof the easy way -- there are some optimizations that
# could be made in cases where we're not showing both columns and are only
# matching on one of them, but the group sets are probably going to be
# pretty small and filtering with HAVING and then excluding the unneeded
# fields isn't a big problem.

# FIXME - need similar (but not as complicated) handling for status and comment fields in where clause
#         (actually, i think this can be handled completely within the where clause)
#         comment => if not-null, 0==1, otherwise it goes away
#         status => do same transformation as on field itself -- IF(...,"D","C")=?
# FIXME - might need to add fields to fieldset for ORDER BY items:
#         for non-munged fields, can just translate the ORDER BY field name to the moodle
#         field names... but for munged fields, we would actually have to add them to the
#         fieldset and then eliminate them in an outer select)

sub _inner_select_stmt {
	my ($self, $fields, $where, $order) = @_;
	
	# make local copies (one level of dereferencing is sufficient)
	$fields = [@$fields] if ref $fields;
	$order = [@$order] if ref $order;
	
	local our %flags;
	$where = $self->conv_where($where);
	# flags:
	#   match_section - true if we need to match a specific section
	#   match_section_value - specific section to match
	#   match_null_section - true if we need to match users with no section
	#   match_recitation - true if we need to match a specific recitation
	#   match_recitation_value - specific recitation to match
	#   match_null_recitation - true if we need to match users with no recitation
	#use Data::Dumper;
	#print STDERR Dumper(\%flags);
	
	# this modifies $fields and $order in place
	$self->_conv_order_ww2mdl($fields, $order);
	
	my ($match_section, $match_recitation) = ("")x2;
	$match_section = "specific" if $flags{match_section};
	$match_section = "none" if $flags{match_null_section};
	$match_recitation = "specific" if $flags{match_recitation};
	$match_recitation = "none" if $flags{match_null_recitation};
	
	my $match_section_value = $flags{match_section_value};
	my $match_recitation_value = $flags{match_recitation_value};
	
	my $asked_for_sec_rec = grep { /^(section|recitation)$/ } @$fields;
	my $need_sec_rec = $match_section || $match_recitation || $asked_for_sec_rec;
	
	my @fields = @$fields; # webwork field names at this point, becomes CSV
	#my @tables = $self->sql->_table("user"); # becomes CSV
	my @joins;
	my @where;
	my @bind_vals;
	my @group_by; # becomes CSV
	my @having; # gets ANDed together
	
	# prepend the "id IN ( userids subquery )" part and bind values
	my ($sub_stmt, @sub_bind_vals) = @{$self->{userids_subquery}};
	push @where, $self->sql->_quote("user.id") . " IN ( $sub_stmt )";
	push @bind_vals, @sub_bind_vals;
	
	if ($need_sec_rec) {
		# add to fields list if they're not there already
		push @fields, "section" unless grep { $_ eq "section" } @fields;
		push @fields, "recitation" unless grep { $_ eq "recitation" } @fields;
		
		# we'll be grouping by user.id (because of grouping MIN() function)
		push @group_by, $self->sql->_quote("user.id");
		
		# join groups_members table
		push @joins, " JOIN ".$self->sql->_table("groups_members")
			. " ON " . $self->sql->_quote("groups_members.userid")
			. "=" . $self->sql->_quote("user.id");
		
		# join groups table
		push @joins, " JOIN ".$self->sql->_table("groups")
			. " ON " . $self->sql->_quote("groups_members.groupid")
			. "=" . $self->sql->_quote("groups.id");
		
		# join bridge table (to restrict us to groups in this course)
		push @joins, " JOIN ".$self->sql->_table($self->MOODLE_WEBWORK_BRIDGE_TABLE)
			. " ON " . $self->sql->_quote($self->MOODLE_WEBWORK_BRIDGE_TABLE.".course")
			. "=" . $self->sql->_quote("groups.courseid");
		
		# restrict bridges to this course
		push @where, $self->sql->_quote($self->MOODLE_WEBWORK_BRIDGE_TABLE.".coursename") . "=?";
		push @bind_vals, $self->courseName;
		
		# get where clause for section/recitation matching, append it to main where clause
		my ($sec_rec_where_clause, @sec_rec_bind_vals) = $self->_sec_rec_where($match_section,
			$match_recitation, $match_section_value, $match_recitation_value);
		#print STDERR Dumper(\@sec_rec_bind_vals);
		if (defined $sec_rec_where_clause) {
			push @where, $sec_rec_where_clause;
			push @bind_vals, @sec_rec_bind_vals;
		}
		
		# get having clause for section/recitation matching, append it to main having clause
		push @having, $self->_sec_rec_having($match_section, $match_recitation);
	}
	
	my ($base_where_clause, @base_bind_vals) = $self->sql->where($where, $order);
	$base_where_clause =~ s/(\bORDER BY\b.*)//;
	my $order_by_clause = defined $1 ? $1 : "";
	$base_where_clause =~ s/\bWHERE\b//; # annoying
	if ($base_where_clause =~ /\S/) {
		push @where, $base_where_clause;
		push @bind_vals, @base_bind_vals;
	}
	my $where_clause = @where ? "WHERE " . join(" AND ", @where) : "";
	
	@fields = $self->keyfields unless @fields; # default fieldset
	my $fields_clause = $self->_conv_fields_ww2mdl(\@fields);
	
	my $table = $self->sql->_table("user");
	my $join_clause = join(" ", @joins);
	my $group_by_clause = @group_by ? "GROUP BY " . join(",", @group_by) : "";
	my $having_clause = @having ? "HAVING " . join(" AND ", @having) : "";
	
	# make sure everything's defined
	#{
	#	my $junk;
	#	$junk = "$fields_clause";
	#	$junk = "table";
	#	$junk = "$join_clause";
	#	$junk = "$where_clause";
	#	$junk = "$group_by_clause";
	#	$junk = "$having_clause";
	#	$junk = "$order_by_clause";
	#}
	
	my $stmt = "SELECT $fields_clause FROM $table $join_clause $where_clause $group_by_clause $having_clause $order_by_clause";
	
	# DEBUG
	#$stmt =~ s/\?/$self->dbh->quote(shift @bind_vals)/eg;
	#return "$stmt;";
	# END DEBUG
	
	return $stmt, @bind_vals;
}

################################################################################
# counting/existence
################################################################################

# returns the number of matching rows
sub count_where {
	my ($self, $where) = @_;
	
	my ($inner_stmt, @bind_vals) = $self->_inner_select_stmt([$self->keyfields], $where);
	my $stmt = "SELECT COUNT(*) FROM ( $inner_stmt ) AS InnerSelect";
	
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
	
	my ($inner_stmt, @bind_vals) = $self->_inner_select_stmt($fields, $where, $order);
	my $stmt = $self->sql->select("", $fields);
	$stmt =~ s/(?<=FROM).*//;
	$stmt .= " ( $inner_stmt ) AS InnerSelect";
	
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
