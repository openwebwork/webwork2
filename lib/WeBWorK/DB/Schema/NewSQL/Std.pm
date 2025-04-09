package WeBWorK::DB::Schema::NewSQL::Std;
use Mojo::Base 'WeBWorK::DB::Schema::NewSQL';

=head1 NAME

WeBWorK::DB::Schema::NewSQL - support SQL access to single tables.

=cut

use Carp qw(croak);
use Iterator;
use Iterator::Util;
use File::Temp;
use String::ShellQuote;
use Scalar::Util qw(weaken);

use WeBWorK::DB::Utils qw(parse_dsn);
use WeBWorK::DB::Utils::SQLAbstractIdentTrans;
use WeBWorK::Debug;

=head1 SUPPORTED PARAMS

This schema pays attention to the following items in the C<params> entry.

=over

=item tableOverride

Alternate name for this table, to satisfy SQL naming requirements.

=back

=cut

################################################################################
# constructor for SQL-specific behavior
################################################################################

sub new {
	my $self = shift->SUPER::new(@_);
	# effectively calls WeBWorK::DB::Schema::new

	$self->sql_init;

	return $self;
}

sub sql_init {
	my $self = shift;
	weaken $self;

	# Transformation function for table names.  This allows us to pass the WeBWorK table names to
	# SQL::Abstract, and have it translate them to the SQL table names from tableOverride.
	my $transform_table;
	if (defined $self->{params}{tableOverride}) {
		$transform_table = sub {
			my $label = shift;
			if ($label eq $self->{table}) {
				return $self->{params}{tableOverride};
			} else {
				return $label;
			}
		};
	}

	$self->{sql} = new WeBWorK::DB::Utils::SQLAbstractIdentTrans(
		quote_char      => "`",
		name_sep        => ".",
		transform_table => $transform_table
	);
}

################################################################################
# table creation
################################################################################

sub create_table {
	my ($self) = @_;
	my $stmt = $self->_create_table_stmt;
	$self->dbh->do($stmt);
	my @fields = $self->fields;
	my @rows   = map { [ @$_{@fields} ] } $self->initial_records;
	return $self->insert_fields(\@fields, \@rows);
}

