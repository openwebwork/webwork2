################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/DBUpgrade.pm,v 1.4 2007/08/13 22:59:59 sh002i Exp $
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

package WeBWorK::Utils::DBUpgrade;

=head1 NAME

WeBWorK::Utils::DBUpgrade - upgrade WeBWorK SQL databases.

=cut

use strict;
use warnings;
use WeBWorK::Debug;
#use WeBWorK::Utils::CourseManagement qw/listCourses/;

################################################################################

# dummy package variable to localize later
our $self;

my $i = -1;
our @DB_VERSIONS;

$DB_VERSIONS[++$i]{desc} = "is the initial version of database, identical to database structure in WeBWorK 2.2.x.";

$DB_VERSIONS[++$i]{desc} = "adds dbupgrade table to facilitate automatic database upgrades.";
$DB_VERSIONS[  $i]{global_code} = sub {
	$self->dbh->do("CREATE TABLE `dbupgrade` (`name` VARCHAR(255) NOT NULL PRIMARY KEY, `value` TEXT)");
	$self->dbh->do("INSERT INTO `dbupgrade` (`name`, `value`) VALUES (?, ?)", {}, "db_version", 1);
	$self->register_sql_table("dbupgrade");
};

$DB_VERSIONS[++$i]{desc} = "adds problems_per_page field to set and set_user tables of each course.";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	$self->dbh->do("ALTER TABLE `${course}_set` ADD COLUMN `problems_per_page` INT")
		if $self->sql_table_exists("${course}_set");
	$self->dbh->do("ALTER TABLE `${course}_set_user` ADD COLUMN `problems_per_page` INT")
		if $self->sql_table_exists("${course}_set_user");
};

$DB_VERSIONS[++$i]{desc} = "adds depths table to keep track of dvipng depth information.";
$DB_VERSIONS[  $i]{global_code} = sub {
	$self->dbh->do("CREATE TABLE depths (md5 CHAR(33) NOT NULL, depth SMALLINT, PRIMARY KEY (md5))");
	$self->register_sql_table("depths");
};

$DB_VERSIONS[++$i]{desc} = "changes type of key timestamp field to BIGINT";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	return unless $self->sql_table_exists("${course}_key");
	$self->dbh->do("ALTER TABLE `${course}_key` CHANGE COLUMN `timestamp` `timestamp` BIGINT");
};

$DB_VERSIONS[++$i]{desc} = "changes type of problem_user status field to FLOAT";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	return unless $self->sql_table_exists("${course}_problem_user");
	$self->dbh->do("UPDATE `${course}_problem_user` SET `status`=NULL WHERE `status`=''");
	$self->dbh->do("ALTER TABLE `${course}_problem_user` CHANGE COLUMN `status` `status` FLOAT");
};

$DB_VERSIONS[++$i]{desc} = "changes types of alphanumeric keyfields to TINYBLOB NOT NULL";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	$self->dbh->do("ALTER TABLE `${course}_user` CHANGE COLUMN `user_id` `user_id` TINYBLOB NOT NULL")
		if $self->sql_table_exists("${course}_user");
	$self->dbh->do("ALTER TABLE `${course}_password` CHANGE COLUMN `user_id` `user_id` TINYBLOB NOT NULL")
		if $self->sql_table_exists("${course}_password");
	$self->dbh->do("ALTER TABLE `${course}_permission` CHANGE COLUMN `user_id` `user_id` TINYBLOB NOT NULL")
		if $self->sql_table_exists("${course}_permission");
	$self->dbh->do("ALTER TABLE `${course}_key` CHANGE COLUMN `user_id` `user_id` TINYBLOB NOT NULL")
		if $self->sql_table_exists("${course}_key");
	$self->dbh->do("ALTER TABLE `${course}_set` CHANGE COLUMN `set_id` `set_id` TINYBLOB NOT NULL")
		if $self->sql_table_exists("${course}_set");
	$self->dbh->do("ALTER TABLE `${course}_problem` CHANGE COLUMN `set_id` `set_id` TINYBLOB NOT NULL")
		if $self->sql_table_exists("${course}_problem");
	$self->dbh->do("ALTER TABLE `${course}_set_user` CHANGE COLUMN `user_id` `user_id` TINYBLOB NOT NULL")
		if $self->sql_table_exists("${course}_set_user");
	$self->dbh->do("ALTER TABLE `${course}_set_user` CHANGE COLUMN `set_id` `set_id` TINYBLOB NOT NULL")
		if $self->sql_table_exists("${course}_set_user");
	$self->dbh->do("ALTER TABLE `${course}_problem_user` CHANGE COLUMN `user_id` `user_id` TINYBLOB NOT NULL")
		if $self->sql_table_exists("${course}_problem_user");
	$self->dbh->do("ALTER TABLE `${course}_problem_user` CHANGE COLUMN `set_id` `set_id` TINYBLOB NOT NULL")
		if $self->sql_table_exists("${course}_problem_user");
};

