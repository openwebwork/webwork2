################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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
	textbook => {
		select => 'tbk.textbook_id,tbk.title,tbk.author,tbk.edition',
		name   => 'library_textbook',
		where  => 'tbk.textbook_id'
	},
	textchapter => {
		select => 'tc.number,tc.name',
		name   => 'library_textchapter',
		where  => 'tc.name'
	},
	textsection => {
		select => 'ts.number,ts.name',
		name   => 'library_textsection',
		where  => 'ts.name'
	},
	problem => { select => 'prob.name' },
};

BEGIN {
	require Exporter;
	use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

	$VERSION = 1.0;
	@ISA     = qw(Exporter);
	@EXPORT  = qw(
		&deleteListing &getSectionListings &getAllDBsubjects &getAllDBchapters &getAllDBsections &getDBTextbooks
		&getDBListings &countDBListings &getTables &getDBextras
	);
	%EXPORT_TAGS = ();
	@EXPORT_OK   = qw();
}
use vars @EXPORT_OK;

my %OPLtables = (
	dbsubject      => 'OPL_DBsubject',
	dbchapter      => 'OPL_DBchapter',
	dbsection      => 'OPL_DBsection',
	author         => 'OPL_author',
	path           => 'OPL_path',
	pgfile         => 'OPL_pgfile',
	keyword        => 'OPL_keyword',
	pgfile_keyword => 'OPL_pgfile_keyword',
	textbook       => 'OPL_textbook',
	chapter        => 'OPL_chapter',
	section        => 'OPL_section',
	problem        => 'OPL_problem',
	morelt         => 'OPL_morelt',
	pgfile_problem => 'OPL_pgfile_problem',
);

my %NPLtables = (
	dbsubject      => 'NPL-DBsubject',
	dbchapter      => 'NPL-DBchapter',
	dbsection      => 'NPL-DBsection',
	author         => 'NPL-author',
	path           => 'NPL-path',
	pgfile         => 'NPL-pgfile',
	keyword        => 'NPL-keyword',
	pgfile_keyword => 'NPL-pgfile-keyword',
	textbook       => 'NPL-textbook',
	chapter        => 'NPL-chapter',
	section        => 'NPL-section',
	problem        => 'NPL-problem',
	morelt         => 'NPL-morelt',
	pgfile_problem => 'NPL-pgfile-problem',
);

sub getTables {
	my $ce          = shift;
	my $libraryRoot = $ce->{problemLibrary}->{root};
	my %tables;

	if ($ce->{problemLibrary}->{version} == 2.5) {
		%tables = %OPLtables;
	} else {
		%tables = %NPLtables;
	}
	return %tables;
}

sub getDB {
	my $ce  = shift;
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
	return ($dbh);
}

=over

=item getProblemTags($path) and setProblemTags($path, $subj, $chap, $sect)
Get and set tags using full path and Tagging module

=cut

sub getProblemTags {
	my $path  = shift;
	my $tags  = WeBWorK::Utils::Tags->new($path);
	my %thash = ();
	for my $j ('DBchapter', 'DBsection', 'DBsubject', 'Level', 'Status') {
		$thash{$j} = $tags->{$j};
	}
	return \%thash;
}