# this is mostly ripped off from wwdb_check, which is pretty much a per-table
# version of the table creation code in sql_single.pm. wwdb_check is going away
# after 2.3.x, and sql_single.pm is being replaced by this code.
sub _create_table_stmt {
	my ($self) = @_;

	my $sql_table_name = $self->sql_table_name;

	# insure correct syntax if $engine or $character_set is empty. Can't have ENGINE = in mysql stmt.
	my $engine               = $self->engine;
	my $ENGINE_CLAUSE        = ($engine) ? "ENGINE=$engine" : "";
	my $character_set        = $self->character_set;
	my $CHARACTER_SET_CLAUSE = ($character_set) ? "DEFAULT CHARACTER SET = $character_set" : "";

	my @field_list;

	# generate a column specification for each field
	foreach my $field ($self->fields) {
		my $sql_field_name = $self->sql_field_name($field);
		my $sql_field_type = $self->field_data->{$field}{type};

		push @field_list, "`$sql_field_name` $sql_field_type";
	}

	# generate an INDEX specification for each all possible sets of keyfields (i.e. 0+1+2, 1+2, 2)
	my @keyfields = $self->keyfields;
	foreach my $start (0 .. $#keyfields) {
		my @index_components;

		foreach my $component (@keyfields[ $start .. $#keyfields ]) {
			my $sql_field_name   = $self->sql_field_name($component);
			my $sql_field_type   = $self->field_data->{$component}{type};
			my $length_specifier = $sql_field_type =~ /(text|blob)/i ? "(100)" : "";
			if ($start == 0 and $length_specifier and $sql_field_type !~ /tiny/i) {
				warn "warning: UNIQUE KEY component $sql_field_name is a $sql_field_type, which can"
					. " hold values longer than 100 characters. However, in order to support utf8"
					. " we limit the key prefix for text/blob fields to 100. Therefore, uniqueness"
					. "must occur within the first 100 characters of this field.";
			}
			push @index_components, "`$sql_field_name`$length_specifier";
		}

		my $index_string = join(", ", @index_components);
		my $index_type   = $start == 0 ? "UNIQUE KEY" : "KEY";
		push @field_list, "$index_type ( $index_string )";
	}

	my $field_string = join(", ", @field_list);
	return "CREATE TABLE `$sql_table_name` ( $field_string ) $ENGINE_CLAUSE $CHARACTER_SET_CLAUSE";
}

################################################################################
# table renaming
################################################################################

sub rename_table {
	my ($self, $new_sql_table_name) = @_;

	my $stmt = $self->_rename_table_stmt($new_sql_table_name);
	return $self->dbh->do($stmt);
}

sub _rename_table_stmt {
	my ($self, $new_sql_table_name) = @_;

	my $sql_table_name = $self->sql_table_name;
	return "RENAME TABLE `$sql_table_name` TO `$new_sql_table_name`";
}

################################################################################
# table deletion
################################################################################

sub delete_table {
	my ($self) = @_;

	my $stmt = $self->_delete_table_stmt;
	return $self->dbh->do($stmt);
}

sub _delete_table_stmt {
	my ($self) = @_;

	my $sql_table_name = $self->sql_table_name;
	return "DROP TABLE IF EXISTS `$sql_table_name`";
}

################################################################################
# table dumping and restoring
################################################################################

# These are limited to mysql, since they use the mysql monitor and mysqldump.
# An exception will be thrown if the table in question doesn't use mysql.
# It also requires some additions to the params:
#     mysqldump_path - path to mysqldump(1)
#     mysql_path - path to mysql(1)

sub dump_table {
	my ($self, $dumpfile_path) = @_;

	my ($my_cnf, $database) = $self->_get_db_info;
	my $mysqldump = $self->dbh->{params}{mysqldump_path};

	# 2>&1 is specified first, which apparently makes stderr go to stdout
	# and stdout (not including stderr) go to the dumpfile. see bash(1).
	my $dump_cmd = '2>&1 '
		. shell_quote($mysqldump)
		. ' --defaults-file='
		. shell_quote($my_cnf->filename) . ' '
		. shell_quote($database) . ' '
		. shell_quote($self->sql_table_name) . ' > '
		. shell_quote($dumpfile_path);
	my $dump_out = readpipe $dump_cmd;
	if ($?) {
		my $exit   = $? >> 8;
		my $signal = $? & 127;
		my $core   = $? & 128;
		warn "Warning: Failed to dump table '"
			. $self->sql_table_name
			. "' with command '$dump_cmd' (exit=$exit signal=$signal core=$core): $dump_out\n";
		warn "This can be expected if the course was created with an earlier version of WeBWorK.";
	}

	return 1;
}

sub restore_table {
	my ($self, $dumpfile_path) = @_;

	my ($my_cnf, $database) = $self->_get_db_info;
	my $mysql = $self->dbh->{params}{mysql_path};

	my $restore_cmd = '2>&1 '
		. shell_quote($mysql)
		. ' --defaults-file='
		. shell_quote($my_cnf->filename) . ' '
		. shell_quote($database) . ' < '
		. shell_quote($dumpfile_path);
	my $restore_out = readpipe $restore_cmd;
	if ($?) {
		my $exit   = $? >> 8;
		my $signal = $? & 127;
		my $core   = $? & 128;
		warn "Failed to restore table '"
			. $self->sql_table_name
			. "' with command '$restore_cmd' (exit=$exit signal=$signal core=$core): $restore_out\n";
	}

	return 1;
}

sub _get_db_info {
	my ($self)   = @_;
	my $dsn      = $self->dbh->{source};
	my $username = $self->dbh->{params}{username};
	my $password = $self->dbh->{params}{password};

	my %dsn = parse_dsn($self->dbh->{source});
	die "No database specified in DSN!" unless defined $dsn{database};

	my $mysqldump = $self->dbh->{params}{mysqldump_path};

	# Conditionally add column-statistics=0 as MariaDB databases do not support it
	# see: https://serverfault.com/questions/912162/
	#   mysqldump-throws-unknown-table-column-statistics-in-information-schema-1109
	#   https://github.com/drush-ops/drush/issues/4410
	my $column_statistics_off =
		`$mysqldump --help | grep 'column-statistics'` ? "[mysqldump]\ncolumn-statistics=0\n" : '';

	# Doing this securely is kind of a hassle...
	my $my_cnf = File::Temp->new;
	$my_cnf->unlink_on_destroy(1);
	chmod 0600, $my_cnf or die "failed to chmod 0600 $my_cnf: $!";
	print $my_cnf "[client]\n";
	print $my_cnf qq{user="$username"\n}     if defined $username  && length($username) > 0;
	print $my_cnf qq{password="$password"\n} if defined $password  && length($password) > 0;
	print $my_cnf qq{host="$dsn{host}"\n}    if defined $dsn{host} && length($dsn{host}) > 0;
	print $my_cnf qq{port="$dsn{port}"\n}    if defined $dsn{port} && length($dsn{port}) > 0;
	print $my_cnf $column_statistics_off     if $column_statistics_off;

	return ($my_cnf, $dsn{database});
}

####################################################
# checking Fields
####################################################

sub tableFieldExists {
	my $self       = shift;
	my $field_name = shift;
	my $stmt       = $self->_exists_field_stmt($field_name);
	my $result     = $self->dbh->do($stmt);
	return ($result eq "1") ? 1 : 0;    # failed result is 0E0
}

sub _exists_field_stmt {
	my $self           = shift;
	my $field_name     = shift;
	my $sql_table_name = $self->sql_table_name;
	return "Describe `$sql_table_name` `$field_name`";
}
####################################################
# adding Field column
####################################################

sub add_column_field {
	my $self       = shift;
	my $field_name = shift;
	my $stmt       = $self->_add_column_field_stmt($field_name);
	#warn "database command $stmt";
	my $result = $self->dbh->do($stmt);
	#warn "result of add column is $result";
	#return  ($result eq "0E0") ? 0 : 1;    # failed result is 0E0
	return 1;    #FIXME  how to determine if database update was successful???
}

sub _add_column_field_stmt {
	my $self           = shift;
	my $field_name     = shift;
	my $sql_table_name = $self->sql_table_name;
	my $sql_field_name = $self->sql_field_name($field_name);
	my $sql_field_type = $self->field_data->{$field_name}{type};
	return "Alter table `$sql_table_name` add column `$sql_field_name` $sql_field_type";
}

####################################################
# deleting Field column
####################################################

sub drop_column_field {
	my $self       = shift;
	my $field_name = shift;
	my $stmt       = $self->_drop_column_field_stmt($field_name);
	#warn "database command $stmt";
	my $result = $self->dbh->do($stmt);
	#warn "result of add column is $result";
	#return  ($result eq "0E0") ? 0 : 1;    # failed result is 0E0
	return 1;    #FIXME  how to determine if database update was successful???
}

sub _drop_column_field_stmt {
	my $self           = shift;
	my $field_name     = shift;
	my $sql_table_name = $self->sql_table_name;
	my $sql_field_name = $self->sql_field_name($field_name);
	return "Alter table `$sql_table_name` drop column `$sql_field_name` ";
}

####################################################
# Change the type of a column to the type defined in the schema
####################################################

sub change_column_field_type {
	my ($self, $field_name) = @_;
	return 0 unless defined $self->{record}->FIELD_DATA->{$field_name};
	eval {
		$self->dbh->do('ALTER TABLE `'
				. $self->sql_table_name
				. '` MODIFY '
				. $self->sql_field_name($field_name) . ' '
				. $self->{record}->FIELD_DATA->{$field_name}{type}
				. ';');
	};
	return $@ ? 0 : 1;
}

####################################################
# rebuild indexes for the table
####################################################

sub rebuild_indexes {
	my ($self) = @_;

	my $sql_table_name = $self->sql_table_name;
	my $field_data     = $self->field_data;

	# A key field column is going to be removed.  The schema will not have the information for this column.  So the
	# indexes need to be obtained from the database.  Note that each element of the returned array is an array reference
	# of the form [ Table, Non_unique, Key_name, Seq_in_index, Column_name, ... ] (the information indicated by the
	# ellipsis is not needed here).  Only the first column in each sequence is needed.
	my @indexes = grep { $_->[3] == 1 } @{ $self->dbh->selectall_arrayref("SHOW INDEXES FROM `$sql_table_name`") };

	# The columns need to be obtained from the database to determine the types of the columns.  The information from the
	# schema cannot be trusted because it doesn't have information about the field being dropped.  Note that each
	# element of the returned array is an array reference of the form [ Field, Type, Null, Key, Default, Extra ] and
	# Extra contains AUTO_INCREMENT for those fields that have that attribute.
	my $columns = $self->dbh->selectall_arrayref("SHOW COLUMNS FROM `$sql_table_name`");

	# First drop all indexes for the table.
	my @auto_increment_fields;
	for my $index (@indexes) {
		# If a field has the AUTO_INCREMENT attribute, then that needs to be removed before the index can be dropped.
		my $column = (grep { $index->[4] eq $_->[0] } @$columns)[0];
		if (defined $column && $column->[5] =~ m/AUTO_INCREMENT/i) {
			$self->dbh->do("ALTER TABLE `$sql_table_name` MODIFY `$column->[0]` $column->[1]");
			push @auto_increment_fields, $column->[0];
		}

		$self->dbh->do("ALTER TABLE `$sql_table_name` DROP INDEX `$index->[2]`");
	}

	# Add the indices for the table according to the schema.
	my @keyfields = $self->keyfields;
	for my $start (0 .. $#keyfields) {
		my @index_components;
		my $sql_field_name = $self->sql_field_name($keyfields[$start]);

		for my $component (@keyfields[ $start .. $#keyfields ]) {
			my $sql_field_name   = $self->sql_field_name($component);
			my $sql_field_type   = $field_data->{$component}{type};
			my $length_specifier = $sql_field_type =~ /(text|blob)/i ? '(100)' : '';
			push @index_components, "`$sql_field_name`$length_specifier";
		}

		my $index_string = join(', ', @index_components);
		my $index_type   = $start == 0 ? 'UNIQUE KEY' : 'KEY';

		$self->dbh->do("ALTER TABLE `$sql_table_name` ADD $index_type ($index_string)");
	}

	# Finally add the AUTO_INCREMENT attribute back to those columns that is was removed from.
	for my $field (@auto_increment_fields) {
		my $sql_field_name = $self->sql_field_name($field);
		$self->dbh->do("ALTER TABLE `$sql_table_name` MODIFY `$sql_field_name` $field_data->{$field}{type}");
	}

	return 1;
}

####################################################
# checking Tables
####################################################
sub tableExists {
	my $self   = shift;
	my $stmt   = $self->_exists_table_stmt;
	my $result = eval { $self->dbh->do($stmt); };
	(caught WeBWorK::DB::Ex::TableMissing) ? 0 : 1;
}

sub _exists_table_stmt {
	my $self           = shift;
	my $sql_table_name = $self->sql_table_name;
	return "Describe `$sql_table_name` ";
}

################################################################################
# counting/existence
################################################################################

# returns the number of matching rows
sub count_where {
	my ($self, $where) = @_;
	$where = $self->conv_where($where);

	my ($stmt, @bind_vals) = $self->sql->select($self->table, "COUNT(*)", $where);
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3);    # 3 -- see DBI docs
	$self->dbh->debug_stmt($sth, @bind_vals);
	$sth->execute(@bind_vals);
	my ($result) = $sth->fetchrow_array;
	$sth->finish;

	return $result;
}

# returns true iff there is at least one matching row
sub exists_where {
	my ($self, $where) = @_;
	return $self->count_where($where) > 0;
}

################################################################################
# lowlevel get
################################################################################

# returns a list of refs to arrays containing field values for each matching row
sub get_fields_where {
	my ($self, $fields, $where, $order) = @_;
	$fields ||= [ $self->fields ];

	my $sth     = $self->_get_fields_where_prepex($fields, $where, $order);
	my @results = @{ $sth->fetchall_arrayref };
	$sth->finish;
	return @results;
}

# returns an Iterator that generates refs to arrays containg field values for each matching row
sub get_fields_where_i {
	my ($self, $fields, $where, $order) = @_;
	$fields ||= [ $self->fields ];

	my $sth = $self->_get_fields_where_prepex($fields, $where, $order);
	return new Iterator sub {
		my @row = $sth->fetchrow_array;
		if (@row) {
			return \@row;
		} else {
			$sth->finish;    # let the server know we're done getting values
			undef $sth;      # allow the statement handle to get garbage-collected
			Iterator::is_done();
		}
	};
}

# helper, returns a prepared statement handle
sub _get_fields_where_prepex {
	my ($self, $fields, $where, $order) = @_;
	$where = $self->conv_where($where);

	my ($stmt, @bind_vals) = $self->sql->select($self->table, $fields, $where, $order);
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3);    # 3: see DBI docs
	$self->dbh->debug_stmt($sth, @bind_vals);
	$sth->execute(@bind_vals);
	return $sth;
}

