################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Utils/CourseManagement.pm,v 1.4 2004/05/07 21:49:48 sh002i Exp $
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

package WeBWorK::Utils::CourseManagement;
use base qw(Exporter);

=head1 NAME

WeBWorK::Utils::CourseManagement - create, rename, and delete courses.

=cut

use strict;
use warnings;
use Carp;
use DBI;
use File::Path qw(rmtree);
use WeBWorK::Utils qw(dequote runtime_use undefstr readDirectory);

our @EXPORT    = ();
our @EXPORT_OK = qw(
	addCourse
	renameCourse
	deleteCourse
	listCourses
);

use constant CREATE_HELPERS => {
	sql => \&addCourseSQL,
};

use constant RENAME_HELPERS => {
	sql => \&renameCourseSQL,
	gdbm => \&renameCourseGDBM,
};

use constant DELETE_HELPERS => {
	sql => \&deleteCourseSQL,
};

=head1 FUNCTIONS

=over

=item addCourse(%options)

Options must contain:

 courseID => $courseID,
 ce => $ce,
 courseOptions => $courseOptions, 
 dbOptions => $dbOptions,
 users => $users

Create a new course named $courseID.

$ce is a WeBWorK::CourseEnvironment object that describes the new course's
environment.

$courseOptions is a reference to a hash containing the following options:

 dbLayoutName         => $dbLayoutName
 globalUserID         => $dbLayouts{gdbm}->{set}->{params}->{globalUserID}
                         $dbLayouts{gdbm}->{problem}->{params}->{globalUserID}
 allowedRecipients    => $mail{allowedRecipients}
 feedbackRecipients   => $mail{feedbackRecipients}
 PRINT_FILE_NAMES_FOR => $pg{specialPGEnvironmentVars}->{PRINT_FILE_NAMES_FOR}

C<dbLayoutName> is required. C<allowedRecipients>, C<feedbackRecipients>, and
C<PRINT_FILE_NAMES_FOR> are references to arrays.

$dbOptions is a reference to a hash containing information required to create a
database for the course.

 if dbLayout == "sql":
 
 	host     => host to connect to
 	port     => port to connect to
 	username => user to connect as (must have CREATE, DELETE, FILE, INSERT,
 	            SELECT, UPDATE privileges, WITH GRANT OPTION.)
 	password => password to supply
 	database => the name of the database to create
 	wwhost   => the host from which the webwork database users will be allowed
 	            to connect. (if host is set to localhost, this should be set to
 	            localhost too.)

These values must match the information given in the selected dbLayout. If
$dbOptions is undefined, addCourse() assumes that the database has already been
created, and skips that step in the course creation process.

$users is a list of arrayrefs, each containing a User, Password, and
PermissionLevel record for a single user:

 $users = [ $User, $Password, $PermissionLevel ]

These users are added to the course.

=cut

