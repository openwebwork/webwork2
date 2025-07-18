################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::DB::Database;
use Mojo::Base -signatures;

=head1 NAME

WeBWorK::DB::Database - DBI interface to SQL databases.

=head1 CONSTRUCTOR

    my $dbh = WeBWorK::DB::Database->new($source, $username, $password, %params);

Creates a DBI database connection.  The C<$source> parameter should be a DBI
data source, i.e., a DSN.  The C<$username> and C<$password> parameters are the
username and password required to access the database.  The additional options
passed via C<%params> may contain the database C<engine> and C<character_set>
that will be used for all tables. If the database C<engine> is not provided,
then the default value of "MYISAM" will be used.  If the C<character_set> is not
provided, then the default value of "latin1" will be used.  If this database
handle will be used for archiving or unarchiving courses then the additional
options passed via C<%params> must also contain C<mysql_path> and
C<mysqldump_path>.  In addition C<< debug => 1 >> may be set in C<%params> for
development debugging purposes.

=cut

use DBI;

use WeBWorK::Utils qw(undefstr);

# Map error numbers to exception classes for MySQL.
our %MYSQL_ERROR_CODES = (
	1062 => 'WeBWorK::DB::Ex::RecordExists',
	1146 => 'WeBWorK::DB::Ex::TableMissing',
);

sub new ($proto, $source, $username, $password, %params) {
	my $self = bless { source => $source, params => { username => $username, password => $password, %params } },
		ref($proto) || $proto;

	# Add dbi handle.
	$self->{dbh} = DBI->connect_cached(
		$source,
		$username,
		$password,
		{
			PrintError => 0,
			RaiseError => 1,
			# Only the DBD::mysql driver should get the mysql_enable_utf8mb4 and mysql_enable_utf8 settings.
			$source =~ /DBI:mysql/ ? (mysql_enable_utf8mb4 => 1, mysql_enable_utf8 => 1) : ()
		}
	);
	die $DBI::errstr unless defined $self->{dbh};

	# Provide a custom error handler.
	$self->{dbh}{HandleError} = \&handle_error;

	# Set trace level from debug param.
	#$self->{dbh}->trace($params{debug}) if $params{debug};

	return $self;
}

# Provide access to the raw DBI handle.  This really shouldn't be used outside this file though.
# Instead use the wrapper methods provided below.
sub dbh ($self) {
	return $self->{dbh};
}

# The engine used for all tables.
sub engine ($self) {
	return $self->{params}{engine} // 'MYISAM';
}

# The character set used for all tables.
sub character_set ($self) {
	return $self->{params}{character_set} // 'latin1';
}

# DBI wrapper methods. (All currently used methods are implemented.  Add more as needed.)

sub do ($self, $statement, $attr = undef, @bind_values) {
	return $self->dbh->do($statement, $attr, @bind_values);
}

sub selectall_arrayref ($self, $statement, $attr = undef, @bind_values) {
	return $self->dbh->selectall_arrayref($statement, $attr, @bind_values);
}

sub prepare_cached ($self, $statement, $attr = undef, $if_active = 0) {
	return $self->dbh->prepare_cached($statement, $attr, $if_active);
}

sub begin_work ($self) { $self->dbh->begin_work; return; }
sub commit     ($self) { $self->dbh->commit;     return; }
sub rollback   ($self) { $self->dbh->{AutoCommit} = 0; $self->dbh->rollback; return; }

# Debugging methods.
sub debug_stmt ($self, $sth, @bind_vals) {
	return unless $self->{params}{debug};
	my ($subroutine) = (caller(1))[3];
	print STDERR "$subroutine: " . $self->bind_values($sth->{Statement}, undefstr("#UNDEF#", @bind_vals)) . "\n";
	return;
}

sub bind_values ($self, $stmt, @bind_vals) {
	$stmt =~ s/\?/@bind_vals ? "?[".$self->dbh->quote(shift @bind_vals)."]" : "### NO BIND VALS ###"/eg;
	$stmt .= " ### EXTRA BIND VALS |@bind_vals| ###" if @bind_vals;
	return $stmt;
}

# Turn MySQL error codes into exceptions (WeBWorK::DB::Schema::Ex objects for known error types),
# and normal die exceptions for unknown errors.
sub handle_error ($errmsg, $handle, $returned) {
	if (exists $MYSQL_ERROR_CODES{ $handle->err }) {
		$MYSQL_ERROR_CODES{ $handle->err }->throw(error => $errmsg);
	} else {
		if ($errmsg =~ /Unknown column/) {
			warn 'It looks like the database is missing a column. You may need to upgrade your course tables. '
				. 'If this is the admin course then you will need to upgrade the '
				. 'admin tables using the upgrade_admin_db.pl script.';
		}
		die $errmsg;
	}

	return;
}

1;
