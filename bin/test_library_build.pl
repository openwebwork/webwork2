#!/usr/bin/env perl

BEGIN {
	use Mojo::File qw(curfile);
	use YAML::XS qw(LoadFile);
	use Env qw(WEBWORK_ROOT PG_ROOT);

	$WEBWORK_ROOT = curfile->dirname->dirname;

	# Load the configuration file to obtain the PG root directory.
	my $config_file = "$WEBWORK_ROOT/conf/webwork2.mojolicious.yml";
	$config_file = "$WEBWORK_ROOT/conf/webwork2.mojolicious.dist.yml" unless -e $config_file;
	my $config = LoadFile($config_file);
	$PG_ROOT = $config->{pg_dir};

	die "The pg directory must be correctly defined in conf/webwork2.mojolicious.yml" unless -e $ENV{PG_ROOT};
}

# Get database connection

use lib "$ENV{WEBWORK_ROOT}/lib";
use lib "$ENV{WEBWORK_ROOT}/bin";
use lib "$ENV{PG_ROOT}/lib";
use WeBWorK::CourseEnvironment;
use OPLUtils qw/build_library_directory_tree build_library_subject_tree build_library_textbook_tree/;
use DBI;

my $ce  = WeBWorK::CourseEnvironment->new({ webwork_dir => $ENV{WEBWORK_ROOT}, pg_dir => $ENV{PG_ROOT} });
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
