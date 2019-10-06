################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/ListingDB.pm,v 1.19 2007/08/13 22:59:59 sh002i Exp $
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
use WeBWorK::Utils qw(sortByName);
use WeBWorK::Utils::Tags;
use File::Basename;
use WeBWorK::Debug;

use constant LIBRARY_STRUCTURE => {
	textbook => { select => 'tbk.textbook_id,tbk.title,tbk.author,tbk.edition',
	name => 'library_textbook', where => 'tbk.textbook_id'},
	textchapter => { select => 'tc.number,tc.name', name=>'library_textchapter',
	where => 'tc.name'},
	textsection => { select => 'ts.number,ts.name', name=>'library_textsection',
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
	&getDBListings &countDBListings &getTables &getDBextras
	);
	%EXPORT_TAGS		=();
	@EXPORT_OK		=qw();
}
use vars @EXPORT_OK;

my %OPLtables = (
 dbsubject => 'OPL_DBsubject',
 dbchapter => 'OPL_DBchapter',
 dbsection => 'OPL_DBsection',
 author => 'OPL_author',
 path => 'OPL_path',
 pgfile => 'OPL_pgfile',
 keyword => 'OPL_keyword',
 pgfile_keyword => 'OPL_pgfile_keyword',
 textbook => 'OPL_textbook',
 chapter => 'OPL_chapter',
 section => 'OPL_section',
 problem => 'OPL_problem',
 morelt => 'OPL_morelt',
 pgfile_problem => 'OPL_pgfile_problem',
);


my %NPLtables = (
 dbsubject => 'NPL-DBsubject',
 dbchapter => 'NPL-DBchapter',
 dbsection => 'NPL-DBsection',
 author => 'NPL-author',
 path => 'NPL-path',
 pgfile => 'NPL-pgfile',
 keyword => 'NPL-keyword',
 pgfile_keyword => 'NPL-pgfile-keyword',
 textbook => 'NPL-textbook',
 chapter => 'NPL-chapter',
 section => 'NPL-section',
 problem => 'NPL-problem',
 morelt => 'NPL-morelt',
 pgfile_problem => 'NPL-pgfile-problem',
);


sub getTables {
	my $ce = shift;
	my $libraryRoot = $ce->{problemLibrary}->{root};
	my %tables;

       if($ce->{problemLibrary}->{version} == 2.5) {
		%tables = %OPLtables;
	  } else {
		%tables = %NPLtables;
	  }
	return %tables;
}

sub getDB {
	my $ce = shift;
	my $dbh = DBI->connect(
		$ce->{problemLibrary_db}->{dbsource},
		$ce->{problemLibrary_db}->{user},
		$ce->{problemLibrary_db}->{passwd},
		{
			PrintError => 0,
			RaiseError => 1,
		},
	);
	die "Cannot connect to problem library database" unless $dbh;
	return($dbh);
}

=item getProblemTags($path) and setProblemTags($path, $subj, $chap, $sect)
Get and set tags using full path and Tagging module
                                                                                
=cut

sub getProblemTags {
	my $path = shift;
	my $tags = WeBWorK::Utils::Tags->new($path);
	my %thash = ();
	for my $j ('DBchapter', 'DBsection', 'DBsubject', 'Level', 'Status') {
		$thash{$j} = $tags->{$j};
	}
	return \%thash;
}

sub setProblemTags {
	my $path = shift;
        if (-w $path) {
		my $subj= shift;
		my $chap = shift;
		my $sect = shift;
		my $level = shift;
		my $status = shift || 0;
		my $tags = WeBWorK::Utils::Tags->new($path);
		$tags->settag('DBsubject', $subj, 1);
		$tags->settag('DBchapter', $chap, 1);
		$tags->settag('DBsection', $sect, 1);
		$tags->settag('Level', $level, 1);
		$tags->settag('Status', $status, 1);
		eval {
			$tags->write();
			1;
		} or do {
			return [0, "Problem writing file"];
		};
		return [1, "Tags written"];
        } else {
		return [0, "Do not have permission to write to the problem file"];
	}
}

