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

# Web service which fetches WeBWorK problems from a library.
package WebworkWebservice::LibraryActions;

use strict;
use warnings;

use File::Find;

use WeBWorK::Utils::ListingDB;
use WeBWorK::CourseEnvironment;

# Idea from http://www.perlmonks.org/index.pl?node=How%20to%20map%20a%20directory%20tree%20to%20a%20perl%20hash%20tree
sub build_tree {
	my ($dirPath) = @_;
	my $tree      = {};
	my $node      = $tree;
	my @s;
	find(
		{
			wanted => sub {
				unless ($File::Find::dir =~ /.svn/ || $File::Find::name =~ /.svn/) {
					$node = (pop @s)->[1] while @s and $File::Find::dir ne $s[-1][0];
					return $node->{$_} = -s if -f;
					push @s, [ $File::Find::name, $node ];
					$node = $node->{$_} = {};
				}
			},
			follow_fast => 1
		},
		$dirPath
	);
	return { $dirPath => $tree->{'.'} };
}

sub listLib {
	my ($invocant, $self, $rh) = @_;
	my $out = {};
	$rh->{library_name} =~ s|^/||;
	my $dirPath  = $self->ce->{courseDirs}{templates} . '/' . $rh->{library_name};
	my $maxdepth = $rh->{maxdepth};
	my $dirPath2 = $dirPath . (($rh->{dirPath}) ? '/' . $rh->{dirPath} : '');

	my @tare = $dirPath2 =~ m|/|g;
	my $tare = @tare;                # counts number of '/' in dirPath prefix
	my @outListLib;
	my %libDirectoryList;
	my $depthfinder = sub {          # counts depth below the current directory
		my $path  = shift;
		my @count = $path =~ m|/|g;
		my $depth = @count;
		return $depth - $tare;
	};
	my $wanted = sub {               # find .pg files
		unless ($File::Find::dir =~ /.svn/) {
			my $name = $File::Find::name;
			if ($name =~ /\S/) {
				push(@outListLib, $name) if $name =~ /\.pg/;
			}
		}
	};

	my $wanted_directory = sub {
		$File::Find::prune = 1 if &$depthfinder($File::Find::dir) > $maxdepth;
		unless ($File::Find::dir =~ /.svn/) {
			my $dir = $File::Find::dir;
			if ($dir =~ /\S/) {
				$dir =~ s|^$dirPath2/*||;    # cut the first directory

				$libDirectoryList{$dir} = {};
			}
		}
	};

	my $command = $rh->{command};

	$command = 'all' unless defined($command);

	$command eq 'all' && do {
		$out->{command} = "all -- list all pg files in $dirPath";
		find({ wanted => $wanted, follow_fast => 1 }, $dirPath);
		@outListLib    = sort @outListLib;
		$out->{ra_out} = \@outListLib;
		$out->{text}   = join("\n", @outListLib);
		return $out;
	};
	$command eq 'dirOnly' && do {
		if (-e $dirPath2 && $dirPath2 !~ m|//|) {
			# it turns out that when // occur in path -e will work
			# but find will not :-(
			find({ wanted => $wanted_directory, follow_fast => 1 }, $dirPath2);
			delete $libDirectoryList{''};
			$out->{ra_out} = \%libDirectoryList;
			$out->{text}   = 'Loaded libraries';
			return $out;
		} else {
			$out->{error} = "Can't open directory  $dirPath2";
		}
	};
	$command eq 'buildtree' && do {
		my $tree = build_tree($dirPath);
		$out->{ra_out} = $tree;
		$out->{text}   = 'Loaded libraries';
		return $out;
	};

	$command eq 'files' && do {
		@outListLib = ();

		if (-e $dirPath2 and $dirPath2 !~ m|//|) {
			find({ wanted => $wanted, follow_fast => 1 }, $dirPath2);
			@outListLib    = sort @outListLib;
			$out->{text}   = 'Problems loaded';
			$out->{ra_out} = \@outListLib;
		} else {
			$out->{error} = "Can't open directory  $dirPath2";
		}
		return $out;
	};

	$out->{error} = "Unrecognized command $command";
	return $out;
}

# API for searching the OPL database
sub searchLib {
	my ($invocant, $self, $rh) = @_;
	my $out        = {};
	my $ce         = $self->ce;
	my $subcommand = $rh->{command};
	if ($rh->{library_levels}) {
		$self->{level} = [ split(//, $rh->{library_levels}) ];
	}
	'getDBTextbooks' eq $subcommand && do {
		$self->{library_subjects}    = $rh->{library_subjects};
		$self->{library_chapters}    = $rh->{library_chapters};
		$self->{library_sections}    = $rh->{library_sections};
		$self->{library_textchapter} = $rh->{library_textchapter};
		my @textbooks = WeBWorK::Utils::ListingDB::getDBTextbooks($self);
		$out->{ra_out} = \@textbooks;
		return $out;
	};
	'getAllDBsubjects' eq $subcommand && do {
		my @subjects = WeBWorK::Utils::ListingDB::getAllDBsubjects($self);
		$out->{ra_out} = \@subjects;
		$out->{text}   = 'Subjects loaded.';
		return $out;
	};
	'getAllDBchapters' eq $subcommand && do {
		$self->{library_subjects} = $rh->{library_subjects};
		my @chaps = WeBWorK::Utils::ListingDB::getAllDBchapters($self);
		$out->{ra_out} = \@chaps;
		$out->{text}   = 'Chapters loaded.';

		return $out;
	};
	'getDBListings' eq $subcommand && do {

		my $templateDir = $self->ce->{courseDirs}->{templates};
		$self->{library_subjects}    = $rh->{library_subjects};
		$self->{library_chapters}    = $rh->{library_chapters};
		$self->{library_sections}    = $rh->{library_sections};
		$self->{library_keywords}    = $rh->{library_keywords};
		$self->{library_textbook}    = $rh->{library_textbook};
		$self->{library_textchapter} = $rh->{library_textchapter};
		$self->{library_textsection} = $rh->{library_textsection};
		my @listings = WeBWorK::Utils::ListingDB::getDBListings($self);
		my @output =
			map { "$templateDir/" . $_->{libraryroot} . '/' . $_->{path} . '/' . $_->{filename} } @listings;
		$out->{ra_out} = \@output;
		return $out;
	};
	'getSectionListings' eq $subcommand && do {
		$self->{library_subjects} = $rh->{library_subjects};
		$self->{library_chapters} = $rh->{library_chapters};
		$self->{library_sections} = $rh->{library_sections};

		my @section_listings = WeBWorK::Utils::ListingDB::getAllDBsections($self);
		$out->{ra_out} = \@section_listings;
		$out->{text}   = 'Sections loaded.';

		return $out;
	};

	'countDBListings' eq $subcommand && do {
		$self->{library_subjects}    = $rh->{library_subjects};
		$self->{library_chapters}    = $rh->{library_chapters};
		$self->{library_sections}    = $rh->{library_sections};
		$self->{library_keywords}    = $rh->{library_keywords};
		$self->{library_textbook}    = $rh->{library_textbook};
		$self->{library_textchapter} = $rh->{library_textchapter};
		$self->{library_textsection} = $rh->{library_textsection};
		$self->{includeOPL}          = $rh->{includeOPL};
		$self->{includeContrib}      = $rh->{includeContrib};
		my $count = WeBWorK::Utils::ListingDB::countDBListings($self);
		$out->{text}   = 'Count done.';
		$out->{ra_out} = [$count];
		return $out;
	};

	$out->{error} = "Unrecognized command $subcommand";
	return $out;
}

sub getProblemTags {
	my ($invocant, $self, $rh) = @_;
	my $out  = {};
	my $path = $rh->{command};
	# Get a pointer to a hash of DBchapter, ..., DBsection
	my $tags = WeBWorK::Utils::ListingDB::getProblemTags($path);
	$out->{ra_out} = $tags;
	$out->{text}   = 'Tags loaded.';

	return $out;
}

# FIXME: Why are library_subjects, library_chapters, library_sections plural?  Each has a value that is a single
# subject, chapter, or section.  This is also done in many places above.
sub setProblemTags {
	my ($invocant, $self, $rh) = @_;
	my $path   = $rh->{command};
	my $dbsubj = $rh->{library_subjects};
	my $dbchap = $rh->{library_chapters};
	my $dbsect = $rh->{library_sections};
	my $level  = $rh->{library_levels};
	my $stat   = $rh->{library_status};
	# result is [success, message] with success = 0 or 1
	my $result = WeBWorK::Utils::ListingDB::setProblemTags($path, $dbsubj, $dbchap, $dbsect, $level, $stat);
	my $out    = {};
	$out->{text} = $result->[1];
	return $out;
}

1;
