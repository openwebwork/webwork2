################################################################################
# WeBWorK Online Homework Delivery System
# Copyright <A9> 2000-2004 The WeBWorK Project, http://openwebwork.sf.net/
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

package WeBWorK::Utils::ListingDB;

use strict;
use DBI;

use constant LIBRARY_STRUCTURE => {
	textbook => { select => 'tbk.textbook_id,tbk.title,tbk.author,tbk.edition',
	name => 'library_textbook', where => 'tbk.textbook_id'},
	textchapter => { select => 'tc.name', name=>'library_textchapter',
	where => 'tc.name'},
	textsection => { select => 'ts.name', name=>'library_textsection',
	where => 'ts.name'},
	problem => { select => 'prob.name' },
	};

BEGIN
{
	require Exporter;
	use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	
	$VERSION		=1.0;
	@ISA		=qw(Exporter);
	@EXPORT	=qw(
	&createListing &updateListing &deleteListing &getAllChapters
	&getAllSections &searchListings &getAllListings &getSectionListings
	&getAllDBsubjects &getAllDBchapters &getAllDBsections &getDBTextbooks
	&getDBListings &countDBListings
	);
	%EXPORT_TAGS		=();
	@EXPORT_OK		=qw();
}
use vars @EXPORT_OK;


sub getDB {
	my $ce = shift;
	my $dbinfo = $ce->{problemLibrary};
	my $dbh = DBI->connect_cached("dbi:mysql:$dbinfo->{sourceSQL}", 
				  $dbinfo->{userSQL}, $dbinfo->{passwordSQL});
	die "Cannot connect to problem library database" unless $dbh;
	return($dbh);
}

=item kwtidy($s) and keywordcleaner($s)
Both take a string and perform utility functions related to keywords.
keywordcleaner splits a string, and uses kwtidy to regularize punctuation
and case for an individual entry.
                                                                                
=cut                                                                            

sub kwtidy {
        my $s = shift;
        $s =~ s/\'//g;
        $s =~ s/\"//g;
        $s =~ s/\#//g;
        $s = lc($s);
        return($s);
}

sub keywordCleaner {
        my $string = shift;
        my @spl1 = split /\s*,\s*/, $string;
        my @spl2 = map(kwtidy($_), @spl1);
        return(@spl2);
}

sub makeKeywordWhere {
	my $kwstring = shift;
	my @kwlist = keywordCleaner($kwstring);
	@kwlist = map { "kw.keyword = \"$_\"" } @kwlist;
	my $where = join(" OR ", @kwlist);
	return "AND ( $where )";
}


=item getDBTextbooks($r)                                                    
Returns textbook dependent entries.
                                                                                
$r is a Apache request object so we can extract whatever parameters we want

$thing is a string of either 'textbook', 'textchapter', or 'textsection' to
specify what to return.

If we are to return textbooks, then return an array of textbook names
consistent with the DB subject, chapter, section selected.

=cut                                                                            

sub getDBTextbooks {
	my $r = shift;
	my $thing = shift || 'textbook';
	my $dbh = getDB($r->ce);
	my $extrawhere = '';
	# Handle DB* restrictions
	my $subj = $r->param('library_subjects') || "";
	my $chap = $r->param('library_chapters') || "";
	my $sec = $r->param('library_sections') || "";
	if($subj) {
		$subj =~ s/'/\\'/g;
		$extrawhere .= " AND t.name = \'$subj\'\n";
	}
	if($chap) {
		$chap =~ s/'/\\'/g;
		$extrawhere .= " AND c.name = \'$chap\' AND c.DBsubject_id=t.DBsubject_id\n";
	}
	if($sec) {
		$sec =~ s/'/\\'/g;
		$extrawhere .= " AND s.name = \'$sec\' AND s.DBchapter_id = c.DBchapter_id AND s.DBsection_id=pgf.DBsection_id";
	}
	my $textextrawhere = '';
	my $textid = $r->param('library_textbook') || '';
	if($textid and $thing ne 'textbook') {
		$textextrawhere .= " AND tbk.textbook_id=\"$textid\" ";
	} else {
		return([]) if($thing ne 'textbook');
	}

	my $textchap = $r->param('library_textchapter') || '';
	if($textchap and $thing eq 'textsection') {
		$textextrawhere .= " AND tc.name=\"$textchap\" ";
	} else {
		return([]) if($thing eq 'textsection');
	}

	my $selectwhat = LIBRARY_STRUCTURE->{$thing}{select};
	
	my $query = "SELECT DISTINCT $selectwhat
          FROM textbook tbk, problem prob, pgfile_problem pg, pgfile pgf,
            DBsection s, DBchapter c, DBsubject t, chapter tc, section ts
          WHERE ts.section_id=prob.section_id AND 
            prob.problem_id=pg.problem_id AND
            s.DBchapter_id=c.DBchapter_id AND 
            c.DBsubject_id=t.DBsubject_id AND
            pgf.DBsection_id=s.DBsection_id AND
            pgf.pgfile_id=pg.pgfile_id AND
            ts.chapter_id=tc.chapter_id AND
            tc.textbook_id=tbk.textbook_id
            $extrawhere $textextrawhere ";
	my $text_ref = $dbh->selectall_arrayref($query);
	my @texts = @{$text_ref};
	if( $thing eq 'textbook') {
		@texts = grep { $_->[1] =~ /\S/ } @texts;
		return(\@texts);
	} else {
		@texts = grep { $_->[0] =~ /\S/ } @texts;
		return(\@texts);
	}
}