sub setProblemTags {
	my $path = shift;
	if (-w $path) {
		my $subj   = shift;
		my $chap   = shift;
		my $sect   = shift;
		my $level  = shift;
		my $status = shift || 0;
		my $tags   = WeBWorK::Utils::Tags->new($path);
		$tags->settag('DBsubject', $subj,   1);
		$tags->settag('DBchapter', $chap,   1);
		$tags->settag('DBsection', $sect,   1);
		$tags->settag('Level',     $level,  1);
		$tags->settag('Status',    $status, 1);
		eval {
			$tags->write();
			1;
		} or do {
			return [ 0, "Problem writing file" ];
		};
		return [ 1, "Tags written" ];
	} else {
		return [ 0, "Do not have permission to write to the problem file" ];
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
	return ($s);
}

sub keywordCleaner {
	my $string = shift;
	my @spl1   = split /\s*,\s*/, $string;
	my @spl2   = map(kwtidy($_), @spl1);
	return (@spl2);
}

sub makeKeywordWhere {
	my $kwstring = shift;
	my @kwlist   = keywordCleaner($kwstring);
	#	@kwlist = map { "kw.keyword = \"$_\"" } @kwlist;
	my @kwlistqm = map {"kw.keyword = ? "} @kwlist;
	my $where    = join(" OR ", @kwlistqm);
	return "AND ( $where )", @kwlist;
}

=item getDBextras($path)
Get flags for whether a pg file uses Math Objects, and if it is static

$c is a WeBWorK::Controller object so we can get the right table names

$path is the path to the file

Output is an array reference: [MO, static]

=cut

sub getDBextras {
	my $c      = shift;
	my $path   = shift;
	my %tables = getTables($c->ce);
	my $dbh    = getDB($c->ce);
	my ($mo, $static) = (0, 0);

	$path =~ s|^Library/||;
	my $filename = basename $path;
	$path = dirname $path;
	my $query =
		"SELECT pgfile.MO, pgfile.static FROM `$tables{pgfile}` pgfile, `$tables{path}` p WHERE p.path=\"$path\" AND pgfile.path_id=p.path_id AND pgfile.filename=\"$filename\"";
	my @res = $dbh->selectrow_array($query);
	if (@res) {
		$mo     = $res[0];
		$static = $res[1];
	}

	return [ $mo, $static ];
}

=item getDBTextbooks($c)
Returns textbook dependent entries.

$c is a WeBWorK::Controller object so we can extract whatever parameters we want

$thing is a string of either 'textbook', 'textchapter', or 'textsection' to
specify what to return.

If we are to return textbooks, then return an array of textbook names
consistent with the DB subject, chapter, section selected.

=cut

sub getDBTextbooks {
	my $c          = shift;
	my $thing      = shift || 'textbook';
	my $dbh        = getDB($c->ce);
	my %tables     = getTables($c->ce);
	my $extrawhere = '';
	# Handle DB* restrictions
	my @search_params = ();
	my $subj          = $c->param('library_subjects') || "";
	my $chap          = $c->param('library_chapters') || "";
	my $sec           = $c->param('library_sections') || "";
	if ($subj) {
		$subj =~ s/'/\\'/g;
		$extrawhere .= " AND t.name = ?\n";
		push @search_params, $subj;
	}
	if ($chap) {
		$chap =~ s/'/\\'/g;
		$extrawhere .= " AND c.name = ? AND c.DBsubject_id=t.DBsubject_id\n";
		push @search_params, $chap;
	}
	if ($sec) {
		$sec =~ s/'/\\'/g;
		$extrawhere .= " AND s.name = ? AND s.DBchapter_id = c.DBchapter_id AND s.DBsection_id=pgf.DBsection_id";
		push @search_params, $sec;
	}
	my $textextrawhere = '';
	my $textid         = $c->param('library_textbook') || '';
	if ($textid and $thing ne 'textbook') {
		$textextrawhere .= " AND tbk.textbook_id= ? ";
		push @search_params, $textid;
	} else {
		return ([]) if ($thing ne 'textbook');
	}

	my $textchap = $c->param('library_textchapter') || '';
	$textchap =~ s/^\s*\d+\.\s*//;
	if ($textchap and $thing eq 'textsection') {
		$textextrawhere .= " AND tc.name= ? ";
		push @search_params, $textchap;
	} else {
		return ([]) if ($thing eq 'textsection');
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
	my $text_ref = $dbh->selectall_arrayref($query, {}, @search_params);    #FIXME

	my @texts = @{$text_ref};
	if ($thing eq 'textbook') {
		@texts = grep { $_->[1] =~ /\S/ } @texts;
		my @sortarray = map { $_->[1] . $_->[2] . $_->[3] } @texts;
		@texts = indirectSortByName(\@sortarray, @texts);
		return (\@texts);
	} else {
		@texts = grep { $_->[1] =~ /\S/ } @texts;
		my @sortarray = map { $_->[0] . ". " . $_->[1] } @texts;
		@texts = map { [$_] } @sortarray;
		@texts = indirectSortByName(\@sortarray, @texts);
		return (\@texts);
	}
}

=item getAllDBsubjects($c)
Returns an array of DBsubject names

$c is the WeBWorK::Controller object

=cut

sub getAllDBsubjects {
	my $c       = shift;
	my %tables  = getTables($c->ce);
	my @results = ();
	my @row;
	my $query = "SELECT DISTINCT name, DBsubject_id FROM `$tables{dbsubject}` ORDER BY DBsubject_id";
	my $dbh   = getDB($c->ce);
	my $sth   = $dbh->prepare($query);
	$sth->execute();

	while (@row = $sth->fetchrow_array()) {
		push @results, $row[0];
	}
	# @results = sortByName(undef, @results);
	return @results;
}

=item getAllDBchapters($c)
Returns an array of DBchapter names

$c is the WeBWorK::Controller object

=cut

sub getAllDBchapters {
	my $c       = shift;
	my %tables  = getTables($c->ce);
	my $subject = $c->param('library_subjects');
	return () unless ($subject);
	my $dbh = getDB($c->ce);

	my $query = "SELECT DISTINCT c.name, c.DBchapter_id
				FROM `$tables{dbchapter}` c,
				`$tables{dbsubject}` t
                 WHERE c.DBsubject_id = t.DBsubject_id AND
                 t.name = ? ORDER BY c.DBchapter_id";
	my $all_chaps_ref = $dbh->selectall_arrayref($query, {}, $subject);
	my @results       = map { $_->[0] } @{$all_chaps_ref};
	return @results;
}

=item getAllDBsections($c)
Returns an array of DBsection names

$c is the WeBWorK::Controller object

=cut

sub getAllDBsections {
	my $c       = shift;
	my %tables  = getTables($c->ce);
	my $subject = $c->param('library_subjects');
	return () unless ($subject);
	my $chapter = $c->param('library_chapters');
	return () unless ($chapter);
	my $dbh = getDB($c->ce);

	my $query = "SELECT DISTINCT s.name, s.DBsection_id
                 FROM `$tables{dbsection}` s,
                 `$tables{dbchapter}` c, `$tables{dbsubject}` t
                 WHERE s.DBchapter_id = c.DBchapter_id AND
                 c.DBsubject_id = t.DBsubject_id AND
                 t.name = ? AND c.name = ? ORDER BY s.DBsection_id";
	my $all_sections_ref = $dbh->selectall_arrayref($query, {}, $subject, $chapter);
	my @results          = map { $_->[0] } @{$all_sections_ref};
	return @results;
}

=item getDBListings($c)
Returns an array of hash references with the keys: path, filename.

$c is a WeBWorK::Controller object that has all needed data inside of it

Here, we search on all known fields out of r

=cut

sub getDBListings {
	my $c               = shift;
	my $amcounter       = shift;            # 0-1 if I am a counter.
	my $ce              = $c->ce;
	my %tables          = getTables($ce);
	my $subj            = $c->param('library_subjects') || "";
	my $chap            = $c->param('library_chapters') || "";
	my $sec             = $c->param('library_sections') || "";
	my $include_opl     = $c->param('includeOPL')     // 1;
	my $include_contrib = $c->param('includeContrib') // 0;

	# Make sure these strings are internally encoded in UTF-8
	utf8::upgrade($subj);
	utf8::upgrade($chap);
	utf8::upgrade($sec);

	my $keywords = $c->param('library_keywords') || "";
	# Next could be an array, an array reference, or nothing
	my @levels = $c->param('level');
	if (scalar(@levels) == 1 and ref($levels[0]) eq 'ARRAY') {
		@levels = @{ $levels[0] };
	}
	@levels = grep { defined($_) && m/\S/ } @levels;
	my ($kw1, $kw2) = ('', '');
	my $keywordstring;
	my @keyword_params;
	if ($keywords) {
		($keywordstring, @keyword_params) = makeKeywordWhere($keywords);
		$kw1 = ", `$tables{keyword}` kw, `$tables{pgfile_keyword}` pgkey";
		$kw2 = " AND kw.keyword_id=pgkey.keyword_id AND
			 pgkey.pgfile_id=pgf.pgfile_id $keywordstring";
	}

	my $dbh = getDB($ce);

	my $extrawhere        = '';
	my @select_parameters = ();
	if ($subj) {
		$extrawhere .= " AND dbsj.name= ? ";
		push @select_parameters, $subj;
	}
	if ($chap) {
		$extrawhere .= " AND dbc.name= ? ";
		push @select_parameters, $chap;
	}
	if ($sec) {
		$extrawhere .= " AND dbsc.name= ? ";
		push @select_parameters, $sec;
	}
	if (scalar(@levels)) {
		$extrawhere .= " AND pgf.level IN ( ? ) ";
		push @select_parameters, join(',', @levels);
	}
	$extrawhere .= " AND pgf.libraryroot = 'Library' " unless $include_contrib;
	$extrawhere .= " AND pgf.libraryroot = 'Contrib' " unless $include_opl;
	my $textextrawhere      = '';
	my $haveTextInfo        = 0;
	my @textInfo_parameters = ();
	for my $j (qw( textbook textchapter textsection )) {
		my $foo = $c->param(LIBRARY_STRUCTURE->{$j}{name}) || '';
		$foo =~ s/^\s*\d+\.\s*//;
		if ($foo) {
			$haveTextInfo = 1;
			$foo =~ s/'/\\'/g;
			$textextrawhere .= " AND " . LIBRARY_STRUCTURE->{$j}{where} . "= ? ";
			push @textInfo_parameters, $foo;
		}
	}

	my $selectwhat = 'DISTINCT pgf.pgfile_id';
	$selectwhat = "COUNT($selectwhat)" if ($amcounter);

	my $pg_id_ref;

	$dbh->do(qq{SET NAMES 'utf8mb4';}) if $ce->{ENABLE_UTF8MB4};
	if ($haveTextInfo) {
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
				  prob.section_id = ts.section_id
				  $extrawhere $textextrawhere $kw2";

		$pg_id_ref = $dbh->selectall_arrayref($query, {}, @select_parameters, @textInfo_parameters, @keyword_params);
	} else {
		my $query = "SELECT $selectwhat from `$tables{pgfile}` pgf,
			 `$tables{dbsection}` dbsc, `$tables{dbchapter}` dbc, `$tables{dbsubject}` dbsj $kw1
			WHERE dbsj.DBsubject_id = dbc.DBsubject_id AND
				  dbc.DBchapter_id = dbsc.DBchapter_id AND
				  dbsc.DBsection_id = pgf.DBsection_id
				  $extrawhere $kw2";

		$pg_id_ref = $dbh->selectall_arrayref($query, {}, @select_parameters, @keyword_params);
	}

	my @pg_ids = map { $_->[0] } @{$pg_id_ref};
	return (@pg_ids[0]) if ($amcounter);

	my @results = ();
	for my $pgid (@pg_ids) {
		my $query =
			"SELECT libraryroot, path, filename, morelt_id, pgfile_id, static, MO FROM `$tables{pgfile}` pgf, `$tables{path}` p
          WHERE p.path_id = pgf.path_id AND pgf.pgfile_id= ? ";
		my $row = $dbh->selectrow_arrayref($query, {}, $pgid);

		push @results,
			{
				'libraryroot' => $row->[0],
				'path'        => $row->[1],
				'filename'    => $row->[2],
				'morelt'      => $row->[3],
				'pgid'        => $row->[4],
				'static'      => $row->[5],
				'MO'          => $row->[6],
			};

	}
	return @results;
}

sub countDBListings {
	my $c = shift;
	return (getDBListings($c, 1));
}

sub getMLTleader {
	my $c      = shift;
	my $mltid  = shift;
	my %tables = getTables($c->ce);
	my $dbh    = getDB($c->ce);
	my $query  = "SELECT leader FROM `$tables{morelt}` WHERE morelt_id=\"$mltid\"";
	my $row    = $dbh->selectrow_arrayref($query);
	return $row->[0];
}

##############################################################################
# input chapter, section
# returns an array of hash references.
# if section is omitted, get all from the chapter
sub getSectionListings {
	# TODO: eliminate this subroutine after deprecating OPLv1
	my $c       = shift;
	my $ce      = $c->ce;
	my $version = $ce->{problemLibrary}->{version} || 1;
	if ($version => 2) { return (getDBListings($c, 0)) }
	my $subj = $c->param('library_subjects') || "";
	my $chap = $c->param('library_chapters') || "";
	my $sec  = $c->param('library_sections') || "";

	my $chapstring = '';
	if ($chap) {
		$chap =~ s/'/\\'/g;
		$chapstring = " c.chapter = \'$chap\' AND ";
	}
	my $secstring = '';
	if ($sec) {
		$sec =~ s/'/\\'/g;
		$secstring = " c.section = \'$sec\' AND ";
	}

	my @results;    #returned
	my $query = "SELECT c.*, p.path
	FROM classify c, pgfiles p
	WHERE ? ? c.pgfiles_id = p.pgfiles_id";
	my $dbh    = getDB($ce);
	my %tables = getTables($ce);
	my $sth    = $dbh->prepare($query);

	$sth->execute($chapstring, $secstring);

	while (my $row = $sth->fetchrow_hashref) {
		push @results, $row;
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
	my $ce         = shift;
	my $listing_id = shift;
	#print STDERR "ListingDB::deleteListing(): listing == '$listing_id'\n";

	my $dbh    = getDB($ce);
	my %tables = getTables($ce);

	return undef;
}

# Use sortByName($aref, @b) to sort list @b using parallel list @a.
# Here, $aref is a reference to the array @a

sub indirectSortByName {
	my $aref = shift;
	my @a    = @$aref;
	my @b    = @_;
	my %pairs;
	for my $j (1 .. scalar(@a)) {
		$pairs{ $a[ $j - 1 ] } = $b[ $j - 1 ];
	}
	my @list = sortByName(undef, @a);
	@list = map { $pairs{$_} } @list;
	return (@list);
}

##############################################################################
1;

__END__

=back

=head1 DESCRIPTION

This module provides access to the database of classify in the
system. This includes the filenames, along with the table of
search terms.

=head1 AUTHOR

Written by Bill Ziemer.
Modified by John Jones.

=cut