=item kwtidy($s) and keywordcleaner($s)
Both take a string and perform utility functions related to keywords.
keywordcleaner splits a string, and uses kwtidy to regularize punctuation
and case for an individual entry.
                                                                                
=cut                                                                            

sub kwtidy {
	my $s = shift;
	$s =~ s/\W//g;
	$s =~ s/_//g;
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
#	@kwlist = map { "kw.keyword = \"$_\"" } @kwlist;
	my @kwlistqm = map { "kw.keyword = ? " } @kwlist;
	my $where = join(" OR ", @kwlistqm);
	return "AND ( $where )", @kwlist;
}

=item getDBextras($path)
Get flags for whether a pg file uses Math Objects, and if it is static

$r is a Apache request object so we can get the right table names

$path is the path to the file

Out put is an array reference: [MO, static]

=cut

sub getDBextras {
	my $r = shift;
	my $path = shift;
	my %tables = getTables($r->ce);
	my $dbh = getDB($r->ce);
	my ($mo, $static)=(0,0);

	$path =~ s|^Library/||;
	my $filename = basename $path;
	$path = dirname $path;
	my $query = "SELECT pgfile.MO, pgfile.static FROM `$tables{pgfile}` pgfile, `$tables{path}` p WHERE p.path=\"$path\" AND pgfile.path_id=p.path_id AND pgfile.filename=\"$filename\"";
	my @res = $dbh->selectrow_array($query);
	if(@res) {
		$mo = $res[0];
		$static = $res[1];
	}

	return [$mo, $static];
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
	my %tables = getTables($r->ce);
	my $extrawhere = '';
	# Handle DB* restrictions
	my @search_params=();
	my $subj = $r->param('library_subjects') || "";
	my $chap = $r->param('library_chapters') || "";
	my $sec = $r->param('library_sections') || "";
	if($subj) {
		$subj =~ s/'/\\'/g;
		$extrawhere .= " AND t.name = ?\n";
		push @search_params, $subj;
	}
	if($chap) {
		$chap =~ s/'/\\'/g;
		$extrawhere .= " AND c.name = ? AND c.DBsubject_id=t.DBsubject_id\n";
		push @search_params, $chap;
	}
	if($sec) {
		$sec =~ s/'/\\'/g;
		$extrawhere .= " AND s.name = ? AND s.DBchapter_id = c.DBchapter_id AND s.DBsection_id=pgf.DBsection_id";
		push @search_params, $sec;
	}
	my $textextrawhere = '';
	my $textid = $r->param('library_textbook') || '';
	if($textid and $thing ne 'textbook') {
		$textextrawhere .= " AND tbk.textbook_id= ? ";
		push @search_params, $textid;
	} else {
		return([]) if($thing ne 'textbook');
	}

	my $textchap = $r->param('library_textchapter') || '';
	$textchap =~ s/^\s*\d+\.\s*//;
	if($textchap and $thing eq 'textsection') {
		$textextrawhere .= " AND tc.name= ? ";
		push @search_params, $textchap;
	} else {
		return([]) if($thing eq 'textsection');
	}

	my $selectwhat = LIBRARY_STRUCTURE->{$thing}{select};
	
# 	my $query = "SELECT DISTINCT $selectwhat
#           FROM `$tables{textbook}` tbk, `$tables{problem}` prob, 
# 			`$tables{pgfile_problem}` pg, `$tables{pgfile}` pgf,
#             `$tables{dbsection}` s, `$tables{dbchapter}` c, `$tables{dbsubject}` t,
# 			`$tables{chapter}` tc, `$tables{section}` ts
#           WHERE ts.section_id=prob.section_id AND 
#             prob.problem_id=pg.problem_id AND
#             s.DBchapter_id=c.DBchapter_id AND 
#             c.DBsubject_id=t.DBsubject_id AND
#             pgf.DBsection_id=s.DBsection_id AND
#             pgf.pgfile_id=pg.pgfile_id AND
#             ts.chapter_id=tc.chapter_id AND
#             tc.textbook_id=tbk.textbook_id
#             $extrawhere $textextrawhere ";
	my $query = "SELECT DISTINCT $selectwhat
          FROM `$tables{textbook}` tbk, `$tables{problem}` prob, 
			`$tables{pgfile_problem}` pg, `$tables{pgfile}` pgf,
            `$tables{dbsection}` s, `$tables{dbchapter}` c, `$tables{dbsubject}` t,
			`$tables{chapter}` tc, `$tables{section}` ts
          WHERE ts.section_id=prob.section_id AND 
            prob.problem_id=pg.problem_id AND
            s.DBchapter_id=c.DBchapter_id AND 
            c.DBsubject_id=t.DBsubject_id AND
            pgf.DBsection_id=s.DBsection_id AND
            pgf.pgfile_id=pg.pgfile_id AND
            ts.chapter_id=tc.chapter_id AND
            tc.textbook_id=tbk.textbook_id
            $extrawhere $textextrawhere  ";

#$query =~ s/\n/ /g;
#warn "query:", $query;
#warn "params:", join(" | ", @search_params);
#	my $text_ref = $dbh->selectall_arrayref($query);
    my $text_ref = $dbh->selectall_arrayref($query,{},@search_params);  #FIXME

	my @texts = @{$text_ref};
	if( $thing eq 'textbook') {
		@texts = grep { $_->[1] =~ /\S/ } @texts;
		my @sortarray = map { $_->[1] . $_->[2] . $_->[3] } @texts;
		@texts = indirectSortByName( \@sortarray, @texts );
		return(\@texts);
	} else {
		@texts = grep { $_->[1] =~ /\S/ } @texts;
		my @sortarray = map { $_->[0] .". " . $_->[1] } @texts;
		@texts = map { [ $_ ] } @sortarray;
		@texts = indirectSortByName(\@sortarray, @texts);
		return(\@texts);
	}
}