=item getAllDBsubjects($r)
Returns an array of DBsubject names                                             
                                                                                
$r is the Apache request object
                                                                                
=cut                                                                            

sub getAllDBsubjects {
	my $r = shift;
	my @results=();
	my $row;
	my $query = "SELECT DISTINCT name FROM DBsubject";
	my $dbh = getDB($r->ce);
	my $sth = $dbh->prepare($query);
	$sth->execute();
	while ($row = $sth->fetchrow_array()) {
		push @results, $row;
	}
	return @results;
}


=item getAllDBchapters($r)
Returns an array of DBchapter names                                             
                                                                                
$r is the Apache request object
                                                                                
=cut                                                                            

sub getAllDBchapters {
	my $r = shift;
	my $subject = $r->param('library_subjects');
	return () unless($subject);
	my $dbh = getDB($r->ce);
	my $query = "SELECT DISTINCT c.name FROM DBchapter c, DBsubject t
                 WHERE c.DBsubject_id = t.DBsubject_id AND
                 t.name = \"$subject\"";
	my $all_chaps_ref = $dbh->selectall_arrayref($query);
	my @results = map { $_->[0] } @{$all_chaps_ref};
	return @results;
}

=item getAllDBsections($r)                                            
Returns an array of DBsection names                                             
                                                                                
$r is the Apache request object

=cut                                                                            

sub getAllDBsections {
	my $r = shift;
	my $subject = $r->param('library_subjects');
	return () unless($subject);
	my $chapter = $r->param('library_chapters');
	return () unless($chapter);
	my $dbh = getDB($r->ce);
	my $query = "SELECT DISTINCT s.name FROM DBsection, DBsection s,
                 DBchapter c, DBsubject t
                 WHERE s.DBchapter_id = c.DBchapter_id AND
                 c.DBsubject_id = t.DBsubject_id AND
                 t.name = \"$subject\" AND c.name = \"$chapter\"";
	my $all_sections_ref = $dbh->selectall_arrayref($query);
	my @results = map { $_->[0] } @{$all_sections_ref};
	return @results;
}

=item getDBSectionListings($r)                             
Returns an array of hash references with the keys: path, filename.              
                                                                                
$r is an Apache request object that has all needed data inside of it

Here, we search on all known fields out of r
                                                                                
=cut                                                                            