################################################################################
# getting keyfields (a.k.a. listing)
################################################################################

# returns a list of refs to arrays containing keyfield values for each matching row
sub list_where {
	my ($self, $where, $order) = @_;
	return $self->get_fields_where([ $self->keyfields ], $where, $order);
}

# returns an iterator that generates refs to arrays containing keyfield values for each matching row
sub list_where_i {
	my ($self, $where, $order) = @_;
	return $self->get_fields_where_i([ $self->keyfields ], $where, $order);
}

################################################################################
# getting records
################################################################################

# returns a record objects for each matching row
sub get_records_where {
	my ($self, $where, $order) = @_;

	return map { $self->box($_) } $self->get_fields_where([ $self->fields ], $where, $order);
}

# returns an iterator that generates a record object for each matching row
sub get_records_where_i {
	my ($self, $where, $order) = @_;

	return imap { $self->box($_) }
	$self->get_fields_where_i([ $self->fields ], $where, $order);
}

################################################################################
# lowlevel insert
################################################################################

# returns the number of rows affected by inserting each row
sub insert_fields {
	my ($self, $fields, $rows) = @_;

	my ($sth, @order) = $self->_insert_fields_prep($fields);
	my @results;
	foreach my $row (@$rows) {
		my @bind_vals = @$row[@order];
		$self->dbh->debug_stmt($sth, @bind_vals);
		push @results, $sth->execute(@bind_vals);
	}
	$sth->finish;
	return @results;
}