$DB_VERSIONS[++$i]{desc} = "fixes KEY length, adds UNIQUE KEY for user table";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	return unless $self->sql_table_eixsts("${course}_user");
	$self->dbh->do("ALTER TABLE `${course}_user` DROP KEY `user_id`");
	$self->dbh->do("ALTER TABLE `${course}_user` ADD UNIQUE KEY (`user_id`(255))");
};

$DB_VERSIONS[++$i]{desc} = "fixes KEY length, adds UNIQUE KEY for password table";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	return unless $self->sql_table_exists("${course}_password");
	$self->dbh->do("ALTER TABLE `${course}_password` DROP KEY `user_id`");
	$self->dbh->do("ALTER TABLE `${course}_password` ADD UNIQUE KEY (`user_id`(255))");
};

$DB_VERSIONS[++$i]{desc} = "fixes KEY length, adds UNIQUE KEY for permission table";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	return unless $self->sql_table_exists("${course}_permission");
	$self->dbh->do("ALTER TABLE `${course}_permission` DROP KEY `user_id`");
	$self->dbh->do("ALTER TABLE `${course}_permission` ADD UNIQUE KEY (`user_id`(255))");
};

$DB_VERSIONS[++$i]{desc} = "fixes KEY length, adds UNIQUE KEY for key table";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	return unless $self->sql_table_exists("${course}_key");
	$self->dbh->do("ALTER TABLE `${course}_key` DROP KEY `user_id`");
	$self->dbh->do("ALTER TABLE `${course}_key` ADD UNIQUE KEY (`user_id`(255))");
};

$DB_VERSIONS[++$i]{desc} = "fixes KEY length, adds UNIQUE KEY for set table";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	return unless $self->sql_table_exists("${course}_set");
	$self->dbh->do("ALTER TABLE `${course}_set` DROP KEY `set_id`");
	$self->dbh->do("ALTER TABLE `${course}_set` ADD UNIQUE KEY (`set_id`(255))");
};

$DB_VERSIONS[++$i]{desc} = "fixes KEY length, adds UNIQUE KEY for problem table";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	return unless $self->sql_table_exists("${course}_problem");
	$self->dbh->do("ALTER TABLE `${course}_problem` DROP KEY `set_id`");
	$self->dbh->do("ALTER TABLE `${course}_problem` ADD UNIQUE KEY (`set_id`(255), `problem_id`)");
	$self->dbh->do("ALTER TABLE `${course}_problem` DROP KEY `problem_id`");
	$self->dbh->do("ALTER TABLE `${course}_problem` ADD KEY (`problem_id`)");
};

$DB_VERSIONS[++$i]{desc} = "fixes KEY length, adds UNIQUE KEY for set_user table";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	return unless $self->sql_table_exists("${course}_set_user");
	$self->dbh->do("ALTER TABLE `${course}_set_user` DROP KEY `user_id`");
	$self->dbh->do("ALTER TABLE `${course}_set_user` ADD UNIQUE KEY (`user_id`(255), `set_id`(255))");
	$self->dbh->do("ALTER TABLE `${course}_set_user` DROP KEY `set_id`");
	$self->dbh->do("ALTER TABLE `${course}_set_user` ADD KEY (`set_id`(255))");
};

