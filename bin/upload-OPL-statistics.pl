#!/usr/bin/env perl

# This script dumps the local OPL statistics table and uploads it.

BEGIN {
	use Mojo::File qw(curfile);
	use Env        qw(WEBWORK_ROOT);

	$WEBWORK_ROOT = curfile->dirname->dirname;
}

use lib "$ENV{WEBWORK_ROOT}/lib";

use WeBWorK::CourseEnvironment;

use Net::Domain qw/domainname/;
use String::ShellQuote;

my $ce = WeBWorK::CourseEnvironment->new({ webwork_dir => $ENV{WEBWORK_ROOT} });

# Get DB connection settings

my $db     = $ce->{database_name};
my $host   = $ce->{database_host};
my $port   = $ce->{database_port};
my $dbuser = $ce->{database_username};
my $dbpass = $ce->{database_password};

my $domainname  = domainname() || 'unknown';
my $time        = time();
my $output_file = "$domainname-$time-opl.sql";

my $done;
my $desc;
my $input;
my $answered;
do {
	print <<'END_REQUEST';
WeBWorK and the Open Problem Library (OPL) are provided freely under an
open-source license. We ask that you share your OPL usage statistics for
the benefit of all who use WeBWorK. The following information will be shared
with the WeBWorK community if you agree:

* a list of OPL problems that have been used on your server, with
  the following statistics for each:

  * the total number of users who attempted the problem
  * the average number of attempts made per user on the problem
  * the average completion percentage for each user who attempted the problem

Share OPL usage statistics with the WeBWorK community [Y/N]:
END_REQUEST
	$input = <STDIN>;
	chomp $input;

	if ($input =~ m/y/i) {
		$answered = 1;
	} elsif ($input =~ m/n/i) {
		exit;
	}
} while (!$answered);

do {
	print
		"\nWe would appreciate it if you could provide \nsome basic information to help us \nkeep track of the data we receive.\n\n";

	$desc = "File:\n$output_file\n";

	print "What university is this data for?\n";

	$desc .= "University:\n";
	$input = <STDIN>;
	$desc .= $input;

	print "What department is this data for?\n";

	$desc .= "Department:\n";
	$input = <STDIN>;
	$desc .= $input;

	print "What is your name?\n";

	$desc .= "Name:\n";
	$input = <STDIN>;
	$desc .= $input;

	print "What is your email address?\n";

	$desc .= "Email:\n";
	$input = <STDIN>;
	$desc .= $input;

	print "Have you uploaded data from this server before?\n";

	$desc .= "Uploaded Previously:\n";
	$input = <STDIN>;
	$desc .= $input;

	print "Approximately what years does this data span?\n";

	$desc .= "Years:\n";
	$input = <STDIN>;
	$desc .= $input;

	print "Approximately how many classes are included?\n";

	$desc .= "Number of Classes:\n";
	$input = <STDIN>;
	$desc .= $input;

	print "Additional Comments?\n";

	$desc .= "Additional Comments:\n";
	$input = <STDIN>;
	$desc .= $input;

	print "The data you just entered is below:\n\n";

	print $desc. "\n";

	do {
		print "Please choose one of the following:\n";
		print "1. Upload Data\n";
		print "2. Reenter above information.\n";
		print "3. Cancel.\n";
		print "[1/2/3]? ";

		$input = <STDIN>;
		chomp $input;

		if ($input eq '3') {
			exit;
		} elsif ($input eq '2') {
			$done     = 0;
			$answered = 1;
		} elsif ($input eq '1') {
			$done     = 1;
			$answered = 1;
		} else {
			$answered = 0;
		}
	} while (!$answered);

} while (!$done);

my $desc_file = "$domainname-$time-desc.txt";

open(my $fh, ">", $desc_file)
	or die "Couldn't open file for saving description.";

print $fh $desc;

close($fh);

print "Dumping local OPL statistics\n";

$dbuser = shell_quote($dbuser);
$db     = shell_quote($db);

$ENV{'MYSQL_PWD'} = $dbpass;

my $mysqldump_command = $ce->{externalPrograms}->{mysqldump};

# Conditionally add --column-statistics=0 as MariaDB databases do not support it
# see: https://serverfault.com/questions/912162/mysqldump-throws-unknown-table-column-statistics-in-information-schema-1109
#      https://github.com/drush-ops/drush/issues/4410

my $column_statistics_off      = "";
my $test_for_column_statistics = `$mysqldump_command --help | grep 'column-statistics'`;
if ($test_for_column_statistics) {
	$column_statistics_off = " --column-statistics=0 ";
}

`$mysqldump_command --host=$host --port=$port --user=$dbuser $column_statistics_off $db OPL_local_statistics > $output_file`;

print "Database File Created\n";

my $tar_file = "$domainname-$time-data.tar.gz";

print "Zipping files\n";
`tar -czf $tar_file $output_file $desc_file`;

print "Uploading file\n";
`echo "put $tar_file" | sftp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null wwdata_upload\@146.111.135.122:wwdata/`;

print "Cleaning up\n";
`rm $desc_file $tar_file $output_file`;

print "Done\n";
1;
