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
		my @textbooks = WeBWorK::Utils::ListingDB::getDBTextbooks($self->c);
		$out->{ra_out} = \@textbooks;
		return $out;
	};
	'getAllDBsubjects' eq $subcommand && do {
		my @subjects = WeBWorK::Utils::ListingDB::getAllDBsubjects($self->c);
		$out->{ra_out} = \@subjects;
		$out->{text}   = 'Subjects loaded.';
		return $out;
	};
	'getAllDBchapters' eq $subcommand && do {
		my @chaps = WeBWorK::Utils::ListingDB::getAllDBchapters($self->c);
		$out->{ra_out} = \@chaps;
		$out->{text}   = 'Chapters loaded.';

		return $out;
	};
	'getDBListings' eq $subcommand && do {
		my @listings = WeBWorK::Utils::ListingDB::getDBListings($self->c);
		my @output   = map {"$self->ce->{courseDirs}{templates}/$_->{filepath}"} @listings;
		$out->{ra_out} = \@output;
		return $out;
	};
	'getSectionListings' eq $subcommand && do {
		my @section_listings = WeBWorK::Utils::ListingDB::getAllDBsections($self->c);
		$out->{ra_out} = \@section_listings;
		$out->{text}   = 'Sections loaded.';

		return $out;
	};

	'countDBListings' eq $subcommand && do {
		my $count = WeBWorK::Utils::ListingDB::countDBListings($self->c);
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

sub setProblemTags {
	my ($invocant, $self, $rh) = @_;
	# result is [success, message] with success = 0 or 1
	my $result = WeBWorK::Utils::ListingDB::setProblemTags(
		$rh->{command},         $rh->{library_subject}, $rh->{library_chapter},
		$rh->{library_section}, $rh->{library_levels},  $rh->{library_status}
	);
	my $out = {};
	$out->{text} = $result->[1];
	return $out;
}

1;
