################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/CourseManagement/sql_single.pm,v 1.16 2007/07/21 19:13:10 sh002i Exp $
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

package WeBWorK::Utils::CourseManagement::sql_single;

=head1 NAME

WeBWorK::Utils::CourseManagement::sql_single - create and delete courses using
the sql_single database layout.

=cut

use strict;
use warnings;
#use Data::Dumper;
#use DBI;
use File::Temp;
use String::ShellQuote;
use WeBWorK::Debug;
use WeBWorK::Utils qw/runtime_use/;
#use WeBWorK::Utils::CourseManagement qw/dbLayoutSQLSources/;

=for comment

# DBFIXME this whole process should be through an abstraction layer
# DBFIXME (we shouldn't be calling mysqldump here
sub archiveCourseHelper {
	my ($courseID, $ce,  $dbLayoutName, %options) = @_;
	debug("courseID=$courseID, ce=$ce dbLayoutName=$dbLayoutName\n");
	
	##### get list of tables to archive #####
	
	my $dbLayout    = $ce->{dbLayouts}->{$dbLayoutName};
	debug("dbLayout=$dbLayout\n");
	my %sources     = dbLayoutSQLSources($dbLayout);
	debug("fSources: ", Dumper(\%sources));
	my $source    = mostPopularSource(%sources);
	debug("source=$source\n");
	my %source = %{ $sources{$source} };
	my @tables = @{ $source{tables} };
	my $username = $source{username};
	my $password = $source{password};
	my $archiveDatabasePath = $options{archiveDatabasePath};
	
	##### construct SQL statements to copy the data in each table #####
	
	my @stmts;
	my @dataTables = ();
	foreach my $table (@tables) {
		debug("Table: $table\n");
		
		if ($dbLayout->{$table}{params}{non_native}) {
			debug("$table: marked non-native, skipping\n");
			next;
		}
		
		my $table = do {
			my $paramsRef = $dbLayout->{$table}->{params};
			if ($paramsRef) {
				if (exists $paramsRef->{tableOverride}) {
					$paramsRef->{tableOverride}
				} else {
					""; # no override
				}
			} else {
				""; # no params
			}
		} || $table;
		debug("sql \"real\" table name: $table\n");
		
       
        # this method would be mysql specific but it's a start
		# mysqldump  --user=$username   --password=$password database   tables
#		my $stmt = "DUMP SELECT * FROM `$fromTable`";
#		debug("stmt = $stmt\n");
#		push @stmts, $stmt;
	    push @dataTables, $table;
	}
	debug("Database tables to export are ",join(" ", @dataTables));
	# this method would be mysql specific but it's a start
	my $mysqldumpCommand = $ce->{externalPrograms}{mysqldump};
	my $exportStatement = " $mysqldumpCommand  --user=$username  ".
	"--password=$password " .
	" webwork   ".
	join(" ", @dataTables).
	"   >$archiveDatabasePath";
	debug($exportStatement);
	my $exportResult = system $exportStatement;
	$exportResult and die "Failed to export database with command: '$exportStatement ' (errno: $exportResult): $!
	\n\n Check server error log for more information.";

	##### issue SQL statements #####
	
# 	my $dbh = DBI->connect($source, $username, $password);
# 	unless (defined $dbh) {
# 		die "sql_single: failed to connect to DBI source '$source': $DBI::errstr\n";
# 	}
# 	
# 	foreach my $stmt (@stmts) {
# 		my $rows = $dbh->do($stmt);
# 		unless (defined $rows) {
# 			die "sql_single: failed to execute SQL statement '$stmt': $DBI::errstr\n";
# 		}
# 	}
# 	
# 	$dbh->disconnect;
	
	return 1;
}

=cut

=for comment

# DBFIXME this whole process should be through an abstraction layer
# DBFIXME (we shouldn't be calling mysqldump here!)
sub unarchiveCourseHelper {
	my ($courseID, $ce,  $dbLayoutName, %options) = @_;
	debug("courseID=$courseID, ce=$ce dbLayoutName=$dbLayoutName\n");
	
	##### get list of tables to archive #####
	
	my $dbLayout    = $ce->{dbLayouts}->{$dbLayoutName};
	debug("dbLayout=$dbLayout\n");
	my %sources     = dbLayoutSQLSources($dbLayout);
	debug("fSources: ", Dumper(\%sources));
	my $source    = mostPopularSource(%sources);
	debug("source=$source\n");
	my %source = %{ $sources{$source} };
	my @tables = @{ $source{tables} };
	my $username = $source{username};
	my $password = $source{password};
	my $unarchiveDatabasePath = $options{unarchiveDatabasePath};
	debug( "unarchive database Path is $unarchiveDatabasePath");
	##### construct SQL statements to copy the data in each table #####
	

	# this method would be mysql specific but it's a start
	my $mysqlCommand = $ce->{externalPrograms}{mysql};
	my $importStatement = " $mysqlCommand  --user=$username  ".
	"--password=$password " .
	"-D webwork".        # specifies database name
	"   <$unarchiveDatabasePath";
	debug($importStatement);
	my $importResult = system $importStatement;
	$importResult and die "<pre>Failed to import database with command: \n
	'$importStatement ' \n
	(errno: $importResult): $!
	\n Check server error log for more information.\n</pre>";
	#FIXME  -- what should the return be??
	return 1;
}