# returns the number of rows affected by inserting each row
sub insert_fields_i {
	my ($self, $fields, $rows_i) = @_;

	my ($sth, @order) = $self->_insert_fields_prep($fields);
	my @results;
	until ($rows_i->is_exhausted) {
		my @bind_vals = @{ $rows_i->value }[@order];
		$self->dbh->debug_stmt($sth, @bind_vals);
		push @results, $sth->execute(@bind_vals);
	}
	$sth->finish;
	return @results;
}

# helper, returns a prepared statement handle
sub _insert_fields_prep {
	my ($self, $fields) = @_;

	# we'll use dummy values to determine bind order
	my %values;
	@values{@$fields} = (0 .. @$fields - 1);

	my ($stmt, @order) = $self->sql->insert($self->table, \%values);
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3);    # 3: see DBI docs
	return $sth, @order;
}

################################################################################
# inserting records
################################################################################

# returns the number of rows affected by inserting each record
sub insert_records {
	my ($self, $Records) = @_;
	return $self->insert_fields_i([ $self->fields ], imap { $self->unbox($_) } iarray $Records);
}

# returns the number of rows affected by inserting each record
sub insert_records_i {
	my ($self, $Records_i) = @_;
	return $self->insert_fields_i([ $self->fields ], imap { $self->unbox($_) } $Records_i);
}

