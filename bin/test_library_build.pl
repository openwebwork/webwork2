#!/usr/bin/env perl




BEGIN {
        die "WEBWORK_ROOT not found in environment.\n"
                unless exists $ENV{WEBWORK_ROOT};
	# Unused variable, but define it to avoid an error message.
	$WeBWorK::Constants::WEBWORK_DIRECTORY = '';
}

# Get database connection

use lib "$ENV{WEBWORK_ROOT}/lib";
use WeBWorK::CourseEnvironment;
use OPLUtils qw/build_library_directory_tree build_library_subject_tree build_library_textbook_tree/;
use DBI;

my $ce = new WeBWorK::CourseEnvironment({webwork_dir=>$ENV{WEBWORK_ROOT}});
my $dbh = DBI->connect(
        $ce->{database_dsn},
        $ce->{database_username},
        $ce->{database_password},
        {
                PrintError => 0,
                RaiseError => 1,
        },
);

# auto flush printing
my $old_fh = select(STDOUT);
$| = 1;
select($old_fh);

build_library_directory_tree($ce);
build_library_subject_tree($ce,$dbh);
build_library_textbook_tree($ce,$dbh);

$dbh->disconnect;