$DB_VERSIONS[++$i]{desc} = "fixes KEY length, adds UNIQUE KEY for problem_user table";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	return unless $self->sql_table_exists("${course}_problem_user");
	$self->dbh->do("ALTER TABLE `${course}_problem_user` DROP KEY `user_id`");
	$self->dbh->do("ALTER TABLE `${course}_problem_user` ADD UNIQUE KEY (`user_id`(255), `set_id`(255), `problem_id`)");
	$self->dbh->do("ALTER TABLE `${course}_problem_user` DROP KEY `set_id`");
	$self->dbh->do("ALTER TABLE `${course}_problem_user` ADD KEY (`set_id`(255), `problem_id`)");
	$self->dbh->do("ALTER TABLE `${course}_problem_user` DROP KEY `problem_id`");
	$self->dbh->do("ALTER TABLE `${course}_problem_user` ADD KEY (`problem_id`)");
};

$DB_VERSIONS[++$i]{desc} = "changes psvn index from PRIMARY KEY to UNIQUE KEY";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	return unless $self->sql_table_exists("${course}_set_user");
	$self->dbh->do("ALTER TABLE `${course}_set_user` ADD UNIQUE KEY (`psvn`)");
	$self->dbh->do("ALTER TABLE `${course}_set_user` DROP PRIMARY KEY");
};

$DB_VERSIONS[++$i]{desc} = "adds hide_score and hide_work fields to set and set_user";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	if ( $self->sql_table_exists("${course}_set") ) {
		$self->dbh->do("ALTER TABLE `${course}_set` ADD COLUMN `hide_score` ENUM('0','1')");
		$self->dbh->do("ALTER TABLE `${course}_set` ADD COLUMN `hide_work` ENUM('0','1')");
	}
	if ( $self->sql_table_exists("${course}_set_user") ) {
		$self->dbh->do("ALTER TABLE `${course}_set_user` ADD COLUMN `hide_score` ENUM('0','1')");
		$self->dbh->do("ALTER TABLE `${course}_set_user` ADD COLUMN `hide_work` ENUM('0','1')");
	}
};

$DB_VERSIONS[++$i]{desc} = "updates hide_score and hide_work in set and set_user tables to allow more (and more descriptive) possible values";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	if ( $self->sql_table_exists("${course}_set") ) {
		$self->dbh->do("ALTER TABLE `${course}_set` MODIFY COLUMN `hide_score` ENUM('0','1','2')");
		$self->dbh->do("ALTER TABLE `${course}_set` MODIFY COLUMN `hide_work` ENUM('0','1','2')");
	}
	if ( $self->sql_table_exists("${course}_set_user") ) {
		$self->dbh->do("ALTER TABLE `${course}_set_user` MODIFY COLUMN `hide_score` ENUM('0','1','2')");
		$self->dbh->do("ALTER TABLE `${course}_set_user` MODIFY COLUMN `hide_work` ENUM('0','1','2')");
	}
};

$DB_VERSIONS[++$i]{desc} = "adds time_limit_cap field to set and set_user tables";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	if ( $self->sql_table_exists("${course}_set") ) {
		$self->dbh->do("ALTER TABLE `${course}_set` ADD COLUMN `time_limit_cap` ENUM('0','1')");
	}
	if ( $self->sql_table_exists("${course}_set_user") ) {
		$self->dbh->do("ALTER TABLE `${course}_set_user` ADD COLUMN `time_limit_cap` ENUM('0','1')");
	}
};