################################################################################
# lowlevel update-where
################################################################################

# execute a single UPDATE by passing a ref to a hash mapping field names to new
# values and a reference to a hash specifying a where clause

# returns number of rows affected by update
sub update_where {
	my ($self, $fieldvals, $where) = @_;
	$where = $self->conv_where($where);

	my ($stmt, @bind_vals) = $self->sql->update($self->table, $fieldvals, $where);
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3);    # 3 -- see DBI docs
	$self->dbh->debug_stmt($sth, @bind_vals);
	my $result = $sth->execute(@bind_vals);
	$sth->finish;

	return $result;
}

################################################################################
# lowlevel update-fields
################################################################################

# rather than allowing an unrestrained where clause here, we generate one based
# on the value of the keyfields in each row. in this respect, the behavior is
# more like "REPLACE INTO", except that a record with matching keys must already
# exist.

# returns the number of rows affected by updating each row
sub update_fields {
	my ($self, $fields, $rows) = @_;

	my ($sth, $val_order, $where_order) = $self->_update_fields_prep($fields);
	my @results;
	foreach my $row (@$rows) {
		my @bind_vals = @$row[ @$val_order, @$where_order ];
		$self->dbh->debug_stmt($sth, @bind_vals);
		push @results, $sth->execute(@bind_vals);
	}
	$sth->finish;
	return @results;
}

