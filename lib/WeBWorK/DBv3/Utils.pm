################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DBv3/Utils.pm,v 1.1 2004/11/23 02:50:13 sh002i Exp $
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

package WeBWorK::DBv3::Utils;
use base qw(Exporter);

=head1 NAME

WeBWorK::DBv3::Utils - useful utilities for WWDBv3.

=cut

use strict;
use warnings;
use DBI;
use Fcntl qw/:DEFAULT :flock/;

use constant GET_VERSION => "SELECT `val` FROM `setting` WHERE `name`='db_version'";
use constant INCR_VERSION => "UPDATE `setting` SET `val`=`val`+1 WHERE `name`='db_version'";
use constant DB_VERSION => 1;
use constant DELTAS => [
	q/ # DUMMY VALUE FOR 0 /,
	q/ # DUMMY VALUE FOR 1 /,
];

our @EXPORT = qw(
	upgrade_schema
);

=head1 FUNCTIONS

=head2 upgrade_schema

 upgrade_schema($dbh, $lockfile)

This is a private subroutine, but it has interesting behavior and is therefore
documented here. It should only be called by WeBWorK::DBv3.

Checks the 'db_version' setting in the C<setting> table of the specified WWDBv3
database. If it is less than the current version (defined by the constant
C<DB_VERSION> in this file), deltas are applied to the database to update it.

A lockfile is used to prevent concurrent execution of this subroutine. However,
it does not protect against concurrent execution on the same database from
separate machines.

Any database error causes an exception to be thrown.

=cut

sub upgrade_schema {
	my ($dbh, $lockfile) = @_;
	my $dsn = "dbi:" . $dbh->{Driver}->{Name} . ":" . $dbh->{Name};
	
	# use the upgrade_lock to protect this critical section
	local *LOCK;
	sysopen LOCK, $lockfile, O_RDONLY|O_CREAT
		or die "failed to sysopen WWDBv3 upgrade lock '$lockfile' with flags 'O_RDONLY|OCREAT': $!";
	flock LOCK, LOCK_EX
		or die "failed to flock WWDBv3 upgrade lock '$lockfile' with flags 'LOCK_EX': $!";
	
	my @record = $dbh->selectrow_array(GET_VERSION);
	if (@record) {
		my $db_version = $record[0];
		if ($db_version !~ /^-?\d+$/) {
			warn "System setting 'db_version' in WWDBv3 database '$dsn' has non-numeric value '$db_version'. Assuming database schema is up-to-date.\n";
		} elsif ($db_version == DB_VERSION) {
			# database is fine :)
		} elsif ($db_version < 1) {
			warn "System setting 'db_version' in WWDBv3 database '$dsn' has nonsensical value '$db_version'. Assuming database schema is up-to-date.\n";
		} elsif ($db_version > DB_VERSION) {
			warn "System setting 'db_version' in WWDBv3 database '$dsn' has future value '$db_version'. Assuming database schema is up-to-date.\n";
		} else {
			warn "WWDBv3 schema at version '$db_version', current version is '@{[DB_VERSION]}'. Upgrade required.\n";
			
			foreach my $version ($db_version+1 .. DB_VERSION) {
				my $delta = DELTAS->[$version];
				
				unless ($dbh->do($delta)) {
					warn "Failed to apply schema delta '$version' to WWDBv3 database '$dsn'. Bailing out. DBI error: $DBI::errstr";
					last;
				}
				
				unless ($dbh->do(INCR_VERSION)) {
					warn "Failed to increment system setting 'db_version' in WWDBv3 database '$dsn'. Bailing out. DBI error: $DBI::errstr";
					last;
				}
				
				warn "Upgraded WWDBv3 schema to version '$version'.\n";
			}
		}
	} else {
		# Value doesn't exist yet. We could add it, but there's no sensible
		# default since we can't tell what state the database is in otherwise.
		warn "System setting 'db_version' not found in WWDBv3 database '$dsn'. Assuming database schema is up-to-date.\n";
	}
	
	# we're done, disconnect and unlock
	close LOCK;
}

1;