sub getDBListings {
	my $r = shift;
	my $amcounter = shift;
	my $ce = $r->ce;
	my $subj = $r->param('library_subjects') || "";
	my $chap = $r->param('library_chapters') || "";
	my $sec = $r->param('library_sections') || "";
	my $keywords = $r->param('library_keywords') || "";
	my ($kw1, $kw2) = ('','');
	if($keywords) {
		$kw1 = ", keyword kw, pgfile_keyword pgkey";
		$kw2 = " AND kw.keyword_id=pgkey.keyword_id AND
			 pgkey.pgfile_id=pgf.pgfile_id ". 
			makeKeywordWhere($keywords)
			;
	}

	my $dbh = getDB($ce);

	my $extrawhere = '';
	if($subj) {
		$subj =~ s/'/\\'/g;
		$extrawhere .= " AND dbsj.name=\"$subj\" ";
	}
	if($chap) {
		$chap =~ s/'/\\'/g;
		$extrawhere .= " AND dbc.name=\"$chap\" ";
	}
	if($sec) {
		$sec =~ s/'/\\'/g;
		$extrawhere .= " AND dbsc.name=\"$sec\" ";
	}
	my $textextrawhere = '';
	for my $j (qw( textbook textchapter textsection )) {
		my $foo = $r->param(LIBRARY_STRUCTURE->{$j}{name}) || '';
		if($foo) {
			$foo =~ s/'/\\'/g;
			$textextrawhere .= " AND ".LIBRARY_STRUCTURE->{$j}{where}."=\"$foo\" ";
		}
	}

	my $selectwhat = 'DISTINCT pgf.pgfile_id';
	$selectwhat = 'COUNT(' . $selectwhat . ')' if ($amcounter);

	my $query = "SELECT $selectwhat from pgfile pgf, 
         DBsection dbsc, DBchapter dbc, DBsubject dbsj, pgfile_problem pgp,
         problem prob, textbook tbk , chapter tc, section ts $kw1
        WHERE dbsj.DBsubject_id = dbc.DBsubject_id AND
              dbc.DBchapter_id = dbsc.DBchapter_id AND
              dbsc.DBsection_id = pgf.DBsection_id AND
              pgf.pgfile_id = pgp.pgfile_id AND
              pgp.problem_id = prob.problem_id AND
              tc.textbook_id = tbk.textbook_id AND
              ts.chapter_id = tc.chapter_id AND
              prob.section_id = ts.section_id \n $extrawhere \n $textextrawhere
              $kw2";
#$query =~ s/\n/ /g;
#warn $query;
	my $pg_id_ref = $dbh->selectall_arrayref($query);
	my @pg_ids = map { $_->[0] } @{$pg_id_ref};
	if($amcounter) {
		return(@pg_ids[0]);
	}
	my @results=();
	for my $pgid (@pg_ids) {
		$query = "SELECT path, filename FROM pgfile pgf, path p 
          WHERE p.path_id = pgf.path_id AND pgf.pgfile_id=\"$pgid\"";
		my $row = $dbh->selectrow_arrayref($query);
		push @results, {'path' => $row->[0], 'filename' => $row->[1] };
		
	}
	return @results;
}

sub countDBListings {
	my $r = shift;
	return (getDBListings($r,1));
}

##############################################################################
# input expected: keywords,<keywords>,chapter,<chapter>,section,<section>,path,<path>,filename,<filename>,author,<author>,instituition,<instituition>,history,<history>
sub createListing {
	my $ce = shift;
	my %listing_data = @_; 
	my $classify_id;
	my $dbh = getDB($ce);
	#	my $dbh = WeBWorK::ProblemLibrary::DB::getDB();
	my $query = "INSERT INTO classify
		(filename,chapter,section,keywords)
		VALUES
		($listing_data{filename},$listing_data{chapter},$listing_data{section},$listing_data{keywords})";
	$dbh->do($query);	 #TODO: watch out for comma delimited keywords, sections, chapters!

	$query = "SELECT id FROM classify WHERE filename = $listing_data{filename}";
	my $sth = $dbh->prepare($query);
	$sth->execute();
	if ($sth->rows())
	{
		($classify_id) = $sth->fetchrow_array;
	}
	else
	{
		#print STDERR "ListingDB::createListingPGfiles: $listing_data{filename} failed insert into classify table";
		return 0;
	};

	$query = "INSERT INTO pgfiles
   (
   classify_id,
   path,
   author,
   institution,
   history
   )
   VALUES
  (
   $classify_id,
   $listing_data{path},
   $listing_data{author},
   $listing_data{institution},
   $listing_data{history}
   )";
	
	$dbh->do($query);
	return 1;
}