$DB_VERSIONS[++$i]{desc} = "updates hide_score and hide_work in set and set_user tables to have more descriptive values, set default values";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	if ( $self->sql_table_exists("${course}_set") ) {
		$self->dbh->do("ALTER TABLE `${course}_set` MODIFY COLUMN `hide_score` ENUM('N','Y','BeforeAnswerDate') DEFAULT 'N'");
		$self->dbh->do("ALTER TABLE `${course}_set` MODIFY COLUMN `hide_work` ENUM('N','Y','BeforeAnswerDate') DEFAULT 'N'");
	}
	if ( $self->sql_table_exists("${course}_set_user") ) {
		$self->dbh->do("ALTER TABLE `${course}_set_user` MODIFY COLUMN `hide_score` ENUM('N','Y','BeforeAnswerDate') DEFAULT 'N'");
		$self->dbh->do("ALTER TABLE `${course}_set_user` MODIFY COLUMN `hide_work` ENUM('N','Y','BeforeAnswerDate') DEFAULT 'N'");
	}
};

$DB_VERSIONS[++$i]{desc} = "adds locations, location_addresses, set_locations and set_locations_user tables to database, and add restrict_ip to set and set_user.";
$DB_VERSIONS[  $i]{global_code} = sub {
	$self->dbh->do("CREATE TABLE locations (location_id TINYBLOB NOT NULL, description TEXT, PRIMARY KEY (location_id(1000)))");
	$self->dbh->do("CREATE TABLE location_addresses (location_id TINYBLOB NOT NULL, ip_mask TINYBLOB NOT NULL, PRIMARY KEY (location_id(500),ip_mask(500)))");
};
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	
	$self->dbh->do("CREATE TABLE `${course}_set_locations` (set_id TINYBLOB NOT NULL, location_id TINYBLOB NOT NULL, PRIMARY KEY (set_id(500),location_id(500)))");
	$self->dbh->do("CREATE TABLE `${course}_set_locations_user` (set_id TINYBLOB NOT NULL, user_id TINYBLOB NOT NULL, location_id TINYBLOB NOT NULL, PRIMARY KEY (set_id(300),user_id(300),location_id(300)))");

	if ( $self->sql_table_exists("${course}_set") ) {
		$self->dbh->do("ALTER TABLE `${course}_set` ADD COLUMN `restrict_ip` enum('No','RestrictTo','DenyFrom') DEFAULT 'No'");
	}
	if ( $self->sql_table_exists("${course}_set_user") ) {
		$self->dbh->do("ALTER TABLE `${course}_set_user` ADD COLUMN `restrict_ip` enum('No','RestrictTo','DenyFrom')");
	}
};

$DB_VERSIONS[++$i]{desc} = "updates defaults for hide_work and hide_score in set_user tables.";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;

	if ( $self->sql_table_exists("${course}_set_user") ) {
		$self->dbh->do("ALTER TABLE `${course}_set_user` MODIFY COLUMN `hide_score` ENUM('N','Y','BeforeAnswerDate')");
		$self->dbh->do("ALTER TABLE `${course}_set_user` MODIFY COLUMN `hide_work` ENUM('N','Y','BeforeAnswerDate')");
	}
};

$DB_VERSIONS[++$i]{desc} = "adds relax_restrict_ip, hide_problem_score columns to set and set_user tables.";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;

	if ( $self->sql_table_exists("${course}_set") ) {
		$self->dbh->do("ALTER TABLE `${course}_set` ADD COLUMN `relax_restrict_ip` ENUM('No','AfterAnswerDate','AfterVersionAnswerDate') DEFAULT 'No'");
		$self->dbh->do("ALTER TABLE `${course}_set` ADD COLUMN `hide_score_by_problem` ENUM('N','Y') DEFAULT 'N'");
	}
	if ( $self->sql_table_exists("${course}_set_user") ) {
		$self->dbh->do("ALTER TABLE `${course}_set_user` ADD COLUMN `relax_restrict_ip` ENUM('No','AfterAnswerDate','AfterVersionAnswerDate')");
		$self->dbh->do("ALTER TABLE `${course}_set_user` ADD COLUMN `hide_score_by_problem` ENUM('N','Y')");
	}
};