=item getAllDBsubjects($r)
Returns an array of DBsubject names                                             
                                                                                
$r is the Apache request object
                                                                                
=cut                                                                            

sub getAllDBsubjects {
	my $r = shift;
	my %tables = getTables($r->ce);
	my @results=();
	my @row;
	my $query = "SELECT DISTINCT name, DBsubject_id FROM `$tables{dbsubject}` ORDER BY DBsubject_id";
	my $dbh = getDB($r->ce);
	my $sth = $dbh->prepare($query);
	$sth->execute();

	while (@row = $sth->fetchrow_array()) {
		push @results, $row[0];
	}
	# @results = sortByName(undef, @results);
	return @results;
}


=item getAllDBchapters($r)
Returns an array of DBchapter names                                             
                                                                                
$r is the Apache request object
                                                                                
=cut                                                                            

sub getAllDBchapters {
	my $r = shift;
	my %tables = getTables($r->ce);
	my $subject = $r->param('library_subjects');
	return () unless($subject);
	my $dbh = getDB($r->ce);
# 	my $query = "SELECT DISTINCT c.name, c.DBchapter_id 
#                                 FROM `$tables{dbchapter}` c, 
# 				`$tables{dbsubject}` t
#                  WHERE c.DBsubject_id = t.DBsubject_id AND
#                  t.name = \"$subject\" ORDER BY c.DBchapter_id";
# 	my $all_chaps_ref = $dbh->selectall_arrayref($query);
	my $query = "SELECT DISTINCT c.name, c.DBchapter_id 
                                FROM `$tables{dbchapter}` c, 
				`$tables{dbsubject}` t
                 WHERE c.DBsubject_id = t.DBsubject_id AND
                 t.name = ? ORDER BY c.DBchapter_id";
	my $all_chaps_ref = $dbh->selectall_arrayref($query, {},$subject);
 
 	my @results = map { $_->[0] } @{$all_chaps_ref};
	#@results = sortByName(undef, @results);
	return @results;
}

=item getAllDBsections($r)                                            
Returns an array of DBsection names                                             
                                                                                
$r is the Apache request object

=cut                                                                            

