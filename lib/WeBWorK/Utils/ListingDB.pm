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
use Mojo::Base 'Exporter', -signatures;

use DBI;
use File::Basename;

use WeBWorK::Utils qw(sortByName);
use WeBWorK::Utils::Tags;

our @EXPORT_OK = qw(
	getDBextras
	getDBTextbooks
	getAllDBsubjects
	getAllDBchapters
	getAllDBsections
	getDBListings
	countDBListings
);

use constant LIBRARY_STRUCTURE => {
	textbook => {
		select => 'tbk.textbook_id,tbk.title,tbk.author,tbk.edition',
		name   => 'library_textbook',
		where  => 'tbk.textbook_id'
	},
	textchapter => {
		select => 'tc.chapter_id,tc.number,tc.name',
		name   => 'library_textchapter',
		where  => 'tc.chapter_id'
	},
	textsection => {
		select => 'ts.section_id,ts.number,ts.name',
		name   => 'library_textsection',
		where  => 'ts.section_id'
	},
	problem => { select => 'prob.name' },
};

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

sub getDB ($ce) {
	my $dbh = DBI->connect_cached(
		$ce->{problemLibrary_db}{dbsource},
		$ce->{problemLibrary_db}{user},
		$ce->{problemLibrary_db}{passwd},
		{
			PrintError => 0,
			RaiseError => 1,
		},
	);
	die 'Cannot connect to problem library database' unless $dbh;
	$dbh->do(qq{SET NAMES 'utf8mb4';}) if $ce->{ENABLE_UTF8MB4};
	return $dbh;
}

sub getProblemTags ($path) {
	my $tags = WeBWorK::Utils::Tags->new($path);
	my %thash;
	for my $j ('DBchapter', 'DBsection', 'DBsubject', 'Level', 'Status') {
		$thash{$j} = $tags->{$j};
	}
	return \%thash;
}

sub setProblemTags ($path, $subj, $chap, $sect, $level, $status = 0) {
	$status ||= 0;

	if (-w $path) {
		my $tags = WeBWorK::Utils::Tags->new($path);
		$tags->settag('DBsubject', $subj,   1);
		$tags->settag('DBchapter', $chap,   1);
		$tags->settag('DBsection', $sect,   1);
		$tags->settag('Level',     $level,  1);
		$tags->settag('Status',    $status, 1);
		eval { $tags->write; 1; } or do { return [ 0, 'Problem writing file' ]; };
		return [ 1, 'Tags written' ];
	} else {
		return [ 0, 'Do not have permission to write to the problem file' ];
	}
}