$DB_VERSIONS[++$i]{desc} = "adds set and set_user fields to allow set-level proctor, updates permissions to allow finer-grained regulation of proctoring.";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	if ( $self->sql_table_exists("${course}_permission") ) {
		$self->dbh->do("UPDATE `${course}_permission` SET `permission`=3 where `permission`=2");
	}
	if ( $self->sql_table_exists("${course}_set") ) {
		$self->dbh->do("ALTER TABLE `${course}_set` ADD COLUMN `restricted_login_proctor` ENUM('No','Yes') DEFAULT 'No'");
	}
	if ( $self->sql_table_exists("${course}_set_user") ) {
		$self->dbh->do("ALTER TABLE `${course}_set_user` ADD COLUMN `restricted_login_proctor` ENUM('No','Yes')");
	}
};

$DB_VERSIONS[++$i]{desc} = "adds per-course setting table";
$DB_VERSIONS[  $i]{course_code} = sub {
	my $course = shift;
	$self->dbh->do("CREATE TABLE `${course}_setting` (`name` VARCHAR(255) NOT NULL PRIMARY KEY, `value` TEXT)");
	$self->register_sql_table("${course}_setting");
	$self->dbh->do("INSERT INTO `${course}_setting` (`name`, `value`) VALUES (?, ?)", {}, "db_version", $i);
};
our $FIRST_COURSE_DB_VERSION = $i;

our $THIS_DB_VERSION = $i;

################################################################################

sub new {
	my $invocant = shift;
	my $class = ref $invocant || $invocant;
	my $self = bless {}, $class;
	$self->init(@_);
	return $self;
}

sub init {
	my ($self, %options) = @_;
	
	$self->{dbh} = DBI->connect(
		$options{ce}{database_dsn},
		$options{ce}{database_username},
		$options{ce}{database_password},
		{
			PrintError => 0,
			RaiseError => 1,
		},
	);
	$self->{verbose_sub} = $options{verbose_sub} || \&debug;
	$self->{confirm_sub} = $options{confirm_sub} || \&ask_permission_stdio;
	$self->{ce} = $options{ce};
	$self->{course_db_versions} = {};
}

sub ce { return shift->{ce} }
sub dbh { return shift->{dbh} }
sub verbose { my $sub = shift->{verbose_sub}; return &$sub(@_) }
sub confirm { my $sub = shift->{confirm_sub}; return &$sub(@_) }

sub DESTROY {
	my ($self) = @_;
	$self->unlock_database;
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}

################################################################################

sub lock_database {
	my ($self) = @_;
	
	$self->verbose("Obtaining dbupgrade lock...\n");
	my ($lock_status) = $self->dbh->selectrow_array("SELECT GET_LOCK('dbupgrade', 10)");
	if (not defined $lock_status) {
		die "Couldn't obtain lock because an error occurred.\n";
	}
	if ($lock_status) {
		$self->verbose("Got lock.\n");
	} else {
		die "Timed out while waiting for lock.\n";
	}
}

sub unlock_database {
	my ($self) = @_;
	
	$self->verbose("Releasing dbupgrade lock...\n");
	my ($lock_status) = $self->dbh->selectrow_array("SELECT RELEASE_LOCK('dbupgrade')");
	if (not defined $lock_status) {
		die "Couldn't release lock because the lock does not exist.\n";
	}
	if ($lock_status) {
		$self->verbose("Released lock.\n");
	} else {
		die "Couldn't release lock because the lock is not held by this thread.\n";
	}
}

################################################################################

sub load_sql_table_list {
	my ($self) = @_;
	my $sql_tables_ref = $self->dbh->selectcol_arrayref("SHOW TABLES");
	$self->{sql_tables} = {}; @{$self->{sql_tables}}{@$sql_tables_ref} = ();
}

sub register_sql_table {
	my ($self, $table) = @_;
	$self->{sql_tables}{$table} = ();
}

