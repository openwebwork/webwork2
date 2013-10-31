#!/usr/bin/env perl

# This is the script build-library-tree

# This is used to create the file library-tree.json which can be used to load in 
# subject-chapter-section information for the OPL

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

my @textbooks = ();

my $selectString = "";

my $sth = $dbh->prepare("select * from OPL_textbook");
$sth->execute;

while ( my ($textbook_id,$title,$edition,$author,$publisher,$isbn,$pubdate) = $sth->fetchrow_array ) {

	my $sth2 = $dbh->prepare("select ch.chapter_id,ch.textbook_id,ch.number,ch.name,ch.page "
		. " from OPL_chapter AS ch JOIN OPL_textbook AS text ON ch.textbook_id=text.textbook_id "
		. " WHERE text.textbook_id='" . $textbook_id . "' ORDER BY ch.number;");
	$sth2->execute;
	my @chapters = ();

   	while ( my ($chapter_id,$textbook_id,$chapterNumber,$chapterName,$chapterPage) = $sth2->fetchrow_array ) {
	   	


		my $sth3 = $dbh->prepare("select sect.section_id,sect.chapter_id,sect.number,sect.name,sect.page "
			. "FROM OPL_chapter AS ch "
			. "LEFT JOIN OPL_textbook AS text ON ch.textbook_id=text.textbook_id "
			. "LEFT JOIN OPL_section AS sect ON sect.chapter_id = ch.chapter_id "
			. "WHERE text.textbook_id='$textbook_id' AND ch.chapter_id='$chapter_id' ORDER BY sect.number;");

		$sth3->execute;
		my @sections = ();

	   	while ( my ($section_id,$chapter_id,$sectionNumber,$sectionName,$sectionPage) = $sth3->fetchrow_array ) {
	   		push(@sections,{section_id=>$section_id,name=>$sectionName,number=>$sectionNumber});
		}
	   	push(@chapters,{chapter_id=>$chapter_id,name=>$chapterName,number=>$chapterNumber,sections=>\@sections});
	}

	push(@textbooks,{textbook_id=>$textbook_id,title=>$title,edition=>$edition,author=>$author,
					publisher=>$publisher,ISBN=>$isbn,pubdate=>$pubdate,chapters=>\@chapters});


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