sub getAllDBsections {
	my $r = shift;
	my %tables = getTables($r->ce);
	my $subject = $r->param('library_subjects');
	return () unless($subject);
	my $chapter = $r->param('library_chapters');
	return () unless($chapter);
	my $dbh = getDB($r->ce);
# 	my $query = "SELECT DISTINCT s.name, s.DBsection_id 
#                  FROM `$tables{dbsection}` s,
#                  `$tables{dbchapter}` c, `$tables{dbsubject}` t
#                  WHERE s.DBchapter_id = c.DBchapter_id AND
#                  c.DBsubject_id = t.DBsubject_id AND
#                  t.name = \"$subject\" AND c.name = \"$chapter\" ORDER BY s.DBsection_id";
# 	my $all_sections_ref = $dbh->selectall_arrayref($query);
	my $query = "SELECT DISTINCT s.name, s.DBsection_id 
                 FROM `$tables{dbsection}` s,
                 `$tables{dbchapter}` c, `$tables{dbsubject}` t
                 WHERE s.DBchapter_id = c.DBchapter_id AND
                 c.DBsubject_id = t.DBsubject_id AND
                 t.name = ? AND c.name = ? ORDER BY s.DBsection_id";
	my $all_sections_ref = $dbh->selectall_arrayref($query, {},$subject, $chapter);

	my @results = map { $_->[0] } @{$all_sections_ref};
	#@results = sortByName(undef, @results);
	return @results;
}

=item getDBSectionListings($r)                             
Returns an array of hash references with the keys: path, filename.              
                                                                                
$r is an Apache request object that has all needed data inside of it

Here, we search on all known fields out of r
                                                                                
=cut

=item 

=cut