sub unregister_sql_table {
	my ($self, $table) = @_;
	delete $self->{sql_tables}{$table};
}

sub sql_table_exists {
	my ($self, $table) = @_;
	return exists $self->{sql_tables}{$table};
}

################################################################################

use constant DB_TABLE_MISSING  => -1;
use constant DB_RECORD_MISSING => -2;

sub get_db_version {
	my ($self, $course) = @_;
	my $table = defined $course ? "${course}_setting" : "dbupgrade";
	if ($self->sql_table_exists($table)) {
		my $table_quoted = $self->dbh->quote_identifier($table);
		my @record = $self->dbh->selectrow_array("SELECT `value` FROM $table_quoted WHERE `name`='db_version'");
		if (@record) {
			return $record[0];
		} else {
			return DB_RECORD_MISSING;
		}
	} else {
		return DB_TABLE_MISSING;
	}
}

my $vers_value_should_be = "The value should always be a positive integer.";
sub check_db_version_format {
	my ($self, $db_version) = @_;
	if (not defined $db_version) {
		return "'db_version' has a NULL value. $vers_value_should_be";
	} elsif ($db_version !~ /^-?\d+$/) {
		return "'db_version' is set to the non-numeric value '$db_version'. $vers_value_should_be";
	} elsif ($db_version < 0) {
		return "'db_version' is set to the negative value '$db_version'. $vers_value_should_be";
	} elsif ($db_version == 0) {
		return "'db_version' is set to 0, which is reserved to indicate a pre-automatic-upgrade version. $vers_value_should_be";
	} else {
		# db_version is a positive integer! yay!
		return;
	}
}

sub set_db_version {
	my ($self, $vers, $course) = @_;
	my $table = defined $course ? "${course}_setting" : "dbupgrade";
	my $table_quoted = $self->dbh->quote_identifier($table);
	$self->dbh->do("UPDATE $table_quoted SET `value`=? WHERE `name`='db_version'", {}, $vers);
}

################################################################################

