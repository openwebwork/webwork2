################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/CourseManagement/sql_single.pm,v 1.9 2006/01/26 21:45:42 sh002i Exp $
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
use Data::Dumper;
use DBI;
use WeBWorK::Debug;
use WeBWorK::Utils qw(runtime_use undefstr);
use WeBWorK::Utils::CourseManagement qw/dbLayoutSQLSources/;

=head1 HELPER FUNCTIONS

=over

=item addCourseHelper($courseID, $ce, $dbLayoutName, %options)

Creates the course database for an SQL course. Return value is boolean,
indicates success or failure.

=cut

sub addCourseHelper {
	my ($courseID, $ce, $dbLayoutName, %options) = @_;
	
	##### parse dbLayout to generate sql statements #####
	
	my (%sources, %usernames, %passwords);
	
	debug("dbLayoutName=$dbLayoutName");
	
	my %dbLayout = %{ $ce->{dbLayouts}->{$dbLayoutName} };
	
	my @tables = keys %dbLayout;
	debug("layout defines the following tables: @tables");
	
	foreach my $table (@tables) {
		my %table = %{ $dbLayout{$table} };
		my %params = %{ $table{params} };
		
		if ($params{non_native}) {
			debug("$table: marked non-native, skipping\n");
			next;
		}
		
		my $source = $table{source};
		debug("$table: DBI source is $source\n");
		
		my $tableOverride = $params{tableOverride};
		debug("$table: SQL table name is ", undefstr("not defined", $tableOverride), "\n");
		
		my $recordClass = $table{record};
		debug("$table: record class is $recordClass\n");
		
		runtime_use($recordClass);
		my @fields = $recordClass->FIELDS;
		debug("$table: WeBWorK field names: @fields\n");
		my @keyfields = $recordClass->KEYFIELDS;
		debug("$table: WeBWorK keyfield names: @keyfields\n");
		my @fieldtypes = $recordClass->SQL_TYPES;
		debug("$table: WeBWorK field types: @fieldtypes\n");
		
		if (exists $params{fieldOverride}) {
			my %fieldOverride = %{ $params{fieldOverride} };
			foreach my $field (@fields) {
				$field = $fieldOverride{$field} if exists $fieldOverride{$field};
			}
			debug("$table: SQL field names: @fields\n");
		}
		
		my %fieldtypehash =();
		for my $cnt (0..(scalar(@fields)-1)) {
			$fieldtypehash{$fields[$cnt]} = $fieldtypes[$cnt];
		}
		# generate table creation statement
		
		my @fieldList;
		# special handling of psvn's is now taken care of by
		# its entry in %fieldtypehash, which comes from SQL_TYPES
		foreach my $field (@fields) {
			push @fieldList, "`$field` $fieldtypehash{$field}";
		}
		foreach my $start (0 .. $#keyfields) {
			my $line = "INDEX ( ";
			# we only need to limit the length of the value for
			# types text and blob, but can't do it for int.
			$line .= join(", ", map { "`$_`". (($fieldtypehash{$_} =~ /int/i) ? "" : "(16)") } @keyfields[$start .. $#keyfields]);
			$line .= " )";
			push @fieldList, $line;
		}
		my $fieldString = join(", ", @fieldList);
		
		my $tableName = $tableOverride || $table;
		my $createStmt = "CREATE TABLE `$tableName` ( $fieldString );";

		debug("$table: CREATE statement is: $createStmt\n");
		
		# add to source hash
		
		if (exists $sources{$source}) {
			push @{ $sources{$source} }, $createStmt;
		} else {
			$sources{$source} = [ $createStmt ];
		}
		
		# add username and password to hashes
		
		$usernames{$source} = $params{usernameRW};
		$passwords{$source} = $params{passwordRW};
		
		#warn "\n";
	}
	
	##### handle multiple sources #####
	
	# if more than one source is listed, we only want to create the tables that
	# have the most popular source
	
	my $source;
	if (keys %sources > 1) {
		# more than one -- warn and select the most popular source
 		debug("database layout $dbLayoutName defines more than one SQL source.\n");
		foreach my $curr (keys %sources) {
			$source = $curr if not defined $source or @{ $sources{$curr} } > @{ $sources{$source} };
 		}
 		debug("only creating tables with source \"$source\".\n");
 		debug("others will have to be created manually.\n");
 	} else {
		# there's only one
		($source) = keys %sources;
	}
	
	my $username = $usernames{$source};
	my $password = $passwords{$source};
	
	my @stmts = @{ $sources{$source} };
	
	##### issue SQL statements #####
	
	my $dbh = DBI->connect($source, $username, $password);
	unless (defined $dbh) {
		die "sql_single: failed to connect to DBI source '$source': $DBI::errstr\n";
	}
	
	foreach my $stmt (@stmts) {
		my $rows = $dbh->do($stmt);
		unless (defined $rows) {
			die "sql_single: failed to execute SQL statement '$stmt': $DBI::errstr\n";
		}
	}
	
	$dbh->disconnect;
	
	return 1;
}

=item copyCourseHelper($fromCourseID, $fromCE, $toCourseID, $toCE, $dbLayoutName, %options)

Uses addCourseHelper() to create a new course database on the same server.
Copies the data from the old course database to the new one. Uses
deleteCourseHelper() to delete the old course database.

=cut

sub copyCourseDataHelper {
	my ($fromCourseID, $fromCE, $toCourseID, $toCE, $dbLayoutName, %options) = @_;
	debug("fromCourseID=$fromCourseID, fromCE=$fromCE toCourseID=$toCourseID toCE=$toCE dbLayoutName=$dbLayoutName\n");
	
	##### get list of tables to copy data FROM #####
	
	my $fromDBLayout = $fromCE->{dbLayouts}->{$dbLayoutName};
	debug("fromDBLayout=$fromDBLayout\n");
	my %fromSources = dbLayoutSQLSources($fromDBLayout);
	debug("fromSources: ", Dumper(\%fromSources));
	my $fromSource = mostPopularSource(%fromSources);
	debug("fromSource=$fromSource\n");
	my %fromSource = %{ $fromSources{$fromSource} };
	my @fromTables = @{ $fromSource{tables} };
	my $fromUsername = $fromSource{username};
	my $fromPassword = $fromSource{password};
	
	##### get list of tables to copy data TO #####
	
	my $toDBLayout = $toCE->{dbLayouts}->{$dbLayoutName};
	my %toSources = dbLayoutSQLSources($toDBLayout);
	my $toSource = mostPopularSource(%toSources);
	my %toSource = %{ $toSources{$toSource} };
	my @toTables = @{ $toSource{tables} };
	my $toUsername = $toSource{username};
	my $toPassword = $toSource{password};
	
	##### make sure the same tables are present in each list #####
	
	my %fromTables; @fromTables{@fromTables} = ();
	
	foreach my $toTable (@toTables) {
		if (exists $fromTables{$toTable}) {
			# present in both
			delete $fromTables{$toTable};
		} else {
			die "Table '$toTable' exists in \@toTables but not in \@fromTables. Can't continue";
		}
	}
	
	if (keys %fromTables) {
		my @leftovers = keys %fromTables;
		die "Tables '@leftovers' exist in \@fromTables but not in \@toTables. Can't continue";
	}
	
	if ($fromUsername ne $toUsername) {
		die "Usernames for from/to sources don't match. Can't continue";
	}
	
	if ($fromPassword ne $toPassword) {
		die "Passwords for from/to sources don't match. Can't continue";
	}
	
	##### consruct SQL statements to copy the data in each table #####
	
	my @stmts;
	
	foreach my $table (@fromTables) {
		debug("Table: $table\n");
		my $fromTable = do {
			my $fromParamsRef = $fromDBLayout->{$table}->{params};
			if ($fromParamsRef) {
				if (exists $fromParamsRef->{tableOverride}) {
					$fromParamsRef->{tableOverride}
				} else {
					""; # no override
				}
			} else {
				""; # no params
			}
		} || $table;
		debug("sql \"from\" table name: $fromTable\n");
		
		my $toTable = do {
			my $toParamsRef = $toDBLayout->{$table}->{params};
			if ($toParamsRef) {
				if (exists $toParamsRef->{tableOverride}) {
					$toParamsRef->{tableOverride};
				} else {
					""; # no override
				}
			} else {
				""; # no params
			}
		} || $table;
		debug("sql \"to\" table name: $toTable\n");
		
		my $stmt = "INSERT INTO `$toTable` SELECT * FROM `$fromTable`";
		debug("stmt = $stmt\n");
		push @stmts, $stmt;
	}
	
	##### issue SQL statements #####
	
	my $dbh = DBI->connect($fromSource, $fromUsername, $fromPassword);
	unless (defined $dbh) {
		die "sql_single: failed to connect to DBI source '$fromSource': $DBI::errstr\n";
	}
	
	foreach my $stmt (@stmts) {
		my $rows = $dbh->do($stmt);
		unless (defined $rows) {
			die "sql_single: failed to execute SQL statement '$stmt': $DBI::errstr\n";
		}
	}
	
	$dbh->disconnect;
	
	return 1;
}

=item archiveCourseHelper($fromCourseID, $fromCE, $toCourseID, $toCE, $dbLayoutName, %options)

Dumps the data from the  course database to text files in the courseID/DATA directory. Uses
deleteCourseHelper() to delete the old course database.

=cut

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
	my $exportStatement = " mysqldump  --user=$username  ".
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

=item deleteCourseHelper($courseID, $ce, $dbLayoutName, %options)

Deletes the course database for an SQL course. Return value is boolean,
indicates success or failure.

=cut

sub deleteCourseHelper {
	my ($courseID, $ce, $dbLayoutName, %options) = @_;
	
	##### parse dbLayout to generate sql statements #####
	
	my (%sources, %usernames, %passwords);
	
	debug("dbLayoutName=$dbLayoutName");
	
	my %dbLayout = %{ $ce->{dbLayouts}->{$dbLayoutName} };
	
	my @tables = keys %dbLayout;
	debug("layout defines the following tables: @tables");
	
	foreach my $table (@tables) {
		my %table = %{ $dbLayout{$table} };
		my %params = %{ $table{params} };
		
		if ($params{non_native}) {
			debug("$table: marked non-native, skipping\n");
			next;
		}
		
		my $source = $table{source};
		debug("$table: DBI source is $source\n");
		
		my $tableOverride = $params{tableOverride};
		debug("$table: SQL table name is ", undefstr("not defined", $tableOverride), "\n");
		
		my $recordClass = $table{record};
		debug("$table: record class is $recordClass\n");
		
		runtime_use($recordClass);
		my @fields = $recordClass->FIELDS;
		debug("$table: WeBWorK field names: @fields\n");
		
		if (exists $params{fieldOverride}) {
			my %fieldOverride = %{ $params{fieldOverride} };
			foreach my $field (@fields) {
				$field = $fieldOverride{$field} if exists $fieldOverride{$field};
			}
			debug("$table: SQL field names: @fields\n");
		}
		
		# generate table drop statement
		
		my $tableName = $tableOverride || $table;
		my $createStmt = "DROP TABLE `$tableName`;";

		debug("$table: DROP statement is: $createStmt\n");
		
		# add to source hash
		
		if (exists $sources{$source}) {
			push @{ $sources{$source} }, $createStmt;
		} else {
			$sources{$source} = [ $createStmt ];
		}
		
		# add username and password to hashes
		
		$usernames{$source} = $params{usernameRW};
		$passwords{$source} = $params{passwordRW};
		
		#warn "\n";
	}
	
	##### handle multiple sources #####
	
	# if more than one source is listed, we only want to drop the tables that
	# have the most popular source
	
	my $source;
	if (keys %sources > 1) {
		# more than one -- warn and select the most popular source
 		debug("database layout $dbLayoutName defines more than one SQL source.\n");
		foreach my $curr (keys %sources) {
			$source = $curr if not defined $source or @{ $sources{$curr} } > @{ $sources{$source} };
 		}
 		debug("only creating tables with source \"$source\".\n");
 		debug("others will have to be created manually.\n");
 	} else {
		# there's only one
		($source) = keys %sources;
	}
	
	my $username = $usernames{$source};
	my $password = $passwords{$source};
	
	my @stmts = @{ $sources{$source} };
	
	##### issue SQL statements #####
	
	my $dbh = DBI->connect($source, $username, $password, { PrintError => 0 });
	unless (defined $dbh) {
		warn "sql_single: failed to connect to DBI source '$source': $DBI::errstr\n";
	}
	
	foreach my $stmt (@stmts) {
		my $rows = $dbh->do($stmt);
		unless (defined $rows) {
			warn "sql_single: failed to execute SQL statement '$stmt': $DBI::errstr\n";
		}
	}
	
	$dbh->disconnect;
	
	return 1;
}

=back

=cut

1;