sub addCourse {
	my (%options) = @_;
	
	my $courseID = $options{courseID};
	my $ce = $options{ce};
	my %courseOptions = %{ $options{courseOptions} };
	my %dbOptions = defined $options{dbOptions} ? %{ $options{dbOptions} } : ();
	my @users = exists $options{users} ? @{ $options{users} } : ();
	
	# get the database layout out of the options hash
	my $dbLayoutName = $courseOptions{dbLayoutName};
	
	# collect some data
	my $coursesDir = $ce->{webworkDirs}->{courses};
	my $courseDir = "$coursesDir/$courseID";
	
	# fail if the course already exists
	if (-e $courseDir) {
		croak "$courseID: course exists";
	}
	
	# fail if the database layout is invalid
	if (defined $dbLayoutName and not exists $ce->{dbLayouts}->{$dbLayoutName}) {
		croak "$dbLayoutName: not found in \%dbLayouts";
	}
	
	# if we didn't get a database layout, use the default one
	if (not defined $dbLayoutName) {
		$dbLayoutName = $ce->{dbLayoutName};
	}
	
	##### step 1: create course directory structure #####
	
	my @subDirs = sort values %{ $ce->{courseDirs} };
	foreach my $subDir (@subDirs) {
		mkdir "$subDir"
			or die "Failed to create course directory $subDir: $!\n";
	}
	
	##### step 2: create course database (if necessary) #####
	
	my $createHelper = CREATE_HELPERS->{$dbLayoutName};
	if (defined $createHelper) {
		$createHelper->($courseID, $ce, $dbLayoutName, %dbOptions);
	}
	
	##### step 3: populate course database #####
	
	my $db = WeBWorK::DB->new($ce->{dbLayouts}->{$dbLayoutName});
	
	my @professors; # user ID of any user whose permission level == 10
	
	foreach my $userTriple (@users) {
		my ($User, $Password, $PermissionLevel) = @$userTriple;
		if ($PermissionLevel->permission == 10) {
			push @professors, $PermissionLevel->user_id;
		}
		eval { $db->addUser($User)                       }; warn $@ if $@;
		eval { $db->addPassword($Password)               }; warn $@ if $@;
		eval { $db->addPermissionLevel($PermissionLevel) }; warn $@ if $@;
	}
	
	##### step 4: write course.conf file #####
	
	my $courseEnvFile = $ce->{courseFiles}->{environment};
	open my $fh, ">", $courseEnvFile
		or die "failed to open $courseEnvFile for writing.\n";
	writeCourseConf($fh, $ce, %courseOptions);
	close $fh;
}

=item renameCourse($webworkRoot, $oldCourseID, $newCourseID)

Rename the course named $oldCourseID to $newCourseID.

The name course directory is set to $newCourseID.

If the course's database layout is C<sql>, a new database is created, course
data is exported from the old database and imported into the new database, and
the old database is deleted.

If the course's database layout is C<gdbm>, the DBM files are simply renamed on
disk.

If the course's database layout is something else, no database changes are made.

Any errors encountered while renaming the course are returned.

=cut

sub renameCourse {
	my ($webworkRoot, $oldCourseID, $newCourseID) = @_;
	
	
}

=item deleteCourse(%options)

Options must contain:

 courseID => $courseID,
 ce => $ce,
 dbOptions => $dbOptions,

$ce is a WeBWorK::CourseEnvironment object that describes the course's
environment. It is your responsability to pass a course environment object that
describes the course to be deleted. Do not pass the course environment object
associated with the request, unless you are deleting the course you're currently
using.

$dbOptions is a reference to a hash containing information required to create a
database for the course.

 if dbLayout == "sql":
 
 	host     => host to connect to
 	port     => port to connect to
 	username => user to connect as (must have CREATE, DELETE, FILE, INSERT,
 	            SELECT, UPDATE privileges, WITH GRANT OPTION.)
 	password => password to supply
 	database => the name of the database to create

Deletes the course named $courseID. The course directory is removed.

If the course's database layout is C<sql>, the course database is dropped.

If the course's database layout is something else, no databases are removed.

Any errors encountered while deleting the course are returned.

=cut

sub deleteCourse {
	my (%options) = @_;
	
	my $courseID = $options{courseID};
	my $ce = $options{ce};
	my %dbOptions = defined $options{dbOptions} ? %{ $options{dbOptions} } : ();
	
	# make sure the user isn't brain damaged
	die "the course environment supplied doesn't appear to describe the course $courseID. can't proceed."
		unless $ce->{courseName} eq $courseID;
	
	##### step 1: delete course directory structure #####
	
	my $courseDir = $ce->{courseDirs}->{root};
	rmtree($courseDir, 0, 0);
		
	##### step 2: delete course database (if necessary) #####
	
	my $dbLayoutName = $ce->{dbLayoutName};
	my $deleteHelper = DELETE_HELPERS->{$dbLayoutName};
	if (defined $deleteHelper) {
		$deleteHelper->($courseID, $ce, $dbLayoutName, %dbOptions);
	}
}

