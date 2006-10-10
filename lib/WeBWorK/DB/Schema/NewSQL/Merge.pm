################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Schema/NewSQL/Merge.pm,v 1.2 2006/10/06 20:20:35 sh002i Exp $
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

=head1 SUPPORTED PARAMS

This schema pays attention to the following items in the C<params> entry.

=over

=item merge

A reference to an array listing the tables to merge, from highest priority to
lowest priority.

=back

=cut

################################################################################
# constructor for merge-specific behavior
################################################################################

sub new {
	my $proto = shift;
	my $self = $proto->SUPER::new(@_);
	
	$self->merge_init;
	
	$self->sql_init;
	
	return $self;
}

sub merge_init {
	my $self = shift;
	my $db = $self->{db};
	
	my @merge_tables = @{$self->{params}{merge}};
	
	my %sql_table_names;
	@sql_table_names{@merge_tables} = map { $db->{$_}->sql_table_name } @merge_tables;
	
	my %sql_field_names;
	foreach my $table (@merge_tables) {
		my @fields = $db->{$table}->fields;
		@{$sql_field_names{$table}}{@fields} = map { $db->{$table}->sql_field_name($_) } @fields;
	}
	
	my $pri = $merge_tables[0];
	
	my %sql_fieldexprs;
	my $sql_whereprefix;
	
	foreach my $field ($db->{$pri}->fields) {
		my $sql_field_name = $sql_field_names{$pri}{$field};
		if ($db->{$pri}->field_data->{$field}{key}) {
			# if it's a keyfield, use the version from the primary table
			# (they're all going to be the same anyway)
			$sql_fieldexprs{$field} = "`$sql_table_names{$pri}`.`$sql_field_names{$pri}{$field}`";
			# add this field to the where clause
			foreach my $table (@merge_tables[1..$#merge_tables]) {
				if (exists $db->{$table}->field_data->{$field}) {
					$sql_whereprefix .= "`$sql_table_names{$pri}`"
						. ".`$sql_field_names{$pri}{$field}`"
						. "=`$sql_table_names{$table}`"
						. ".`$sql_field_names{$table}{$field}`"
						. " AND ";
				}
			}
		} else {
			# if it's not a keyfield, we use the COALESCE function to select a
			# value from the table that has the first non-NULL value
			my $coalesce = "COALESCE(";
			foreach my $table (@merge_tables) {
				next unless exists $db->{$table}->field_data->{$field};
				$coalesce .= "`$sql_table_names{$table}`.`$sql_field_names{$table}{$field}`,";
			}
			chop $coalesce; # get rid of trailing comma
			$coalesce .= ")";
			$sql_fieldexprs{$field} = $coalesce;
		}
	}
	
	$self->{pri} = $pri;
	$self->{sql_table_names} = \%sql_table_names;
	$self->{sql_field_names} = \%sql_field_names;
	$self->{sql_fieldexprs} = \%sql_fieldexprs;
	$self->{sql_whereprefix} = $sql_whereprefix;
}

sub sql_init {
	my $self = shift;
	
	# transformation functions for table and field names: these allow us to pass
	# the WeBWorK table/field names to SQL::Abstract, and have it translate them
	# to the SQL table/field names from tableOverride and fieldOverride.
	# (Without this, it would be hard to translate field names in WHERE
	# structures, since they're so convoluted.)
	my $transform_table = sub {
		my $label = shift;
		if (exists $self->{sql_table_names}{$label}) {
			return $self->{sql_table_names}{$label};
		} else {
			warn "can't transform unrecognized table name '$label'";
			return $label;
		}
	};
	
	# This transformation is called both on bare field names and on qualified
	# field names (i.e. "table.field"), but not on bare table names.
	my $transform_all = sub {
		my $label = shift;
		my ($table, $field) = $label =~ /(?:(.+)\.)?(.+)/;
		$table = $self->{pri} unless defined $table;
		if (exists $self->{sql_field_names}{$table}{$field}) {
			$field = $self->{sql_field_names}{$table}{$field};
		} else {
			warn "can't transform unrecognized field name '$field' for table name '$table'";
		}
		$table = $transform_table->($table);
		return "`$table`.`$field`";
	};
	
	# add SQL statement generation object
	$self->{sql} = new WeBWorK::DB::Utils::SQLAbstractIdentTrans(
		quote_char => "`",
		name_sep => ".",
		transform_table => $transform_table,
		transform_all => $transform_all,
	);
}

################################################################################
# lowlevel get
################################################################################

*get_fields_where = *WeBWorK::DB::Schema::NewSQL::Std::get_fields_where;
*get_fields_where_i = *WeBWorK::DB::Schema::NewSQL::Std::get_fields_where_i;

# helper, returns a prepared statement handle
sub _get_fields_where_prepex {
	my ($self, $fields, $where, $order) = @_;
	
	# pull the requested fields out of $self->{sql_fieldexprs}
	my $sql_fields = join(",", @{$self->{sql_fieldexprs}}{@$fields});
	
	# generate the WHERE clause separately, and then prepend $self->{sql_whereprefix}
	my ($stmt, @bind_vals) = $self->sql->where($where, $order);
	my $where_prefix = $self->{sql_whereprefix};
	$stmt =~ s/\bWHERE\b/WHERE $where_prefix/;
	
	# instead of using $self->table, use the merge list
	(substr($stmt, 0, 0)) = $self->sql->select($self->{params}{merge}, $sql_fields);
	
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3); # 3: see DBI docs
	$self->debug_stmt($sth, @bind_vals);
	$sth->execute(@bind_vals);	
	return $sth;
}

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

################################################################################
# utility methods
################################################################################

*sql = *WeBWorK::DB::Schema::NewSQL::Std::sql;

1;