sub getDBListings {
	my $r = shift;
	my $amcounter = shift;  # 0-1 if I am a counter.
	my $ce = $r->ce;
	my %tables = getTables($ce);
	my $subj = $r->param('library_subjects') || "";
	my $chap = $r->param('library_chapters') || "";
	my $sec = $r->param('library_sections') || "";
	
	# Make sure these strings are internally encoded in UTF-8
	utf8::upgrade($subj);
	utf8::upgrade($chap);
	utf8::upgrade($sec);

	my $keywords = $r->param('library_keywords') || "";
	# Next could be an array, an array reference, or nothing
	my @levels = $r->param('level');
	if(scalar(@levels) == 1 and ref($levels[0]) eq 'ARRAY') {
		@levels = @{$levels[0]};
	}
	@levels = grep { defined($_) && m/\S/ } @levels;
	my ($kw1, $kw2) = ('','');
	my $keywordstring;
	my @keyword_params;
	if($keywords) {
		($keywordstring, @keyword_params) = makeKeywordWhere($keywords) ;
		$kw1 = ", `$tables{keyword}` kw, `$tables{pgfile_keyword}` pgkey";
		$kw2 = " AND kw.keyword_id=pgkey.keyword_id AND
			 pgkey.pgfile_id=pgf.pgfile_id $keywordstring"; 
#			makeKeywordWhere($keywords) ;
	}

	my $dbh = getDB($ce);

	my $extrawhere = '';
	my @select_parameters=();
	if($subj) {
#		$subj =~ s/'/\\'/g;
#		$extrawhere .= " AND dbsj.name=\"$subj\" ";
		$extrawhere .= " AND dbsj.name= ? ";
		push @select_parameters, $subj;
	}
	if($chap) {
#		$chap =~ s/'/\\'/g;
#		$extrawhere .= " AND dbc.name=\"$chap\" ";
		$extrawhere .= " AND dbc.name= ? ";
		push @select_parameters, $chap;
	}
	if($sec) {
#		$sec =~ s/'/\\'/g;
#		$extrawhere .= " AND dbsc.name=\"$sec\" ";
		$extrawhere .= " AND dbsc.name= ? ";
		push @select_parameters, $sec;
	}
	if(scalar(@levels)) {
#		$extrawhere .= " AND pgf.level IN (".join(',', @levels).") ";
		$extrawhere .= " AND pgf.level IN ( ? ) ";
		push @select_parameters, join(',', @levels);
	}
	my $textextrawhere = '';
    my $haveTextInfo=0;
    my @textInfo_parameters=();
	for my $j (qw( textbook textchapter textsection )) {
		my $foo = $r->param(LIBRARY_STRUCTURE->{$j}{name}) || '';
		$foo =~ s/^\s*\d+\.\s*//;
		if($foo) {
            $haveTextInfo=1;
			$foo =~ s/'/\\'/g;
			$textextrawhere .= " AND ".LIBRARY_STRUCTURE->{$j}{where}."= ? ";
			push @textInfo_parameters, $foo;
		}
	}

	my $selectwhat = 'DISTINCT pgf.pgfile_id';
	$selectwhat = 'COUNT(' . $selectwhat . ')' if ($amcounter);

# 	my $query = "SELECT $selectwhat from `$tables{pgfile}` pgf, 
#          `$tables{dbsection}` dbsc, `$tables{dbchapter}` dbc, `$tables{dbsubject}` dbsj $kw1
#         WHERE dbsj.DBsubject_id = dbc.DBsubject_id AND
#               dbc.DBchapter_id = dbsc.DBchapter_id AND
#               dbsc.DBsection_id = pgf.DBsection_id 
#               \n $extrawhere 
#               $kw2";

	my $pg_id_ref;
	
	$dbh->do(qq{SET NAMES 'utf8mb4';}) if $ce->{ENABLE_UTF8MB};
	if($haveTextInfo) {
		my $query = "SELECT $selectwhat from `$tables{pgfile}` pgf, 
			`$tables{dbsection}` dbsc, `$tables{dbchapter}` dbc, `$tables{dbsubject}` dbsj,
			`$tables{pgfile_problem}` pgp, `$tables{problem}` prob, `$tables{textbook}` tbk ,
			`$tables{chapter}` tc, `$tables{section}` ts $kw1
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
		#warn "text info: ", $query;
		#warn "params: ", join(" | ",@select_parameters, @textInfo_parameters,@keyword_params);
		
		$pg_id_ref = $dbh->selectall_arrayref($query, {},@select_parameters, @textInfo_parameters, @keyword_params);

     } else {
		my $query = "SELECT $selectwhat from `$tables{pgfile}` pgf, 
			 `$tables{dbsection}` dbsc, `$tables{dbchapter}` dbc, `$tables{dbsubject}` dbsj $kw1
			WHERE dbsj.DBsubject_id = dbc.DBsubject_id AND
				  dbc.DBchapter_id = dbsc.DBchapter_id AND
				  dbsc.DBsection_id = pgf.DBsection_id 
				  \n $extrawhere 
				  $kw2";
				  
		#$query =~ s/\n/ /g;
		#warn "no text info: ", $query;
		#warn "params: ", join(" | ",@select_parameters,@keyword_params);

     	$pg_id_ref = $dbh->selectall_arrayref($query,{},@select_parameters,@keyword_params);
     	#$query =~ s/\n/ /g;

     }

	my @pg_ids = map { $_->[0] } @{$pg_id_ref};
	if($amcounter) {
		return(@pg_ids[0]);
	}
	my @results=();
	for my $pgid (@pg_ids) {
# 		$query = "SELECT path, filename, morelt_id, pgfile_id, static, MO FROM `$tables{pgfile}` pgf, `$tables{path}` p 
#           WHERE p.path_id = pgf.path_id AND pgf.pgfile_id=\"$pgid\"";
# 		my $row = $dbh->selectrow_arrayref($query);
		my $query = "SELECT path, filename, morelt_id, pgfile_id, static, MO FROM `$tables{pgfile}` pgf, `$tables{path}` p 
          WHERE p.path_id = pgf.path_id AND pgf.pgfile_id= ? ";
		my $row = $dbh->selectrow_arrayref($query,{},$pgid);

		push @results, {'path' => $row->[0], 'filename' => $row->[1], 'morelt' => $row->[2], 'pgid'=> $row->[3], 'static' => $row->[4], 'MO' => $row->[5] };
		
	}
	return @results;
}