=item listCourses($ce)

Lists the courses defined. 

=cut

sub listCourses {
	my ($ce) = @_;
	
	my $coursesDir = $ce->{webworkDirs}->{courses};
	
	return grep { not (m/^\./ or m/^CVS$/) and -d "$coursesDir/$_" } readDirectory($coursesDir);
}

=back

=cut

################################################################################

=head1 DATABASE-LAYOUT SPECIFIC HELPER FUNCTIONS

These functions are used by the methods and should not be called directly.

=over

=item addCourseSQL($courseID, $ce, $dbLayoutName, %options)

=cut

=for comment



=cut

sub addCourseSQL {
	my ($courseID, $ce, $dbLayoutName, %options) = @_;
	
	##### parse dbLayout to generate sql statements #####
	
	my %sources;
	
	#warn "\n";
	#warn "addCourseSQL: dbLayoutName=$dbLayoutName\n";
	
	my %dbLayout = %{ $ce->{dbLayouts}->{$dbLayoutName} };
	
	my @tables = keys %dbLayout;
	#warn "addCourseSQL: layout defines the following tables: @tables\n";
	#warn "\n";
	
	foreach my $table (@tables) {
		my %table = %{ $dbLayout{$table} };
		my %params = %{ $table{params} };
		
		my $source = $table{source};
		#warn "addCourseSQL: $table: DBI source is $source\n";
		
		my $tableOverride = $params{tableOverride};
		#warn "addCourseSQL: $table: SQL table name is ", undefstr("not defined", $tableOverride), "\n";
		
		my $recordClass = $table{record};
		#warn "addCourseSQL: $table: record class is $recordClass\n";
		
		runtime_use($recordClass);
		my @fields = $recordClass->FIELDS;
		#warn "addCourseSQL: $table: WeBWorK field names: @fields\n";
		
		if (exists $params{fieldOverride}) {
			my %fieldOverride = %{ $params{fieldOverride} };
			foreach my $field (@fields) {
				$field = $fieldOverride{$field} if exists $fieldOverride{$field};
			}
			#warn "addCourseSQL: $table: SQL field names: @fields\n";
		}
		
		# generate table creation statement
		
		my $tableName = $tableOverride || $table;
		my $fieldList = join(", ", map("$_ TEXT", @fields));
		my $createStmt = "CREATE TABLE $tableName ( $fieldList );";

		#warn "addCourseSQL: $table: CREATE statement is: $createStmt\n";
		
		# generate GRANT statements
		
		my $grantStmtRO = "GRANT SELECT"
				. " ON $options{database}.$tableName"
				. " TO $params{usernameRO}\@$options{wwhost}"
				. " IDENTIFIED BY '$params{passwordRO}';";
		my $grantStmtRW = "GRANT SELECT, INSERT, UPDATE, DELETE"
				. " ON $options{database}.$tableName"
				. " TO $params{usernameRW}\@$options{wwhost}"
				. " IDENTIFIED BY '$params{passwordRW}';";
		
		#warn "addCourseSQL: $table: GRANT RO statement is: $grantStmtRO\n";
		#warn "addCourseSQL: $table: GRANT RW statement is: $grantStmtRW\n";
		
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
 		warn "addCourseSQL: database layout $dbLayoutName defines more than one SQL source.\n";
		foreach my $curr (keys %sources) {
			$source = $curr if not defined $source or @{ $sources{$curr} } > @{ $sources{$source} };
 		}
 		warn "addCourseSQL: only creating tables with source \"$source\".\n";
 		warn "addCourseSQL: others will have to be created manually.\n";
 	} else {
		# there's only one
		($source) = keys %sources;
	}
	my @stmts = (
		"CREATE DATABASE $options{database};",
		"USE $options{database};",
		@{ $sources{$source} }
	);
	
	##### issue SQL statements #####
	
	my ($driver) = $source =~ m/^dbi:(\w+):/i;
	execSQLStatements($driver, $ce->{externalPrograms}, \%options, @stmts)
	
}

