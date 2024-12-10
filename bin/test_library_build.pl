#!/usr/bin/env perl

BEGIN {
	use Mojo::File qw(curfile);
	use Env        qw(WEBWORK_ROOT);

	$WEBWORK_ROOT = curfile->dirname->dirname;
}

# Get database connection

use lib "$ENV{WEBWORK_ROOT}/lib";
use lib "$ENV{WEBWORK_ROOT}/bin";

use WeBWorK::CourseEnvironment;
use OPLUtils qw/build_library_directory_tree build_library_subject_tree build_library_textbook_tree/;
use DBI;

my $ce  = WeBWorK::CourseEnvironment->new({ webwork_dir => $ENV{WEBWORK_ROOT} });
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
build_library_subject_tree($ce, $dbh);
build_library_textbook_tree($ce, $dbh);

$dbh->disconnect;
