################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Utils/CourseManagement/sql_single.pm,v 1.14 2006/09/29 19:39:55 sh002i Exp $
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
use WeBWorK::Utils::CourseManagement qw/dbLayoutSQLSources/;

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

1;