=item renameCourseSQL($oldCourseID, $newCourseID, $ce, $dbLayoutName, %options)

=cut

=item deleteCourseSQL($courseID, $ce, $dbLayoutName, %options)

=cut

sub deleteCourseSQL {
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
	my ($driver) = $dbi_source =~ m/^dbi:(\w+):/i;
	
	my $stmt = "DROP DATABASE $options{database};";
	
	execSQLStatements($driver, $ce->{externalPrograms}, \%options, $stmt);
}

=item renameCourseGDBM($oldCourseID, $newCourseID, $ce, $dbLayoutName, %options)

=cut

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

=cut

sub execSQLStatements {
	my ($driver, $externalPrograms, $dbOptions, @statements) = @_;
	my %options = %$dbOptions;
	
	if (lc $driver eq "mysql") {
		my @commandLine = ( $externalPrograms->{mysql} );
		push @commandLine, "--host=$options{host}" if exists $options{host};
		push @commandLine, "--port=$options{port}" if exists $options{port};
		push @commandLine, "--user=$options{username}" if exists $options{username};
		push @commandLine, "--password=$options{password}" if exists $options{password};
		
		open my $mysql, "|@commandLine"
				or die "execSQLStatements: failed to execute \"@commandLine\": $!\n";
		
		# exec sql statements
		foreach my $stmt (@statements) {
			warn "execSQLStatements: exec: $stmt\n";
			print $mysql "$stmt\n";
		}
		
		close $mysql;
	}
	
	# add code to deal with other RDBMSs here:
	# 
	#elsif (lc $driver eq "foobar") {
	#	# do something else
	#}
	
	else {
		warn "execSQLStatements: driver \"$driver\" is not supported.\n";
	}
}

=item protectQString($string)

Protects the contents of a single-quoted Perl string.

=cut

sub protectQString {
	my ($string) = @_;
	$string =~ s/'/\'/g;
	return $string;
}

=item writeCourseConf($fh, $ce, %options)

Writes a course.conf file to $fh, a file handle, using defaults from the course
environment object $ce and overrides from %options. %options can contain any of
the pairs accepted in %courseOptions by addCourse(), above.

=cut