# returns the number of rows affected by updating each row
sub update_fields_i {
	my ($self, $fields, $rows_i) = @_;

	my ($sth, $val_order, $where_order) = $self->_update_fields_prep($fields);
	my @results;
	until ($rows_i->is_exhausted) {
		my @bind_vals = @{ $rows_i->value }[ @$val_order, @$where_order ];
		$self->dbh->debug_stmt($sth, @bind_vals);
		push @results, $sth->execute(@bind_vals);
	}
	$sth->finish;
	return @results;
}

# helper, returns a prepared statement handle
sub _update_fields_prep {
	my ($self, $fields) = @_;

	# get hashes to pass to update() and where()
	# (dies if any keyfield is missing from @$fields)
	my ($values, $where) = $self->gen_update_hashes($fields);

	# do the where clause separately so we get a separate bind list (cute substr trick, huh?)
	my ($stmt, @val_order) = $self->sql->update($self->table, $values);
	(substr($stmt, length($stmt), 0), my @where_order) = $self->sql->where($where);

	my $sth = $self->dbh->prepare_cached($stmt, undef, 3);    # 3: see DBI docs
	return $sth, \@val_order, \@where_order;
}

################################################################################
# updating records
################################################################################

# returns the number of rows affected by updating each record
sub update_records {
	my ($self, $Records) = @_;
	return $self->update_fields_i([ $self->fields ], imap { $self->unbox($_) } iarray $Records);
}

# returns the number of rows affected by updating each record
sub update_records_i {
	my ($self, $Records_i) = @_;
	return $self->update_fields_i([ $self->fields ], imap { $self->unbox($_) } $Records_i);
}

################################################################################
# lowlevel delete-where
################################################################################

# execute a single DELETE by passing a ref to a hash specifying a where clause

# returns number of rows affected by delete
sub delete_where {
	my ($self, $where) = @_;
	$where = $self->conv_where($where);

	my ($stmt, @bind_vals) = $self->sql->delete($self->table, $where);
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3);    # 3 -- see DBI docs
	$self->dbh->debug_stmt($sth, @bind_vals);
	my $result = $sth->execute(@bind_vals);
	$sth->finish;

	return $result;
}

################################################################################
# lowlevel delete-fields
################################################################################

# rather than allowing an unrestrained where clause here, we generate one based
# on the value of the keyfields in each row. this allows us to delete a bunch
# of records with a single statement handle, if what we have is a big list of
# record IDs (i.e. keyfields)

# an alternate approach would be to generate one big WHERE clause by ORing
# together the ANDed keyfields for each record to delete. This has the potential
# to accumulate a huge stmt string, but it's just one execute.

# this doesn't support NULL in keyfields, because the WHERE clause is
# constructed differently for NULL and non-NULL values. use delete_where.

# returns the number of rows affected by deleting each row
sub delete_fields {
	my ($self, $fields, $rows) = @_;

	my ($sth, @order) = $self->_delete_fields_prep($fields);
	my @results;
	foreach my $row (@$rows) {
		my @bind_vals = @$row[@order];
		$self->dbh->debug_stmt($sth, @bind_vals);
		push @results, $sth->execute(@bind_vals);
	}
	$sth->finish;
	return @results;
}

