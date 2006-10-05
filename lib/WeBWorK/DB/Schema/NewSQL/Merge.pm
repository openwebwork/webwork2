################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Schema/NewSQL.pm,v 1.7 2006/10/02 16:32:51 sh002i Exp $
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

package WeBWorK::DB::Schema::NewSQL::Merge;
use base qw(WeBWorK::DB::Schema::NewSQL);

=head1 NAME

WeBWorK::DB::Schema::NewSQL::Merge - get merged records from multiple tables in
an SQL database.

=cut

use strict;
use warnings;
use Carp qw(croak);
use Iterator;
use Iterator::Util;
use WeBWorK::DB::Utils::SQLAbstractIdentTrans;
use WeBWorK::Debug;

use constant TABLES => qw(*);
use constant STYLE  => "dbi";

{
	no warnings 'redefine';
	
	sub debug {
		my ($self, @string) = @_;
		WeBWorK::Debug::debug(@string) if $self->{params}{debug};
	}
}

=head1 SUPPORTED PARAMS

This schema pays attention to the following items in the C<params> entry.

=over

=item merge

A reference to an array listing the tables to merge, from highest priority to
lowest priority.

=back

=cut

################################################################################
# constructor for SQL-specific behavior
################################################################################

sub new {
	my ($proto, $db, $driver, $table, $record, $params) = @_;
	my $self = $proto->SUPER::new($db, $driver, $table, $record, $params);
	
	my @merge_tables = @{$self->{params}{merge}};
	
	my %sql_table_names;
	@sql_table_names{@merge_tables} = map { $self->{db}{$_}->sql_table_name } @merge_tables;
	
	my $pri_table = shift @merge_tables;
	my $pri_table_schema = $self->{db}{$pri_table};
	my $pri_table_sql = $sql_table_names{$pri_table};
	my %pri_table_data = $pri_table_schema->field_data;
	
	my %sql_fieldexprs;
	my $sql_whereprefix;
	
	foreach my $field ($pri_table_schema->fields) {
		my $sql_field_name = $pri_table_schema->sql_field_name($field);
		if ($pri_table_data->{$field}{key}) {
			# if it's a keyfield, use the version from the primary table
			# (they're all going to be the same anyway)
			$sql_fieldexprs{$field} = "`$pri_table_sql`.`$sql_field_name`";
			# add this field to the where clause
			foreach my $table (@merge_tables) {
				my %table_data = $self->{db}{$table}->table_data;
				if (exists $table_data{$field}) {
					$sql_whereprefix .= "`$pri_table_sql`.`sql_field_name`".
						. "=`$sql_table_names{$table}`.`"
						. $self->{db}{$table}->sql_field_name($field) ."` AND ";
				}
			}
		} else {
			# if it's not a keyfield, we use the COALESCE function to select a
			# value from the table that has the first non-NULL value
			my $coalesce = "COALESCE(";
			my $first = 1;
			foreach my $table (@merge_tables) {
				$first ? $first = 0 : $coalesce .= ",";
				$coalesce .= "`$sql_table_names{$table}`.`"
					. $self->{db}{$table}->sql_field_name($field) . "`";
			}
			$coalesce .= ")";
			$sql_fieldexprs{$field} = $coalesce;
		}
	}
	
	$self->{sql_tablelist} = [@sql_table_names{@merge_tables}];
	$self->{sql_fieldexprs} = \%sql_fieldexprs;
	$self->{sql_whereprefix} = $sql_whereprefix;
	
	return $self;
	
	# use the SQL statement generation object from the primary table, so that
	# the table/field name transformation functions will be corrent (not point
	# in duplicating that logic here)
	$self->{sql} = $pri_table_schema->{sql};
}

=for comment

SELECT
sam_course_set_user.user_id,sam_course_set_user.set_id,sam_course_set_user.psvn,
COALESCE(sam_course_set.set_header,sam_course_set_user.set_header),COALESCE(
sam_course_set.hardcopy_header,sam_course_set_user.hardcopy_header) FROM
sam_course_set, sam_course_set_user where
sam_course_set_user.set_id=sam_course_set.set_id and
sam_course_set_user.set_id='imagegen_test' and
sam_course_set_user.user_id='sam';

=cut

################################################################################
# lowlevel get
################################################################################

# returns a list of refs to arrays containing field values for each matching row
sub get_fields_where {
	my ($self, $fields, $where, $order) = @_;
	
	my $sth = $self->_get_fields_where_prepex($fields, $where, $order);
	my @results = @{ $sth->fetchall_arrayref };
	$sth->finish;
	return @results;
}

# returns an Iterator that generates refs to arrays containg field values for each matching row
sub get_fields_where_i {
	my ($self, $fields, $where, $order) = @_;
	
	my $sth = $self->_get_fields_where_prepex($fields, $where, $order);
	return new Iterator sub {
		my $row = $sth->fetchrow_arrayref;
		if (defined $row) {
			return [@$row]; # need to make a copy here, since DBI reuses arrayrefs
		} else {
			$sth->finish; # let the server know we're done getting values (is this necessary?)
			undef $sth; # allow the statement handle to get garbage-collected
			Iterator::is_done();
		}
	};
}

# helper, returns a prepared statement handle
sub _get_fields_where_prepex {
	my ($self, $fields, $where, $order) = @_;
	
	# pull the requested fields out of $self->{sql_fieldlist}
	my $sql_fields = join(",", @{$self->{sql_fieldexprs}}{@$fields});
	
	# generate the WHERE clause separately, and then prepend $self->{sql_whereprefix}
	my ($stmt, @bind_vals) = $self->sql->where($where, $order);
	my $where_prefix = $self->{sql_whereprefix};
	$stmt =~ s/^WHERE/WHERE $where_prefix /;
	
	# instead of using $self->table, use join("," $self->{tablelist})
	(substr($stmt, 0, 0)) = $self->sql->select($self->{tablelist}, $sql_fields);
	
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3); # 3: see DBI docs
	$sth->execute(@bind_vals);	
	return $sth;
}

################################################################################
# getting records
################################################################################

# returns a record objects for each matching row
sub get_records_where {
	my ($self, $where, $order) = @_;
	
	return map { $self->box($_) }
		$self->get_fields_where([$self->fields], $where, $order);
}

# returns an iterator that generates a record object for each matching row
sub get_records_where_i {
	my ($self, $where, $order) = @_;
	
	return imap { $self->box($_) }
		$self->get_fields_where_i([$self->fields], $where, $order);
}

################################################################################
# compatibility methods for old API
################################################################################

# oldapi
sub count {
	croak "read-only table";
}

# oldapi
sub list {
	croak "read-only table";
}

# oldapi
sub exists {
	croak "read-only table";
}

# oldapi
sub get {
	my ($self, @keyparts) = @_;
	return ( $self->get_records_where($self->keyparts_to_where(@keyparts)) )[0];
}

# oldapi
sub gets {
	my ($self, @keypartsRefList) = @_;
	return map { $self->get_records_where($self->keyparts_to_where(@$_)) } @keypartsRefList;
}

# oldapi
sub add {
	croak "read-only table";
}

# oldapi
sub put {
	croak "read-only table";
}

# oldapi
sub delete {
	croak "read-only table";
}

################################################################################
# utility methods
################################################################################

1;