sub do_upgrade {
	my ($self) = @_;
	
	$self->lock_database;
	$self->load_sql_table_list;
	
	#### Get system's database version
	
	my $system_db_version = $self->get_db_version();
	
	if ($system_db_version == DB_TABLE_MISSING) {
		warn "No 'upgrade' table exists: assuming system database version is 0.\n";
		$system_db_version = 0;
	} elsif ($system_db_version == DB_RECORD_MISSING) {
		die "The 'dbupgrade' table exists in the database, but no 'db_version' record exists in it. Can't continue.\n";
	} elsif (my $error = $self->check_db_version_format($system_db_version)) {
		die "$error Can't continue.\n";
	} elsif ($system_db_version > $THIS_DB_VERSION) {
		die "This database's system db_version value is $system_db_version, but the current database version is only $THIS_DB_VERSION. This database was probably used with a newer version of WeBWorK. Can't continue.\n";
	}
	
	$self->verbose("Initial system db_version is $system_db_version\n");
	
	#### Get database version for each course
	# If $system_db_version < $FIRST_COURSE_DB_VERSION, most courses will not have
	# a db_version, but some might. (Say, if they were imported from a newer
	# version of WeBWorK.)
	
	my @ww_courses = listCourses($self->ce);
	$self->{ww_courses} = \@ww_courses;

	my $course_db_versions = $self->{course_db_versions};

	foreach my $course (@ww_courses) {
		my $course_db_version = $self->get_db_version($course);
		
		if ($system_db_version < $FIRST_COURSE_DB_VERSION) {
			
			if ($course_db_version == DB_TABLE_MISSING) {
				# this is to be expected -- we assume the course is at the current system version
				$self->verbose("Course '$course' has no db_version of it's own, assuming system db_version $system_db_version.\n");
				$course_db_versions->{$course} = $system_db_version;
			} else {
				# there is a settings table -- the course is probably from a later version of WW
				warn "The course '$course' already contains a '${course}_setting' table."
					." Settings tables were introduced at db_version $FIRST_COURSE_DB_VERSION,"
					." but the current system db_version is only $system_db_version."
					." We'll assume that this course is from a later version of WeBWorK"
					." and try to determine the course's version...\n";
				if ($course_db_version == DB_RECORD_MISSING) {
					warn "There is no 'db_version' record in the course's settings table,"
						." so we can't determine the version. This course will be excluded from upgrades."
						." If you know the version of this course,"
						." add a 'db_version' record with the appropriate value to the '${course}_setting' table.\n";
				} elsif (my $error = check_db_version_format($course_db_version)) {
					warn "$error\n";
					warn "There is a 'db_version' record in the course's settings table,"
						." but it has an invalid value , so we can't determine the version."
						." This course will be excluded from upgrades."
						." If you know the version of this course,"
						." update 'db_version' record in the '${course}_setting' table with the appropriate value.\n";
				} elsif ($course_db_version < $FIRST_COURSE_DB_VERSION) {
					warn "This course's version is $course_db_version, which is before per-course versioning was introduced."
						." Therefore, a course at version $course_db_version should have neither a '${course}_setting' table"
						." nor a 'db_version' record in that table. Regardless, we will assume the recorded version is correct.\n";
					$course_db_versions->{$course} = $system_db_version;
				} else {
					warn "This course's version is $course_db_version, which makes sense.\n";
					$course_db_versions->{$course} = $course_db_version;
				}
			}
			
		} else {
			
			if ($course_db_version == DB_TABLE_MISSING) {
				warn "The course '$course' is missing a '${course}_setting' table, so we can't determine the version."
					." This course will be ignored."
					." If you know the version of this course, add a '${course}_setting' table"
					." and add a 'db_version' record with the appropriate value to the table.\n";
			} else {
				# there is a settings table -- good
				if ($course_db_version == DB_RECORD_MISSING) {
					warn "The course '$course' is missing a 'db_version' record in its '${course}_setting' table,"
						." so we can't determine the version. This course will be ignored."
						." If you know the version of this course,"
						." add a 'db_version' record with the appropriate value to the '${course}_setting' table.\n";
				} elsif (my $error = check_db_version_format($course_db_version)) {
					warn "$error\n";
					warn "The course '$course' has an invalid value in the 'db_version' record in its '${course}_setting' table,"
						." so we can't determine the version. This course will be ignored."
						." If you know the version of this course,"
						." update the 'db_version' record in the '${course}_setting' table with the appropriate value.\n";
				} elsif ($course_db_version < $FIRST_COURSE_DB_VERSION) {
					warn "This course's version is $course_db_version, which is before per-course versioning was introduced."
						." Therefore, a course at version $course_db_version should have neither a '${course}_setting' table"
						." nor a 'db_version' record in that table. Regardless, we will assume the recorded version is correct.\n";
					$course_db_versions->{$course} = $course_db_version;
				} else {
					$self->verbose("Course '$course' has valid db_version $course_db_version.\n");
					$course_db_versions->{$course} = $system_db_version;
				}
			}
			
		}
	}

	$self->verbose(map { "$_ => $$course_db_versions{$_}\n" } keys %$course_db_versions);

	#### Determine lowest version

	my $lowest_db_version = $system_db_version;
	foreach my $v (values %$course_db_versions) {
		$lowest_db_version = $v if $v < $lowest_db_version;
	}

	$self->verbose("Lowest db_version is $lowest_db_version\n");

	#### Do the upgrades

	# upgrade_to_version uses this
	$self->{system_db_version} = $system_db_version;
	
	my $vers = $lowest_db_version;
	while ($vers < $THIS_DB_VERSION) {
		$vers++;
		unless ($self->upgrade_to_version($vers)) {
			print "\nUpgrading from version ".($vers-1)." to $vers failed.\n\n";
			unless ($self->ask_permission("Ignore this error and go on to the next version?", 0)) {
				exit 3;
			}
		}
	}
	
	#### All done!
	
	print "\nDatabase is up-to-date at version $vers.\n";
}