=cut

# TOTALLY STOLEN FROM NewSQL::Std.
sub unarchiveCourseHelper {
	my ($courseID, $ce,  $dbLayoutName, %options) = @_;
	my $dumpfile_path = $options{unarchiveDatabasePath};
	
	my ($my_cnf, $database) = _get_db_info($ce);
	my $mysql = $ce->{externalPrograms}{mysql};
	
	my $restore_cmd = "2>&1 " . shell_quote($mysql)
		. " --defaults-extra-file=" . shell_quote($my_cnf->filename)
		. " " . shell_quote($database)
		. " < " . shell_quote($dumpfile_path);
	my $restore_out = readpipe $restore_cmd;
	if ($?) {
		my $exit = $? >> 8;
		my $signal = $? & 127;
		my $core = $? & 128;
		die "Failed to restore database for course '$courseID' with command '$restore_cmd' (exit=$exit signal=$signal core=$core): $restore_out\n";
	}
	
	return 1;
}

# TOTALLY STOLEN FROM NewSQL::Std.
sub _get_db_info {
	my ($ce) = @_;
	my $dsn = $ce->{database_dsn};
	my $username = $ce->{database_username};
	my $password = $ce->{database_password};

	my %dsn;
	if ($dsn =~ m/^dbi:mariadb:/i || $dsn =~ m/^dbi:mysql:/i) {
		# Expect DBI:MariaDB:database=webwork;host=db;port=3306
		# or DBI:mysql:database=webwork;host=db;port=3306
		# The host and port are optional.
		my ($dbi, $dbtype, $dsn_opts) = split(':', $dsn);
		while (length($dsn_opts)) {
			if ($dsn_opts =~ /^([^=]*)=([^;]*);(.*)$/) {
				$dsn{$1} = $2;
				$dsn_opts = $3;
			} else {
				my ($var, $val) = $dsn_opts =~ /^([^=]*)=([^;]*)$/;
				$dsn{$var} = $val;
				$dsn_opts = '';
			}
		}
	} else {
		die "Can't call dump_table or restore_table on a table with a non-MySQL/MariaDB source";
	}
	
	die "no database specified in DSN!" unless defined $dsn{database};

	my $mysqldump = $self->{params}{mysqldump_path};
	# Conditionally add column-statistics=0 as MariaDB databases do not support it
	# see: https://serverfault.com/questions/912162/mysqldump-throws-unknown-table-column-statistics-in-information-schema-1109
	#      https://github.com/drush-ops/drush/issues/4410

	my $column_statistics_off = "";
	my $test_for_column_statistics = `$mysqldump_command --help | grep 'column-statistics'`;
	if ( $test_for_column_statistics ) {
		$column_statistics_off = "[mysqldump]\ncolumn-statistics=0\n";
		#warn "Setting in the temporary mysql config file for table dump/restore:\n$column_statistics_off\n\n";
	}

	# doing this securely is kind of a hassle...
	my $my_cnf = new File::Temp;
	$my_cnf->unlink_on_destroy(1);
	chmod 0600, $my_cnf or die "failed to chmod 0600 $my_cnf: $!"; # File::Temp objects stringify with ->filename
	print $my_cnf "[client]\n";
	print $my_cnf "user=$username\n" if defined $username and length($username) > 0;
	print $my_cnf "password=$password\n" if defined $password and length($password) > 0;
	print $my_cnf "host=$dsn{host}\n" if defined $dsn{host} and length($dsn{host}) > 0;
	print $my_cnf "port=$dsn{port}\n" if defined $dsn{port} and length($dsn{port}) > 0;
	print $my_cnf "$column_statistics_off" if $test_for_column_statistics;

	return ($my_cnf, $dsn{database});
}

=for comment

# returns the name of the source with the most tables
sub mostPopularSource {
	my (%sources) = @_;
	
	my $source;
	if (keys %sources > 1) {
		# more than one -- warn and select the most popular source
 		debug("more than one SQL source defined.\n");
		foreach my $curr (keys %sources) {
			$source = $curr if not defined $source or @{ $sources{$curr}->{tables} } > @{ $sources{$source}->{tables} };
 		}
 		debug("only handling tables with source \"$source\".\n");
 		debug("others will have to be handled manually (or not at all).\n");
 	} else {
		# there's only one
		($source) = keys %sources;
	}
	
	return $source;
}

=cut

1;