##############################################################################
# input expected any pair of: keywords,<keywords data>,chapter,<chapter data>,section,<section data>,filename,<filename data>,author,<author data>,instituition,<instituition data>
# returns an array of hash references
sub searchListings {
	my $ce = shift;
	my %searchterms = @_;
	#print STDERR "ListingDB::searchListings  input array @_\n";
	my @results;
	my ($row,$key);
	my $dbh = getDB($ce);
	my $query = "SELECT c.filename, p.path
		FROM classify c, pgfiles p
		WHERE c.id = p.classify_id";
	foreach $key (keys %searchterms) {
		$query .= " AND c.$key = $searchterms{$key}";
	};
	my $sth = $dbh->prepare($query);
	$sth->execute();
	if ($sth->rows())
	{
		while (1)
		{
			$row = $sth->fetchrow_hashref();
			if (!defined($row))
			{
				last;
			}
			else
			{
				#print STDERR "ListingDB::searchListings(): found $row->{id}\n";
				my $listing = $row;
				push @results, $listing;
			}
		}
	}
	return @results;
}
##############################################################################
# returns a list of chapters
sub getAllChapters {
	#print STDERR "ListingDB::getAllChapters\n";
	my $ce = shift;
	my @results=();
	my ($row,$listing);
	my $query = "SELECT DISTINCT chapter FROM classify";
	my $dbh = getDB($ce);
	my $sth = $dbh->prepare($query);
	$sth->execute();
	while (1)
	{
		$row = $sth->fetchrow_array;
		if (!defined($row))
		{
			last;
		}
		else
		{
			my $listing = $row;
			push @results, $listing;
			#print STDERR "ListingDB::getAllChapters $listing\n";
		}
	}
	return @results;
}
##############################################################################
# input chapter
# returns a list of sections
sub getAllSections {
	#print STDERR "ListingDB::getAllSections\n";
	my $ce = shift;
	my $chapter = shift;
	my @results=();
	my ($row,$listing);
	my $query = "SELECT DISTINCT section FROM classify
				WHERE chapter = \'$chapter\'";
	my $dbh = getDB($ce);
	my $sth = $dbh->prepare($query);
	$sth->execute();
	while (1)
	{
		$row = $sth->fetchrow_array;
		if (!defined($row))
		{
			last;
		}
		else
		{
			my $listing = $row;
			push @results, $listing;
			#print STDERR "ListingDB::getAllSections $listing\n";
		}
	}
	return @results;
}

##############################################################################
# returns an array of hash references
sub getAllListings {
	#print STDERR "ListingDB::getAllListings\n";
	my $ce = shift;
	my @results;
	my ($row,$key);
	my $dbh = getDB($ce);
	my $query = "SELECT c.*, p.path
			FROM classify c, pgfiles p
			WHERE c.pgfiles_id = p.pgfiles_id";
	my $sth = $dbh->prepare($query);
	$sth->execute();
	while (1)
	{
		$row = $sth->fetchrow_hashref();
		last if (!defined($row));
		my $listing = $row;
		push @results, $listing;
		#print STDERR "ListingDB::getAllListings $listing\n";
	}
	return @results;
}
##############################################################################
# input chapter, section
# returns an array of hash references.
# if section is omitted, get all from the chapter
sub getSectionListings	{
	#print STDERR "ListingDB::getSectionListings(chapter,section)\n";
	my $r = shift;
	my $ce = $r->ce;
	my $version = $ce->{problemLibrary}->{version} || 1;
	if($version == 2) { return(getDBListings($r, 0))}
	my $subj = $r->param('library_subjects') || "";
	my $chap = $r->param('library_chapters') || "";
	my $sec = $r->param('library_sections') || "";

	my $chapstring = '';
	if($chap) {
		$chap =~ s/'/\\'/g;
		$chapstring = " c.chapter = \'$chap\' AND ";
	}
	my $secstring = '';
	if($sec) {
		$sec =~ s/'/\\'/g;
		$secstring = " c.section = \'$sec\' AND ";
	}

	my @results; #returned
	my $query = "SELECT c.*, p.path
	FROM classify c, pgfiles p
	WHERE $chapstring $secstring c.pgfiles_id = p.pgfiles_id";
	my $dbh = getDB($ce);
	my $sth = $dbh->prepare($query);
	
	$sth->execute();
	while (1)
	{
		my $row = $sth->fetchrow_hashref();
		if (!defined($row))
		{
			last;
		}
		else
		{
			push @results, $row;
			#print STDERR "ListingDB::getSectionListings $row\n";
		}
	}
	return @results;
}

###############################################################################
# INPUT:
#  listing id number
# RETURN:
#  1 = all ok
#
# not implemented yet
sub deleteListing {
	my $ce = shift;
	my $listing_id = shift;
	#print STDERR "ListingDB::deleteListing(): listing == '$listing_id'\n";

	my $dbh = getDB($ce);

	return undef;
}

##############################################################################
1;

__END__

=head1 DESCRIPTION

This module provides access to the database of classify in the
system. This includes the filenames, along with the table of
search terms.

=head1 FUNCTION REFERENCE

=over 4

=item $result = createListing( %listing_data );

Creates a new listing populated with data from %listing_data. On
success, 1 is returned, 0 is returned on failure. The %listing_data
hash has the following format:
=cut

=back

=head1 AUTHOR

Written by Bill Ziemer.
Modified by John Jones.

=cut


##############################################################################
# end of ListingDB.pm
##############################################################################