sub countDBListings {
	my $r = shift;
	return (getDBListings($r,1));
}

sub getMLTleader {
	my $r = shift;
	my $mltid = shift;
	my %tables = getTables($r->ce);
	my $dbh = getDB($r->ce);
	my $query = "SELECT leader FROM `$tables{morelt}` WHERE morelt_id=\"$mltid\"";
	my $row = $dbh->selectrow_arrayref($query);
	return $row->[0];
}

##############################################################################
# input expected: keywords,<keywords>,chapter,<chapter>,section,<section>,path,<path>,filename,<filename>,author,<author>,instituition,<instituition>,history,<history>
#
#
# Warning - this function is out of date (but currently unused)
#

# sub createListing {
# 	my $ce = shift;
# 	my %tables = getTables($ce);
# 	my %listing_data = @_; 
# 	my $classify_id;
# 	my $dbh = getDB($ce);
# 	#	my $dbh = WeBWorK::ProblemLibrary::DB::getDB();
# 	my $query = "INSERT INTO classify
# 		(filename,chapter,section,keywords)
# 		VALUES
# 		($listing_data{filename},$listing_data{chapter},$listing_data{section},$listing_data{keywords})";
# 	$dbh->do($query);	 #TODO: watch out for comma delimited keywords, sections, chapters!
# 
# 	$query = "SELECT id FROM classify WHERE filename = $listing_data{filename}";
# 	my $sth = $dbh->prepare($query);
# 	$sth->execute();
# 	if ($sth->rows())
# 	{
# 		($classify_id) = $sth->fetchrow_array;
# 	}
# 	else
# 	{
# 		#print STDERR "ListingDB::createListingPGfiles: $listing_data{filename} failed insert into classify table";
# 		return 0;
# 	};
# 
# 	$query = "INSERT INTO pgfiles
#    (
#    classify_id,
#    path,
#    author,
#    institution,
#    history
#    )
#    VALUES
#   (
#    $classify_id,
#    $listing_data{path},
#    $listing_data{author},
#    $listing_data{institution},
#    $listing_data{history}
#    )";
# 	
# 	$dbh->do($query);
# 	return 1;
# }

##############################################################################
# input expected any pair of: keywords,<keywords data>,chapter,<chapter data>,section,<section data>,filename,<filename data>,author,<author data>,instituition,<instituition data>
# returns an array of hash references
#
# Warning - out of date (and unusued)
#

# sub searchListings {
# 	my $ce = shift;
# 	my %tables = getTables($ce);
# 	my %searchterms = @_;
# 	#print STDERR "ListingDB::searchListings  input array @_\n";
# 	my @results;
# 	my ($row,$key);
# 	my $dbh = getDB($ce);
# 	my $query = "SELECT c.filename, p.path
# 		FROM classify c, pgfiles p
# 		WHERE c.id = p.classify_id";
# 	foreach $key (keys %searchterms) {
# 		$query .= " AND c.$key = $searchterms{$key}";
# 	};
# 	my $sth = $dbh->prepare($query);
# 	$sth->execute();
# 	if ($sth->rows())
# 	{
# 		while (1)
# 		{
# 			$row = $sth->fetchrow_hashref();
# 			if (!defined($row))
# 			{
# 				last;
# 			}
# 			else
# 			{
# 				#print STDERR "ListingDB::searchListings(): found $row->{id}\n";
# 				my $listing = $row;
# 				push @results, $listing;
# 			}
# 		}
# 	}
# 	return @results;
# }
##############################################################################
# returns a list of chapters
#
# Warning - out of date
#

