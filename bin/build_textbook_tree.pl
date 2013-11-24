#!/usr/bin/env perl

# This is the script build-textbook-tree

# This is used to create the file textbook-tree.json which can be used to load in 
# textbook information for the OPL

use strict;
use warnings;
use File::Find;
use File::Basename;
use open qw/:std :utf8/;
use DBI;
use Data::Dumper;
use JSON;
use IO::Handle;

 #(maximum varchar length is 255 for mysql version < 5.0.3.  
 #You can increase path length to  4096 for mysql > 5.0.3)

$| = 1; # autoflush output

BEGIN {
        die "WEBWORK_ROOT not found in environment.\n"
                unless exists $ENV{WEBWORK_ROOT};
	# Unused variable, but define it to avoid an error message.
	$WeBWorK::Constants::WEBWORK_DIRECTORY = '';
}

# Get database connection

use lib "$ENV{WEBWORK_ROOT}/lib";
use WeBWorK::CourseEnvironment;

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

my $libraryRoot = $ce->{problemLibrary}->{root};
$libraryRoot =~ s|/+$||;
my $libraryVersion = $ce->{problemLibrary}->{version};


my $selectClause = "SELECT pg.pgfile_id from OPL_path as path "
	."LEFT JOIN OPL_pgfile AS pg ON pg.path_id=path.path_id "
	."LEFT JOIN OPL_pgfile_problem AS pgprob ON pgprob.pgfile_id=pg.pgfile_id "
	."LEFT JOIN OPL_problem AS prob ON prob.problem_id=pgprob.problem_id "
	."LEFT JOIN OPL_section AS sect ON sect.section_id=prob.section_id "
	."LEFT JOIN OPL_chapter AS ch ON ch.chapter_id=sect.chapter_id "
	."LEFT JOIN OPL_textbook AS text ON text.textbook_id=ch.textbook_id ";

my $results = $dbh->selectall_arrayref("select * from OPL_textbook ORDER BY title;");

my @textbooks=map { {textbook_id=>$_->[0],title=>$_->[1],edition=>$_->[2],
		author=>$_->[3],publisher=>$_->[4],isbn=>$_->[5],pubdate=>$_->[6]}} @{$results};

my $i =0; ## index to alert user the length of the build

print "Building the Textbook Library Tree\n";
print "There are ". $#textbooks ." textbooks to process.\n";

for my $textbook (@textbooks){
	$i++;
	printf("%3d",$i);
	print("\n") if ($i %10==0);

	my $results = $dbh->selectall_arrayref("select ch.chapter_id,ch.name,ch.number "
		. " from OPL_chapter AS ch JOIN OPL_textbook AS text ON ch.textbook_id=text.textbook_id "
		. " WHERE text.textbook_id='" . $textbook->{textbook_id} . "' ORDER BY ch.number;");

	my @chapters=map { {chapter_id=>$_->[0],name=>$_->[1],number=>$_->[2]}} @{$results};

	for my $chapter (@chapters){

		my $results = $dbh->selectall_arrayref("select sect.section_id,sect.name,sect.number "
			. "FROM OPL_chapter AS ch "
			. "LEFT JOIN OPL_textbook AS text ON ch.textbook_id=text.textbook_id "
			. "LEFT JOIN OPL_section AS sect ON sect.chapter_id = ch.chapter_id "
			. "WHERE text.textbook_id='" .$textbook->{textbook_id}. "' AND "
			. "ch.chapter_id='".$chapter->{chapter_id}."' ORDER BY sect.number;");


		my @sections = map { {section_id=>$_->[0],name=>$_->[1],number=>$_->[2]}} @{$results};

		for my $section (@sections){

	   		my $whereClause ="WHERE sect.section_id='". $section->{section_id} 
	   			."' AND ch.chapter_id='". $chapter->{chapter_id}."' AND "
	   				."text.textbook_id='".$textbook->{textbook_id}."'";

			my $sth = $dbh->prepare($selectClause.$whereClause);
			$sth->execute;
			$section->{num_probs}=$sth->rows;

		}
		my $whereClause ="WHERE ch.chapter_id='". $chapter->{chapter_id}."' AND "
   				."text.textbook_id='".$textbook->{textbook_id}."'";

		my $sth = $dbh->prepare($selectClause.$whereClause);
		$sth->execute;
		$chapter->{num_probs}=$sth->rows;

		$chapter->{sections}=\@sections;
	
	}
	my $whereClause ="WHERE text.textbook_id='".$textbook->{textbook_id}."'";

	my $sth = $dbh->prepare($selectClause.$whereClause);
	$sth->execute;
	$textbook->{num_probs}=$sth->rows;

	$textbook->{chapters}=\@chapters;
}
$dbh->disconnect;

my $webwork_htdocs = $ce->{webwork_dir}."/htdocs";
my $file = "$webwork_htdocs/DATA/textbook-tree.json";

# use a variable for the file handle
my $OUTFILE;

# use the three arguments version of open
# and check for errors
open $OUTFILE, '>', $file  or die "Cannot open $file";

# you can check for errors (e.g., if after opening the disk gets full)
print { $OUTFILE } to_json(\@textbooks,{pretty=>1}) or die "Cannot write to $file";

# check for errors
close $OUTFILE or die "Cannot close $file";


print "Wrote Library Tree to $file\n";