sub keywordTidy ($s) {
	return lc($s =~ s/[\W_]//gr);
}

sub keywordCleaner ($string) {
	return map { keywordTidy($_) } split /\s*,\s*/, $string;
}

sub makeKeywordWhere ($kwstring) {
	my @kwlist = keywordCleaner($kwstring);
	my $where  = join(' OR ', map {'kw.keyword = ? '} @kwlist);
	return "AND ( $where )", @kwlist;
}

sub getDBextras ($c, $path) {
	my $dbh = getDB($c->ce);
	my ($mo, $static) = (0, 0);

	$path =~ s|^Library/||;
	my $filename = basename $path;
	$path = dirname $path;
	my $query =
		"SELECT pgfile.MO, pgfile.static FROM `$OPLtables{pgfile}` pgfile, `$OPLtables{path}` p "
		. "WHERE p.path=\"$path\" AND pgfile.path_id=p.path_id AND pgfile.filename=\"$filename\"";
	my @res = $dbh->selectrow_array($query);
	if (@res) {
		$mo     = $res[0];
		$static = $res[1];
	}

	return [ $mo, $static ];
}

sub getDBTextbooks ($c, $thing = 'textbook') {
	my $dbh = getDB($c->ce);

	my $extrawhere = '';
	my @search_params;

	if ($c->param('library_subject')) {
		$extrawhere .= " AND t.DBsubject_id = ?\n";
		push @search_params, $c->param('library_subject');
	}
	if ($c->param('library_chapter')) {
		$extrawhere .= " AND c.DBchapter_id = ? AND c.DBsubject_id = t.DBsubject_id\n";
		push @search_params, $c->param('library_chapter');
	}
	if ($c->param('library_section')) {
		$extrawhere .=
			' AND s.DBsection_id = ? AND s.DBchapter_id = c.DBchapter_id AND s.DBsection_id = pgf.DBsection_id';
		push @search_params, $c->param('library_section');
	}

	my $textextrawhere = '';

	if ($thing ne 'textbook') {
		return [] unless $c->param('library_textbook');
		$textextrawhere .= ' AND tbk.textbook_id = ? ';
		push @search_params, $c->param('library_textbook');
	}

	if ($thing eq 'textsection') {
		return [] unless $c->param('library_textchapter');
		$textextrawhere .= ' AND tc.chapter_id = ? ';
		push @search_params, $c->param('library_textchapter');
	}

	my $selectwhat = LIBRARY_STRUCTURE->{$thing}{select};

	my $query = "SELECT DISTINCT $selectwhat
		FROM `$OPLtables{textbook}` tbk,
			`$OPLtables{problem}` prob,
			`$OPLtables{pgfile_problem}` pg,
			`$OPLtables{pgfile}` pgf,
			`$OPLtables{dbsection}` s,
			`$OPLtables{dbchapter}` c,
			`$OPLtables{dbsubject}` t,
			`$OPLtables{chapter}` tc,
			`$OPLtables{section}` ts
		WHERE ts.section_id = prob.section_id AND
			prob.problem_id = pg.problem_id AND
			s.DBchapter_id = c.DBchapter_id AND
			c.DBsubject_id = t.DBsubject_id AND
			pgf.DBsection_id = s.DBsection_id AND
			pgf.pgfile_id = pg.pgfile_id AND
			ts.chapter_id = tc.chapter_id AND
			tc.textbook_id = tbk.textbook_id
			$extrawhere $textextrawhere";

	my $text_ref = $dbh->selectall_arrayref($query, {}, @search_params);

	my @texts = @{$text_ref};
	my @sortarray;
	if ($thing eq 'textbook') {
		@texts     = grep { $_->[1] =~ /\S/ } @texts;
		@sortarray = map  { $_->[1] . $_->[2] . $_->[3] } @texts;
	} else {
		@texts     = grep { $_->[2] =~ /\S/ } @texts;
		@sortarray = map  { $_->[1] . '. ' . $_->[2] } @texts;
	}

	@texts = indirectSortByName(\@sortarray, @texts);
	return \@texts;
}

sub getAllDBsubjects ($c) {
	my $dbh = getDB($c->ce);
	return @{
		$dbh->selectall_arrayref(
			"SELECT DISTINCT name, DBsubject_id FROM `$OPLtables{dbsubject}` ORDER BY DBsubject_id")
	};
}

sub getAllDBchapters ($c) {
	return unless $c->param('library_subject');
	my $dbh = getDB($c->ce);
	return @{
		$dbh->selectall_arrayref(
			"SELECT DISTINCT c.name, c.DBchapter_id FROM `$OPLtables{dbchapter}` c, `$OPLtables{dbsubject}` t "
				. 'WHERE c.DBsubject_id = t.DBsubject_id AND t.DBsubject_id = ? ORDER BY c.DBchapter_id',
			{}, $c->param('library_subject')
		)
	};
}

sub getAllDBsections ($c) {
	return unless $c->param('library_subject') && $c->param('library_chapter');
	my $dbh = getDB($c->ce);
	return @{
		$dbh->selectall_arrayref(
			"SELECT DISTINCT s.name, s.DBsection_id "
				. "FROM `$OPLtables{dbsection}` s, `$OPLtables{dbchapter}` c, `$OPLtables{dbsubject}` t "
				. "WHERE s.DBchapter_id = c.DBchapter_id AND c.DBsubject_id = t.DBsubject_id "
				. "AND t.DBsubject_id = ? AND c.DBchapter_id = ? "
				. "ORDER BY s.DBsection_id",
			{}, $c->param('library_subject'), $c->param('library_chapter')
		)
	};
}

sub getDBListings ($c, $amcounter = 0) {
	my $ce = $c->ce;

	my $extrawhere = '';
	my @select_parameters;
	if ($c->param('library_subject')) {
		$extrawhere .= ' AND dbsj.DBsubject_id = ? ';
		push @select_parameters, $c->param('library_subject');
	}
	if ($c->param('library_chapter')) {
		$extrawhere .= ' AND dbc.DBchapter_id = ? ';
		push @select_parameters, $c->param('library_chapter');
	}
	if ($c->param('library_section')) {
		$extrawhere .= ' AND dbsc.DBsection_id = ? ';
		push @select_parameters, $c->param('library_section');
	}

	my @levels = $c->param('level');
	@levels = @{ $levels[0] }              if @levels == 1 && ref($levels[0]) eq 'ARRAY';
	@levels = split(/\s*,\s*/, $levels[0]) if @levels == 1;
	@levels = grep { defined && m/\S/ } @levels;
	if (@levels) {
		$extrawhere .= ' AND pgf.level IN (' . join(',', ('?') x @levels) . ') ';
		push(@select_parameters, @levels);
	}

	$extrawhere .= " AND pgf.libraryroot = 'Library' " unless $c->param('includeContrib');
	$extrawhere .= " AND pgf.libraryroot = 'Contrib' " unless $c->param('includeOPL') // 1;

	my ($kw_tables, $kw_where) = ('', '');
	my @keyword_parameters;
	if ($c->param('library_keywords')) {
		(my $keywordstring, @keyword_parameters) = makeKeywordWhere($c->param('library_keywords'));
		$kw_tables = ", `$OPLtables{keyword}` kw, `$OPLtables{pgfile_keyword}` pgkey";
		$kw_where  = " AND kw.keyword_id = pgkey.keyword_id AND pgkey.pgfile_id = pgf.pgfile_id $keywordstring";
	}

	my $textextrawhere = '';
	my @textInfo_parameters;
	for (qw(textbook textchapter textsection)) {
		if ($c->param(LIBRARY_STRUCTURE->{$_}{name})) {
			$textextrawhere .= ' AND ' . LIBRARY_STRUCTURE->{$_}{where} . ' = ? ';
			push @textInfo_parameters, $c->param(LIBRARY_STRUCTURE->{$_}{name});
		}
	}

	my $group_by   = '';
	my $selectwhat = 'CONCAT(pgf.libraryroot, "/", p.path, "/", pgf.filename)';
	if ($amcounter) {
		$selectwhat = "COUNT(DISTINCT $selectwhat)";
	} else {
		$selectwhat .= 'as filepath, pgf.morelt_id, pgf.pgfile_id, pgf.static, pgf.MO';
		$group_by = 'GROUP BY filepath';
	}

	my $pg_file_ref;

	my $dbh = getDB($ce);

	if ($textextrawhere) {
		my $query = "SELECT $selectwhat from `$OPLtables{pgfile}` pgf, `$OPLtables{path}` p,
			`$OPLtables{dbsection}` dbsc, `$OPLtables{dbchapter}` dbc, `$OPLtables{dbsubject}` dbsj,
			`$OPLtables{pgfile_problem}` pgp, `$OPLtables{problem}` prob, `$OPLtables{textbook}` tbk,
			`$OPLtables{chapter}` tc, `$OPLtables{section}` ts $kw_tables
			WHERE dbsj.DBsubject_id = dbc.DBsubject_id AND
				dbc.DBchapter_id = dbsc.DBchapter_id AND
				dbsc.DBsection_id = pgf.DBsection_id AND
				pgf.pgfile_id = pgp.pgfile_id AND
				pgp.problem_id = prob.problem_id AND
				tc.textbook_id = tbk.textbook_id AND
				ts.chapter_id = tc.chapter_id AND
				prob.section_id = ts.section_id AND
				p.path_id = pgf.path_id
				$extrawhere $textextrawhere $kw_where $group_by";

		$pg_file_ref =
			$dbh->selectall_arrayref($query, {}, @select_parameters, @textInfo_parameters, @keyword_parameters);
	} else {
		my $query = "SELECT $selectwhat from `$OPLtables{pgfile}` pgf, `$OPLtables{path}` p,
			`$OPLtables{dbsection}` dbsc, `$OPLtables{dbchapter}` dbc, `$OPLtables{dbsubject}` dbsj $kw_tables
			WHERE dbsj.DBsubject_id = dbc.DBsubject_id AND
				dbc.DBchapter_id = dbsc.DBchapter_id AND
				dbsc.DBsection_id = pgf.DBsection_id AND
				p.path_id = pgf.path_id
				$extrawhere $kw_where $group_by";

		$pg_file_ref = $dbh->selectall_arrayref($query, {}, @select_parameters, @keyword_parameters);
	}

	return $pg_file_ref->[0][0] if $amcounter;

	my @results;
	for my $pgfile (@$pg_file_ref) {
		push @results,
			{
				'filepath' => $pgfile->[0],
				'morelt'   => $pgfile->[1],
				'pgid'     => $pgfile->[2],
				'static'   => $pgfile->[3],
				'MO'       => $pgfile->[4],
			};
	}

	return @results;
}

sub countDBListings ($c) {
	return getDBListings($c, 1);
}

sub getMLTleader ($c, $mltid) {
	my $dbh = getDB($c->ce);
	my $row = $dbh->selectrow_arrayref(qq{SELECT leader FROM `$OPLtables{morelt}` WHERE morelt_id="$mltid"});
	return $row->[0];
}

# Use sortByName($aref, @b) to sort list @b using the parallel list referenced by $aref.
sub indirectSortByName ($aref, @b) {
	my %pairs;
	for my $j (0 .. $#$aref) {
		$pairs{ $aref->[$j] } = $b[$j];
	}
	return map { $pairs{$_} } sortByName(undef, @$aref);
}

1;

=head1 DESCRIPTION

This module provides access to the database of classify in the
system. This includes the filenames, along with the table of
search terms.

=head2 getProblemTags

Usage: C<getProblemTags($path)>

Get tags using full path and tagging module.

=head2 setProblemTags

Usage: C<setProblemTags($path, $subj, $chap, $sect)>

Set tags using full path and tagging module.

=head2 keywordTidy

Usage: C<keywordTidy($s)>

Regularize punctuation and case for a keyword.

=head2 keywordCleaner

Usage: C<keywordCleaner($s)>

Split a string on commas, and apply keywordTidy to the entries.

=head2 getDBextras

Usage: C<getDBextras($c, $path)>

Get flags for whether a pg file uses Math Objects, and if it is static.

The parameter C<$c> must be a WeBWorK::Controller object.

C<$path> is the path to the file.

Output is an array reference: C<[MO, static]>

=head2 getDBTextbooks

Usage: C<getDBTextbooks($c, $thing)>

The parameter C<$c> must be a WeBWorK::Controller object.

The parameter C<$thing> must be one of "textbook", "textchapter", or
"textsection".

This returns a reference to an array of arrays. If C<$thing> is "textboot", then
each entry of the return array is an array containing the database id of the
textbook, the textbook title, the textbook author, and textbook edition. If
C<$thing> is "textchapter", then each entry of the return array is an array
containing the database id of the texbook chapter, the chapter number, and the
chapter name. If C<$thing> is "textsection", then each entry of the return array
is an array containing the database id of the texbook section, the section
number, and the section name.

=head2 getAllDBsubjects

Usage: C<getAllDBsubjects($c)>

Returns an array of arrays, each of which contains a database subject name and
its database id.

The parameter C<$c> must be a WeBWorK::Controller object.

=head2 getAllDBchapters

Usage: C<getAllDBchapters($c)>

Returns an array of arrays, each of which contains a database chapter name and
its database id.

The parameter C<$c> must be a WeBWorK::Controller object.

=head2 getAllDBsections

Usage: C<getAllDBsections($c)>

Returns an array of arrays, each of which contains a database section name and
its database id.

The parameter C<$c> must be a WeBWorK::Controller object.

=head2 getDBListings

Usage: C<getDBListings($c)>

The parameter C<$c> must be a WeBWorK::Controller object.

Returns an array of hash references with the keys "filepath" which is the
relative file path in the OPL, "morelt" which is true if there are more problems
like this one, "pgid" which is the internal datbase index of the problem,
"static" which is true if the problem is declared static (which it should be if
it has no random parameters), and "MO" if the problem is declared to use
MathObjects.

The search may be constrained by the parameters "library_subject",
"library_chapter", "library_section", "level", "library_keywords", "includeOPL",
"includeContrib", "library_textbook", "library_textchapter", and
"library_textsection" which are retrieved with the C<< $c->param >> method.

=head2 countDBListings

Usage: C<countDBListings($c)>

The parameter C<$c> must be a WeBWorK::Controller object.

Returns the number of OPL problems that satisfy the given constraints. The
constraints are the same as those for C<getDBListings>.

=head2 getMLTleader

Usage: C<getMLTleader($c, $mltid)>

The parameter C<$c> must be a WeBWorK::Controller object. The parameter
C<$multid> should be the more like this index of an OPL problem.

Returns the "leader" for the more like this group.

=cut