sub writeCourseConf {
	my ($fh, $ce, %options) = @_;
	
	# several options should be defined no matter what
	$options{dbLayoutName} = $ce->{dbLayoutName} unless defined $options{dbLayoutName};
	$options{globalUserID} = $ce->{dbLayouts}->{gdbm}->{set}->{params}->{globalUserID}
		unless defined $options{dbLayoutName};
	
	print $fh <<'EOF';
#!perl
################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
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

# This file is used to override the global WeBWorK course environment for
# requests to this course. All package variables set in this file are added to
# the course environment. If you wish to set a variable here but omit it from
# the course environment,  use the "my" keyword. Commonly changed configuration
# options are noted below.

EOF
	
	print $fh <<'EOF';
# Database Layout (global value typically defined in global.conf)
# 
# Several database are defined in the file conf/database.conf and stored in the
# hash %dbLayouts.
# 
# The database layout is always set here, since one should be able to change the
# default value in global.conf without disrupting existing courses.
# 
# global.conf values:
EOF
	
	print $fh "# \t", '$dbLayoutName = \'', protectQString($ce->{dbLayoutName}), '\';', "\n";
	print $fh "# \t", '*dbLayout = $dbLayouts{$dbLayoutName};', "\n";
	print $fh "\n";
	
	if (defined $options{dbLayoutName}) {
		print $fh '$dbLayoutName = \'', protectQString($options{dbLayoutName}), '\';', "\n";
		print $fh '*dbLayout = $dbLayouts{$dbLayoutName};', "\n";
		print $fh "\n";
	} else {
		print $fh "\n\n\n";
	}
	
	print $fh <<'EOF';
# Global User ID (global value typically defined in database.conf)
# 
# The globalUserID parameter given for the set and problem tables denotes the ID
# of the user that the GlobalTableEmulator will use to store data for the set
# and problem tables.
# 
# If a course will be used under WeBWorK 1.x, this value should be overridden on
# a course-by-course basis to the ID of the professor who is most likely to be
# involved in creating new problem sets. Sets which have not been assigned will
# only be visible to this user when logging into WeBWorK 1.x.
# 
# The global user ID is always set here, since one should be able to change the
# default value in database.conf without disrupting existing courses.
# 
# global.conf values:
EOF
	
	print $fh "# \t", '$dbLayouts{gdbm}->{set}->{params}->{globalUserID} = \'',
			protectQString($ce->{dbLayouts}->{gdbm}->{set}->{params}->{globalUserID}), '\';', "\n";
	print $fh "# \t", '$dbLayouts{gdbm}->{problem}->{params}->{globalUserID} = \'',
			protectQString($ce->{dbLayouts}->{gdbm}->{problem}->{params}->{globalUserID}), '\';', "\n";
	print $fh "\n";
	
	if (defined $options{globalUserID} or defined $options{globalUserID}) {
		if (defined $options{globalUserID}) {
			print $fh '$dbLayouts{gdbm}->{set}->{params}->{globalUserID} = \'',
					protectQString($options{globalUserID}), '\';', "\n";
		}
		if (defined $options{globalUserID}) {
			print $fh '$dbLayouts{gdbm}->{problem}->{params}->{globalUserID} = \'',
					protectQString($options{globalUserID}), '\';', "\n";
		}
		print $fh "\n";
	} else {
		print $fh "\n\n\n";
	}
	
	print $fh <<'EOF';
# Allowed Mail Recipients (global value typically not defined)
# 
# Defines addresses to which the PG system is allowed to send mail. This should
# probably be set to the addresses of professors of this course. Sending mail
# from the PG system (i.e. questionaires, essay questions) will fail if this is
# not set.
# 
# global.conf values:
EOF
	
	if (defined $ce->{mail}->{allowedRecipients}) {
		print $fh "# \t", '$mail{allowedRecipients} = [',
				join(", ", map { "'" . protectQString($_) . "'" } @{ $ce->{mail}->{allowedRecipients} }), '];', "\n";
	} else {
		print $fh "# \t", '$mail{allowedRecipients} = [  ];', "\n";
	}
	print $fh "\n";
	
	if (defined $options{allowedRecipients}) {
		print $fh '$mail{allowedRecipients} = [',
				join(", ", map { "'" . protectQString($_) . "'" } @{ $options{allowedRecipients} }), '];', "\n";
		print $fh "\n";
	} else {
		print $fh "\n\n\n";
	}
	
	print $fh <<'EOF';
# Feedback Mail Recipients (global value typically not defined)
# 
# Defines recipients for feedback mail. If not defined, mail is sent to all
# instructors and TAs.
# 
# global.conf values:
EOF
	
	if (defined $ce->{mail}->{feedbackRecipients}) {
		print $fh "# \t", '$mail{feedbackRecipients} = [',
				join(", ", map { "'" . protectQString($_) . "'" } @{ $ce->{mail}->{feedbackRecipients} }), '];', "\n";
	} else {
		print $fh "# \t", '$mail{feedbackRecipients} = [  ];', "\n";
	}
	print $fh "\n";
	
	if (defined $options{feedbackRecipients}) {
		print $fh '$mail{feedbackRecipients} = [',
				join(", ", map { "'" . protectQString($_) . "'" } @{ $options{feedbackRecipients} }), '];', "\n";
		print $fh "\n";
	} else {
		print $fh "\n\n\n";
	}
}

1;