# sub getAllChapters {
# 	#print STDERR "ListingDB::getAllChapters\n";
# 	my $ce = shift;
# 	my %tables = getTables($ce);
# 	my @results=();
# 	my ($row,$listing);
# 	my $query = "SELECT DISTINCT chapter FROM classify";
# 	my $dbh = getDB($ce);
# 	my $sth = $dbh->prepare($query);
# 	$sth->execute();
# 	while (1)
# 	{
# 		$row = $sth->fetchrow_array;
# 		if (!defined($row))
# 		{
# 			last;
# 		}
# 		else
# 		{
# 			my $listing = $row;
# 			push @results, $listing;
# 			#print STDERR "ListingDB::getAllChapters $listing\n";
# 		}
# 	}
# 	return @results;
# }
##############################################################################
# input chapter
# returns a list of sections
#
# Warning - out of date (and unused)
#

# sub getAllSections {
# 	#print STDERR "ListingDB::getAllSections\n";
# 	my $ce = shift;
# 	my %tables = getTables($ce);
# 	my $chapter = shift;
# 	my @results=();
# 	my ($row,$listing);
# # 	my $query = "SELECT DISTINCT section FROM classify
# # 				WHERE chapter = \'$chapter\'";
# 	my $query = "SELECT DISTINCT section FROM classify
# 				WHERE chapter = ? ";
# 	my $dbh = getDB($ce);
# #	my $sth = $dbh->prepare($query);
# 	my $sth = $dbh->prepare($query, $chapter);
# 
# 	$sth->execute();
# 	while (1)
# 	{
# 		$row = $sth->fetchrow_array;
# 		if (!defined($row))
# 		{
# 			last;
# 		}
# 		else
# 		{
# 			my $listing = $row;
# 			push @results, $listing;
# 			#print STDERR "ListingDB::getAllSections $listing\n";
# 		}
# 	}
# 	return @results;
# }

##############################################################################
# returns an array of hash references
#
# Warning - out of date (and unused)
#

# sub getAllListings {
# 	#print STDERR "ListingDB::getAllListings\n";
# 	my $ce = shift;
# 	my @results;
# 	my ($row,$key);
# 	my $dbh = getDB($ce);
# 	my %tables = getTables($ce);
# 	my $query = "SELECT c.*, p.path
# 			FROM classify c, pgfiles p
# 			WHERE c.pgfiles_id = p.pgfiles_id";
# 	my $sth = $dbh->prepare($query);
# 	$sth->execute();
# 	while (1)
# 	{
# 		$row = $sth->fetchrow_hashref();
# 		last if (!defined($row));
# 		my $listing = $row;
# 		push @results, $listing;
# 		#print STDERR "ListingDB::getAllListings $listing\n";
# 	}
# 	return @results;
# }

##############################################################################
# input chapter, section
# returns an array of hash references.
# if section is omitted, get all from the chapter
sub getSectionListings	{
	#print STDERR "ListingDB::getSectionListings(chapter,section)\n";
	my $r = shift;
	my $ce = $r->ce;
	my $version = $ce->{problemLibrary}->{version} || 1;
	if($version => 2) { return(getDBListings($r, 0))}
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
# 	my $query = "SELECT c.*, p.path
# 	FROM classify c, pgfiles p
# 	WHERE $chapstring $secstring c.pgfiles_id = p.pgfiles_id";
# 	my $dbh = getDB($ce);
# 	my %tables = getTables($ce);
# 	my $sth = $dbh->prepare($query);
# 	
# 	$sth->execute();
    my $query = "SELECT c.*, p.path
	FROM classify c, pgfiles p
	WHERE ? ? c.pgfiles_id = p.pgfiles_id";
	my $dbh = getDB($ce);
	my %tables = getTables($ce);
	my $sth = $dbh->prepare($query);
	
	$sth->execute($chapstring,$secstring);

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
	my %tables = getTables($ce);

	return undef;
}


# Use sortByName($aref, @b) to sort list @b using parallel list @a.
# Here, $aref is a reference to the array @a

sub indirectSortByName {
	my $aref = shift ;
	my @a = @$aref;
	my @b = @_;
	my %pairs ;
	for my $j (1..scalar(@a)) {
		$pairs{$a[$j-1]} = $b[$j-1];
	}
	my @list = sortByName(undef, @a);
	@list = map { $pairs{$_} } @list;
	return(@list);
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
