################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/CourseManagement/sql_single.pm,v 1.1 2004/08/10 23:57:24 sh002i Exp $
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
use DBI;
use WeBWorK::Debug;
use WeBWorK::Utils qw(runtime_use undefstr);

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
		
		# generate table creation statement
		
		my $tableName = $tableOverride || $table;
		my @fieldList;
		foreach my $field (@fields) {
			# a stupid hack to make PSVNs numeric and auto-increment
			if ($field eq "psvn") {
				push @fieldList, "`$field` INT NOT NULL PRIMARY KEY AUTO_INCREMENT";
			} else {
				push @fieldList, "`$field` TEXT";
			}
		}
		my $fieldString = join(", ", @fieldList);
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
}

=back

=cut

1;