# returns the number of rows affected by deleting each row
sub delete_fields_i {
	my ($self, $fields, $rows_i) = @_;

	my ($sth, @order) = $self->_delete_fields_prep($fields);

	my @results;
	until ($rows_i->is_exhausted) {
		my @bind_vals = @{ $rows_i->value }[@order];
		$self->dbh->debug_stmt($sth, @bind_vals);
		push @results, $sth->execute(@bind_vals);
	}
	$sth->finish;
	return @results;
}

# helper, returns a prepared statement handle
sub _delete_fields_prep {
	my ($self, $fields) = @_;

	# get hashes to pass to update() and where()
	# (dies if any keyfield is missing from @$fields)
	my (undef, $where) = $self->gen_update_hashes($fields);

	# do the where clause separately so we get a separate bind list (cute substr trick, huh?)
	my ($stmt, @order) = $self->sql->delete($self->table, $where);

	my $sth = $self->dbh->prepare_cached($stmt, undef, 3);    # 3: see DBI docs
	return $sth, @order;
}

################################################################################
# deleting records
################################################################################

# we can pass whole records in here, even though all that's needed to delete is
# the keyfields. will be unboxed, and then _delete_fields_prep will ignore the
# non-keyfields when generating the WHERE clause template.

# returns the number of rows affected by deleting each record
sub delete_records {
	my ($self, $Records) = @_;
	return $self->delete_fields_i([ $self->fields ], imap { $self->unbox($_) } iarray $Records);
}

# returns the number of rows affected by deleting each record
sub delete_records_i {
	my ($self, $Records_i) = @_;
	return $self->delete_fields_i([ $self->fields ], imap { $self->unbox($_) } $Records_i);
}

################################################################################
# compatibility methods for old API
################################################################################

# oldapi
sub count {
	my ($self, @keyparts) = @_;
	return $self->count_where($self->keyparts_to_where(@keyparts));
}

# oldapi
sub list {
	my ($self, @keyparts) = @_;
	return $self->list_where($self->keyparts_to_where(@keyparts));
}

# oldapi
sub exists {
	my ($self, @keyparts) = @_;
	return $self->exists_where($self->keyparts_to_where(@keyparts));
}

# oldapi
sub get {
	my ($self, @keyparts) = @_;
	return ($self->get_records_where($self->keyparts_to_where(@keyparts)))[0];
}

# oldapi
sub gets {
	my ($self, @keypartsRefList) = @_;
	return map { $self->get_records_where($self->keyparts_to_where(@$_)) } @keypartsRefList;
}

# oldapi
sub add {
	my ($self, $Record) = @_;
	return ($self->insert_records([$Record]))[0];
}

# oldapi
sub put {
	my ($self, $Record) = @_;
	return ($self->update_records([$Record]))[0];
}

# oldapi
sub delete {
	my ($self, @keyparts) = @_;
	return $self->delete_where($self->keyparts_to_where(@keyparts));
}

################################################################################
# utility methods
################################################################################

sub sql {
	return shift->{sql};
}

# returns non-quoted SQL name of current table
sub sql_table_name {
	my ($self) = @_;
	return defined $self->{params}{tableOverride} ? $self->{params}{tableOverride} : $self->table;
}

sub engine {
	my ($self) = @_;
	return $self->dbh->engine;
}

sub character_set {
	my $self = shift;
	return $self->dbh->character_set;
}

# returns non-quoted SQL name of given field
sub sql_field_name {
	my ($self, $field) = @_;
	return $field;
}

# returns fully quoted expression refering to the specified field
# if $include_table is true, the field name is prefixed with the table name
sub sql_field_expression {
	my ($self, $field, $table) = @_;

	# _quote will do native-to-SQL table/field name translation
	if (defined $table) {
		return $self->sql->_quote("$table.$field");
	} else {
		return $self->sql->_quote($field);
	}
}

sub DESTROY { }

1;
