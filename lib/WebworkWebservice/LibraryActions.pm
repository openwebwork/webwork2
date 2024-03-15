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

use Carp;
use JSON;
use File::stat;
use File::Find;

use WeBWorK::Debug;
use WeBWorK::Utils qw(sortByName);
use WeBWorK::Utils::Files qw(readDirectory);
use WeBWorK::Utils::ListingDB;
use WeBWorK::CourseEnvironment;

use constant MY_PROBLEMS   => '  My Problems  ';
use constant MAIN_PROBLEMS => '  Unclassified Problems  ';

my %problib;    # This is configured in defaults.config -- no, it's really not.

# List of directories to ignore while search through the libraries.
my %ignoredir = (
	'.'        => 1,
	'..'       => 1,
	'Library'  => 1,
	'CVS'      => 1,
	'tmpEdit'  => 1,
	'headers'  => 1,
	'macros'   => 1,
	'email'    => 1,
	'graphics' => 1,
	'.svn'     => 1,
);

# List the problem libraries that are available.
sub listLibraries {
	my ($invocant, $self, $rh) = @_;

	my %libraries = %{ $self->ce->{courseFiles}{problibs} };

	my $templateDirectory = $self->ce->{courseDirs}{templates};

	foreach my $key (keys %libraries) {
		$libraries{$key} = "$templateDirectory/$key";
	}

	my @outListLib = sort keys %libraries;
	return { ra_out => \@outListLib, text => 'success' };
}

sub readFile {
	my ($invocant, $self, $rh) = @_;

	local $| = 1;
	my $out      = {};
	my $filePath = $rh->{filePath};

	my %libraries = %{ $self->ce->{courseFiles}->{problibs} };

	my $templateDirectory = $self->ce->{courseDirs}{templates};

	for my $key (keys %libraries) {
		$libraries{$key} = "$templateDirectory/$key";
	}

	if (defined $libraries{ $rh->{library_name} }) {
		$filePath = $libraries{ $rh->{library_name} } . '/' . $filePath;
	} else {
		$out->{text} = "Could not find library: $rh->{library_name}.";
		return $out;
	}
	if (-r $filePath) {
		open my $in, '<', $filePath;
		local $/ = undef;
		my $text = <$in>;
		close $in;
		my $sb = stat($filePath);
		$out->{text}   = 'success';
		$out->{ra_out} = {
			text        => $text,
			size        => $sb->size,
			path        => $filePath,
			permissions => $sb->mode & 777,
			modTime     => scalar localtime $sb->mtime
		};
	} else {
		$out->{text} = "Could not read file at |$filePath|";
	}
	return $out;
}

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
		debug(to_json($rh));
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

sub get_library_sets {
	my ($top, $dir) = @_;
	# ignore directories that give us an error
	my @lis = eval { readDirectory($dir) };
	if ($@) {
		return (0);
	}
	return 0 if grep {/^=library-ignore$/} @lis;

	my @pgfiles = grep { m/\.pg$/ && !m/(Header|-text)\.pg$/ && -f "$dir/$_" } @lis;
	my $pgcount = scalar(@pgfiles);
	my $pgname  = $dir;
	$pgname =~ s!.*/!!;
	$pgname .= '.pg';
	my $combineUp = ($pgcount == 1 && $pgname eq $pgfiles[0] && !(grep {/^=library-no-combine$/} @lis));

	my @pgdirs;
	my @dirs = grep { !$ignoredir{$_} && -d "$dir/$_" } @lis;
	if ($top == 1) {
		@dirs = grep { !$problib{$_} } @dirs;
	}
	foreach my $subdir (@dirs) {
		my @results = get_library_sets(0, "$dir/$subdir");
		$pgcount += shift @results;
		push(@pgdirs, @results);
	}

	return ($pgcount, @pgdirs) if $top || $combineUp || grep {/^=library-combine-up$/} @lis;
	return (0, @pgdirs, $dir);
}

sub getProblemDirectories {
	my ($invocant, $self, $rh) = @_;
	my $out = {};
	my $ce  = $self->ce;

	my %libraries = %{ $self->ce->{courseFiles}{problibs} };

	my $lib    = "Library";
	my $source = $ce->{courseDirs}{templates};
	my $main   = MY_PROBLEMS;
	my $isTop  = 1;
	if ($lib) { $source .= "/$lib"; $main = MAIN_PROBLEMS; $isTop = 2 }

	my @all_problem_directories = get_library_sets($isTop, $source);
	my $includetop              = shift @all_problem_directories;
	my $j;
	for ($j = 0; $j < scalar(@all_problem_directories); $j++) {
		$all_problem_directories[$j] =~ s|^$ce->{courseDirs}->{templates}/?||;
	}
	@all_problem_directories = sortByName(undef, @all_problem_directories);
	unshift @all_problem_directories, $main if ($includetop);

	$out->{ra_out} = \@all_problem_directories;
	$out->{text}   = 'Problem Directories loaded.';

	return $out;
}

#  This subroutines outputs the entire library based on Subjects, chapters and sections.
#  The output is an array in the form "Subject/Chapter/Section"
sub buildBrowseTree {
	my ($invocant, $self, $rh) = @_;
	my $out      = {};
	my $ce       = $self->ce;
	my @tree     = ();
	my @subjects = WeBWorK::Utils::ListingDB::getAllDBsubjects($self);
	foreach my $sub (@subjects) {
		$self->{library_subjects} = $sub;
		push(@tree, "Subjects/" . $sub);
		my @chapters = WeBWorK::Utils::ListingDB::getAllDBchapters($self);
		foreach my $chap (@chapters) {
			$self->{library_chapters} = $chap;
			push(@tree, "Subjects/" . $sub . "/" . $chap);
			my @sections = WeBWorK::Utils::ListingDB::getAllDBsections($self);
			foreach my $sect (@sections) {
				push(@tree, "Subjects/" . $sub . "/" . $chap . "/" . $sect);
			}
		}
	}
	$out->{ra_out} = \@tree;
	$out->{text}   = 'Subjects, Chapters and Sections loaded.';
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