################################################################################

use constant OK => 0;
use constant SKIPPED => 1;
use constant ERROR => 2;

sub upgrade_to_version {
	my ($self, $vers) = @_;
	my %info = %{$DB_VERSIONS[$vers]};
	
	print "\nUpgrading database from version " . ($vers-1) . " to $vers...\n";
	my $desc = $info{desc} || "has no description.";
	print "(Version $vers $desc)\n";
	
	if ($self->{system_db_version} < $vers and exists $info{global_code}) {
		eval {
			local $WeBWorK::Utils::DBUpgrade::self = $self;
			$info{global_code}->();
		};
		if ($@) {
			print "\nAn error occured while running the system upgrade code for version $vers:\n";
			print "$@";
			return 0 unless $self->ask_permission("Ignore this error and keep going?", 0);
		}
	}
	$self->set_db_version($vers);
	
	my $do_upgrade = 1;
	foreach my $course (@{$self->{ww_courses}}) {
		if ($do_upgrade) {
			my $result = $self->upgrade_course_to_version($course, $vers);
			if ($result == ERROR) {
				if ($self->ask_permission("Update course's stored db_version to $vers anyway?", 0)) {
					set_db_version($vers, $course);
					print "OK, updated course's stored db_version.\n";
				} else {
					print "OK, not updating course's stored db_version.\n";
				}
				if ($self->ask_permission("Upgrade the remaining courses to version $vers?", 0)) {
					print "OK, going on to the next course...\n";
				} else {
					print "OK, we'll skip upgrading the rest of the courses to version $vers.\n";
					if ($self->ask_permission("Update the stored db_version for the courses we're skipping, as if we had upgraded them?", 1)) {
						$do_upgrade = 0;
					} else {
						return 0;
					}
				}
			} elsif ($result == OK) {
				$self->set_db_version($vers, $course);
			} elsif ($result == SKIPPED) {
				# do nothing
			}
		} else {
			$self->set_db_version($vers, $course);
		}
	}
	
	return 1;
}

sub upgrade_course_to_version {
	my ($self, $course, $vers) = @_;
	my $course_db_versions = $self->{course_db_versions};
	my %info = %{$DB_VERSIONS[$vers]};
	
	my $course_vers = $course_db_versions->{$course};
	#$self->verbose("course=$course course_vers=$course_vers vers=$vers\n");
	if (not defined $course_vers) {
		$self->verbose("Course '$course' has a missing or invalid version -- skipping.\n");
		return SKIPPED;
	} elsif ($course_vers == $vers) {
		$self->verbose("Course '$course' is already at version $vers -- skipping.\n");
		return SKIPPED;
	} elsif ($course_vers > $vers) {
		$self->verbose("Course '$course' version $course_vers > target version $vers -- skipping.\n");
		return SKIPPED;
	} elsif ($course_vers < $vers-1) {
		warn "Course '$course' at version $course_vers, which is too old to upgrade to $vers. This should never happen. Not upgrading.\n";
		return SKIPPED;
	}
	
	$self->verbose("Upgrading course '$course' to version $vers...\n");
	eval {
		local $WeBWorK::Utils::DBUpgrade::self = $self;
		$info{course_code}->($course);
	};
	if ($@) {
		print "\nAn error occured while running the course upgrade code for version $vers on course $course:\n";
		print "$@";
		return ERROR;
	} else {
		return OK;
	}
}

################################################################################

sub ask_permission_stdio {
	my ($prompt, $default) = @_;
	
	$default = 1 if not defined $default;
	my $options = $default ? "[Y/n]" : "[y/N]";
	
	while (1) {
		print "$prompt $options ";
		my $resp = <STDIN>;
		chomp $resp;
		return $default if $resp eq "";
		return 1 if lc $resp eq "y";
		return 0 if lc $resp eq "n";
		$prompt = 'Please enter "y" or "n".';
	}
}

1;

