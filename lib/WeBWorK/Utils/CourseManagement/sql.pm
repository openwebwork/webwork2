################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/CourseManagement.pm,v 1.17 2004/06/24 17:44:16 sh002i Exp $
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

package WeBWorK::Utils::CourseManagement::sql;

=head1 NAME

WeBWorK::Utils::CourseManagement::sql - create and delete courses using the sql
database layout.

=cut

use strict;
use warnings;
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
	
	my %sources;
	
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
		
		# generate GRANT statements
		
		my $grantStmtRO = "GRANT SELECT"
				. " ON `$options{database}`.`$tableName`"
				. " TO $params{usernameRO}\@$options{wwhost}"
				. " IDENTIFIED BY '$params{passwordRO}';";
		my $grantStmtRW = "GRANT SELECT, INSERT, UPDATE, DELETE"
				. " ON `$options{database}`.`$tableName`"
				. " TO $params{usernameRW}\@$options{wwhost}"
				. " IDENTIFIED BY '$params{passwordRW}';";
		
		debug("$table: GRANT RO statement is: $grantStmtRO\n");
		debug("$table: GRANT RW statement is: $grantStmtRW\n");
		
		# add to source hash
		
		if (exists $sources{$source}) {
			push @{ $sources{$source} }, $createStmt, $grantStmtRO, $grantStmtRW;
		} else {
			$sources{$source} = [ $createStmt, $grantStmtRO, $grantStmtRW ];
		}
		
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
	my @stmts = (
		"CREATE DATABASE `$options{database}`;",
		"USE $options{database};", # oddly, backquotes prohibited with USE statement...
		@{ $sources{$source} }
	);
	
	##### issue SQL statements #####
	
	my ($driver) = $source =~ m/^dbi:(\w+):/i;
	return execSQLStatements($driver, $ce->{externalPrograms}, \%options, @stmts)
}

=item deleteCourseHelper($courseID, $ce, $dbLayoutName, %options)

Deletes the course database for an SQL course. Return value is boolean,
indicates success or failure.

=cut

sub deleteCourseHelper {
	my ($courseID, $ce, $dbLayoutName, %options) = @_;
	
	# get the most popular DBI source, so we know what driver to use
	my $dbi_source = do {
		my %sources;
		foreach my $table (keys %{ $ce->{dbLayouts}->{$dbLayoutName} }) {
			$sources{$ce->{dbLayouts}->{$dbLayoutName}->{$table}->{source}}++;
		}
		my $source;
		if (keys %sources > 1) {
			foreach my $curr (keys %sources) {
				$source = $curr if @{ $sources{$curr} } > @{ $sources{$source} };
			}
		} else {
			($source) = keys %sources;
		}
		$source;
	};
	
	my $stmt = "DROP DATABASE `$options{database}`;";
	
	my ($driver) = $dbi_source =~ m/^dbi:(\w+):/i;
	return execSQLStatements($driver, $ce->{externalPrograms}, \%options, $stmt);
}

=back

=cut

################################################################################

=head1 UTILITIES

These functions are used by the methods and should not be called directly.

=over

=item execSQLStatements($driver, $externalPrograms, $dbOptions, @statements)

Execute the listed SQL statements. The appropriate SQL console is determined
using $driver and invoked with the options listed in $dbOptions.

$options is a reference to a hash containing the pairs accepted in %dbOptions by
addCourse(), above.

Returns true on success, false on failure.

=cut

sub execSQLStatements {
	my ($driver, $externalPrograms, $dbOptions, @statements) = @_;
	my %options = %$dbOptions;
	
	my $exit_status;
	
	if (lc $driver eq "mysql") {
		my @commandLine = ( $externalPrograms->{mysql} );
		push @commandLine, "--host=$options{host}" if exists $options{host};
		push @commandLine, "--port=$options{port}" if exists $options{port};
		push @commandLine, "--user=$options{username}" if exists $options{username};
		push @commandLine, "--password=$options{password}" if exists $options{password};
		
		open my $mysql, "|@commandLine"
				or die "sql: failed to execute \"@commandLine\": $!\n";
		
		# exec sql statements
		foreach my $stmt (@statements) {
			debug("exec: $stmt");
			print $mysql "$stmt\n";
		}
		
		close $mysql;
		$exit_status = $?;
	}
	
	# add code to deal with other RDBMSs here:
	# 
	#elsif (lc $driver eq "foobar") {
	#	# do something else
	#}
	
	else {
		die "sql: driver \"$driver\" is not supported.\n";
	}
	
	# "...the exit value of the subprocess is in the high byte, that is, $? >>
	# 8; in the low byte, $? & 127 says which signal (if any) the process died
	# from, while $? & 128 reports whether its demise produced a core dump."
	#     -- Camel, 3rd ed
	my $status = $exit_status >> 8;
	#my $signal = $exit_status & 127;
	#my $core = $exit_status & 128
	
	# we want to return true for success and false for failure
	debug("SQL console returned exit status $status.\n");
	return not $status;
}

=back

=cut

1;
