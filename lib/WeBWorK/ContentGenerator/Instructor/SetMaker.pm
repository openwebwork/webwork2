################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.	 See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::ContentGenerator::Instructor::SetMaker;
use parent qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::SetMaker - Make homework sets.

=cut

use strict;
use warnings;

use File::Find;
use Mojo::File;

use WeBWorK::Debug;
use WeBWorK::Utils qw(readDirectory sortByName x format_set_name_internal);
use WeBWorK::Utils::Tags;
use WeBWorK::Utils::LibraryStats;
use WeBWorK::Utils::ListingDB qw(getSectionListings);
use WeBWorK::Utils::Instructor qw(assignSetToUser assignProblemToAllSetUsers addProblemToSet);

# Use x to mark strings for maketext
use constant MY_PROBLEMS   => x('My Problems');
use constant MAIN_PROBLEMS => x('Unclassified Problems');

# Flags for operations on files
use constant ADDED   => 1;
use constant HIDDEN  => (1 << 1);
use constant SUCCESS => (1 << 2);

my %ignoredir = (
	'.'            => 1,
	'..'           => 1,
	'tmpEdit'      => 1,
	'headers'      => 1,
	'macros'       => 1,
	'email'        => 1,
	'graphics'     => 1,
	'achievements' => 1,
);

sub prepare_activity_entry {
	my $self = shift;
	my $r    = $self->r;
	my $user = $self->r->param('user') || 'NO_USER';
	return ("In SetMaker as user $user");
}

## This is for searching the disk for directories containing pg files.
## to make the recursion work, this returns an array where the first
## item is the number of pg files in the directory.  The second is a
## list of directories which contain pg files.
##
## If a directory contains only one pg file and the directory name
## is the same as the file name, then the directory is considered
## to be part of the parent directory (it is probably in a separate
## directory only because it has auxiliary files that want to be
## kept together with the pg file).
##
## If a directory has a file named "=library-ignore", it is never
## included in the directory menu.  If a directory contains a file
## called "=library-combine-up", then its pg are included with those
## in the parent directory (and the directory does not appear in the
## menu).  If it has a file called "=library-no-combine" then it is
## always listed as a separate directory even if it contains only one
## pg file.

sub get_library_sets {
	my $self = shift;
	my $top  = shift;
	my $dir  = shift;
	# ignore directories that give us an error
	my @lis = eval { readDirectory($dir) };
	if ($@) {
		warn $@;
		return (0);
	}
	return (0) if grep {/^=library-ignore$/} @lis;

	my @pgfiles = grep { m/\.pg$/ && (!m/(Header|-text)(File)?\.pg$/) && -f "$dir/$_" } @lis;
	my $pgcount = scalar(@pgfiles);
	my $pgname  = $dir;
	$pgname =~ s!.*/!!;
	$pgname .= '.pg';
	my $combineUp = ($pgcount == 1 && $pgname eq $pgfiles[0] && !(grep {/^=library-no-combine$/} @lis));

	my @pgdirs;
	my @dirs = grep { !$ignoredir{$_} && -d "$dir/$_" } @lis;
	if ($top == 1) {
		@dirs = grep { !$self->{problibs}{$_} } @dirs;
	}
	# Never include Library or Contrib at the top level
	if ($top == 1) {
		@dirs = grep { $_ ne 'Library' && $_ ne 'Contrib' } @dirs;
	}
	foreach my $subdir (@dirs) {
		my @results = $self->get_library_sets(0, "$dir/$subdir");
		$pgcount += shift @results;
		push(@pgdirs, @results);
	}

	return ($pgcount, @pgdirs) if $top || $combineUp || (grep {/^=library-combine-up$/} @lis);
	return (0, @pgdirs, $dir);
}

sub get_library_pgs {
	my $self = shift;
	my $top  = shift;
	my $base = shift;
	my $dir  = shift;
	my @lis  = readDirectory("$base/$dir");
	return () if (grep {/^=library-ignore$/} @lis);
	return () if !$top && (grep {/^=library-no-combine$/} @lis);

	my @pgs = grep { m/\.pg$/ and (not m/(Header|-text)\.pg$/) and -f "$base/$dir/$_" } @lis;
	my $others =
		scalar(grep { (!m/\.pg$/ || m/(Header|-text)\.pg$/) && !m/(\.(tmp|bak)|~)$/ && -f "$base/$dir/$_" } @lis);

	my @dirs = grep { !$ignoredir{$_} && -d "$base/$dir/$_" } @lis;
	if ($top == 1) {
		@dirs = grep { !$self->{problibs}{$_} } @dirs;
	}
	foreach my $subdir (@dirs) { push(@pgs, $self->get_library_pgs(0, "$base/$dir", $subdir)) }

	return unless $top || (scalar(@pgs) == 1 && $others) || (grep {/^=library-combine-up$/} @lis);
	return (map {"$dir/$_"} @pgs);
}

sub list_pg_files {
	my ($self, $templates, $dir) = @_;
	my $top = ($dir eq '.') ? 1 : 2;
	my @pgs = $self->get_library_pgs($top, $templates, $dir);
	return sortByName(undef, @pgs);
}

## Try to make reading of set defs more flexible.  Additional strategies
## for fixing a path can be added here.

sub munge_pg_file_path {
	my $self            = shift;
	my $pg_path         = shift;
	my $path_to_set_def = shift;
	my $end_path        = $pg_path;
	# if the path is ok, don't fix it
	return ($pg_path) if (-e $self->r->ce->{courseDirs}{templates} . "/$pg_path");
	# if we have followed a link into a self contained course to get
	# to the set.def file, we need to insert the start of the path to
	# the set.def file
	$end_path = "$path_to_set_def/$pg_path";
	return ($end_path) if (-e $self->r->ce->{courseDirs}{templates} . "/$end_path");
	# if we got this far, this path is bad, but we let it produce
	# an error so the user knows there is a troublesome path in the
	# set.def file.
	return ($pg_path);
}

## Problems straight from the OPL database come with MO and static
## tag information.  This is for other times, like next/prev page.

sub getDBextras {
	my ($self, $sourceFileName) = @_;
	my $r = $self->r;

	if ($sourceFileName =~ /^Library/) {
		return @{ WeBWorK::Utils::ListingDB::getDBextras($r, $sourceFileName) };
	}

	my $filePath = $r->ce->{courseDirs}{templates} . "/$sourceFileName";
	my $tag_obj  = WeBWorK::Utils::Tags->new($filePath);
	my $isMO     = $tag_obj->{MO}     || 0;
	my $isstatic = $tag_obj->{Static} || 0;

	return ($isMO, $isstatic);
}

## With MLT, problems come in groups, so we need to find next/prev
## problems.  Return index, or -1 if there are no more.
sub next_prob_group {
	my ($ind, @pgfiles) = @_;
	my $len = scalar(@pgfiles);
	return -1 if ($ind >= $len - 1);
	my $mlt = $pgfiles[$ind]->{morelt} || 0;
	return $ind + 1 if ($mlt == 0);
	while ($ind < $len and defined($pgfiles[$ind]->{morelt}) and $pgfiles[$ind]->{morelt} == $mlt) {
		$ind++;
	}
	return -1 if ($ind == $len);
	return $ind;
}

sub prev_prob_group {
	my ($ind, @pgfiles) = @_;
	return -1 if $ind == 0;
	$ind--;
	my $mlt = $pgfiles[$ind]->{morelt};
	return $ind if $mlt == 0;
	# We have to search to the beginning of this group
	while ($ind >= 0 and $mlt == $pgfiles[$ind]->{morelt}) {
		$ind--;
	}
	return ($ind + 1);
}

sub end_prob_group {
	my ($ind, @pgfiles) = @_;
	my $next = next_prob_group($ind, @pgfiles);
	return (($next == -1) ? $#pgfiles : $next - 1);
}

## Read a set definition file.  This could be abstracted since it happens
## elsewhere.  Here we don't have to process so much of the file.
sub read_set_def {
	my ($self, $filePathOrig) = @_;
	my $r        = $self->r;
	my $filePath = $r->ce->{courseDirs}{templates} . "/$filePathOrig";
	$filePathOrig =~ s/set.*\.def$//;
	$filePathOrig =~ s|/$||;
	$filePathOrig = "." if ($filePathOrig !~ /\S/);
	my @pg_files = ();
	my ($line, $got_to_pgs, $name, @rest) = ("", 0, "");

	if (my $SETFILENAME = Mojo::File->new($filePath)->open('<')) {
		while ($line = <$SETFILENAME>) {
			chomp($line);
			$line =~ s|(#.*)||;    # don't read past comments
			if ($got_to_pgs == 1) {
				unless ($line =~ /\S/) { next; }    # skip blank lines
				($name, @rest) = split(/\s*,\s*/, $line);
				$name =~ s/\s*//g;
				push @pg_files, $name;
			} elsif ($got_to_pgs == 2) {
				# skip lines which dont identify source files
				unless ($line =~ /source_file\s*=\s*(\S+)/) {
					next;
				}
				# otherwise we got the name from the regexp
				push @pg_files, $1;
			} else {
				$got_to_pgs = 1 if ($line =~ /problemList\s*=/);
				$got_to_pgs = 2 if ($line =~ /problemListV2/);
			}
		}
		close $SETFILENAME;
	} else {
		$self->addbadmessage($r->maketext("Cannot open [_1]", $filePath));
	}
	# This is where we would potentially munge the pg file paths
	# One possibility
	@pg_files = map { $self->munge_pg_file_path($_, $filePathOrig) } @pg_files;
	return (@pg_files);
}

## go through past page getting a list of identifiers for the problems
## and whether or not they are selected, and whether or not they should
## be hidden

sub get_past_problem_files {
	my $r     = shift;
	my @found = ();
	my $count = 1;
	while (defined($r->param("filetrial$count"))) {
		my $val = 0;
		$val |= ADDED  if ($r->param("trial$count"));
		$val |= HIDDEN if ($r->param("hideme$count"));
		push @found, [ $r->param("filetrial$count"), $val ];
		$count++;
	}
	return (\@found);
}

#### For adding new problems

sub add_selected {
	my $self          = shift;
	my $db            = shift;
	my $setName       = shift;
	my @past_problems = @{ $self->{past_problems} };
	my @selected      = @past_problems;
	my $freeProblemID;

	my $addedcount = 0;

	for my $selected (@selected) {
		if ($selected->[1] & ADDED) {
			my $file          = $selected->[0];
			my $problemRecord = addProblemToSet(
				$db, $self->r->ce->{problemDefaults},
				setName    => $setName,
				sourceFile => $file
			);
			$freeProblemID++;
			assignProblemToAllSetUsers($db, $problemRecord);
			$selected->[1] |= SUCCESS;
			$addedcount++;
		}
	}
	return ($addedcount);
}

############# List of sets of problems in templates directory

sub get_problem_directories {
	my ($self, $lib) = @_;
	my $r             = $self->r;
	my $ce            = $r->ce;
	my $source        = $ce->{courseDirs}{templates};
	my $main_problems = $r->maketext(MY_PROBLEMS);
	my $isTop         = 1;
	if ($lib) { $source .= "/$lib"; $main_problems = $r->maketext(MAIN_PROBLEMS); $isTop = 2 }
	my @all_problem_directories = $self->get_library_sets($isTop, $source);
	my $includetop              = shift @all_problem_directories;

	for (my $j = 0; $j < scalar(@all_problem_directories); $j++) {
		$all_problem_directories[$j] =~ s|^$ce->{courseDirs}->{templates}/?||;
	}
	@all_problem_directories = sortByName(undef, @all_problem_directories);
	unshift @all_problem_directories, $main_problems if ($includetop);
	return (\@all_problem_directories);
}

### Mainly deal with more like this

sub process_search {
	my ($r, @dbsearch) = @_;

	# Build a hash of MLT entries keyed by morelt_id
	my %mlt = ();
	my $mltind;
	for my $indx (0 .. $#dbsearch) {
		$dbsearch[$indx]->{filepath} =
			$dbsearch[$indx]->{libraryroot} . "/" . $dbsearch[$indx]->{path} . "/" . $dbsearch[$indx]->{filename};
		# For debugging
		$dbsearch[$indx]->{oindex} = $indx;
		if ($mltind = $dbsearch[$indx]->{morelt}) {
			if (defined($mlt{$mltind})) {
				push @{ $mlt{$mltind} }, $indx;
			} else {
				$mlt{$mltind} = [$indx];
			}
		}
	}
	# Now filepath is set and we have a hash of mlt entries

	# Find MLT leaders, mark entries for no show,
	# set up children array for leaders
	for my $mltid (keys %mlt) {
		my @idlist = @{ $mlt{$mltid} };
		if (scalar(@idlist) > 1) {
			my $leader = WeBWorK::Utils::ListingDB::getMLTleader($r, $mltid) || 0;
			my $hold   = undef;
			for my $subindx (@idlist) {
				if ($dbsearch[$subindx]->{pgid} == $leader) {
					$dbsearch[$subindx]->{children} = [];
					$hold = $subindx;
				} else {
					$dbsearch[$subindx]->{noshow} = 1;
				}
			}
			do {    # we did not find the leader
				$hold                        = $idlist[0];
				$dbsearch[$hold]->{noshow}   = undef;
				$dbsearch[$hold]->{children} = [];
			} unless ($hold);
			$mlt{$mltid} = $dbsearch[$hold];    # store ref to leader
		} else {    # only one, no more
			$dbsearch[ $idlist[0] ]->{morelt} = 0;
			delete $mlt{$mltid};
		}
	}

	# Put children in leader and delete them, record index of leaders
	$mltind = 0;
	while ($mltind < scalar(@dbsearch)) {
		if ($dbsearch[$mltind]->{noshow}) {
			# move the entry to the leader
			my $mltval = $dbsearch[$mltind]->{morelt};
			push @{ $mlt{$mltval}->{children} }, $dbsearch[$mltind];
			splice @dbsearch, $mltind, 1;
		} else {
			if ($dbsearch[$mltind]->{morelt}) {    # a leader
				for my $mltid (keys %mlt) {
					if ($mltid == $dbsearch[$mltind]->{morelt}) {
						$mlt{$mltid}->{index} = $mltind;
						last;
					}
				}
			}
			$mltind++;
		}
	}
	# Last pass, reinsert children into dbsearch
	my @leaders = keys(%mlt);
	@leaders = reverse sort { $mlt{$a}->{index} <=> $mlt{$b}->{index} } @leaders;
	for my $i (@leaders) {
		my $base = $mlt{$i}->{index};
		splice @dbsearch, $base + 1, 0, @{ $mlt{$i}->{children} };
	}

	return @dbsearch;
}

async sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;

	# Make sure these are defined for the templates.
	$r->stash->{pg_files} = [];
	$r->stash->{plist}    = [];

	$self->{error} = 0;
	my $ce       = $r->ce;
	my $db       = $r->db;
	my $maxShown = $r->param('max_shown') || 20;
	$maxShown = 10000000 if ($maxShown eq 'All');    # let's hope there aren't more
	my $library_basic = $r->param('library_is_basic') || 1;
	$self->{problem_seed} = $r->param('problem_seed') || 1234;

	# Grab library sets to display from parameters list.  We will modify this as we go through the if/else tree.
	$self->{current_library_set} = $r->param('library_sets');

	# These directories will have individual buttons
	$self->{problibs} = $ce->{courseFiles}{problibs} // {};

	my $userName = $r->param('user');
	my $user     = $db->getUser($userName);          # checked
	die "record for user $userName (real user) does not exist."
		unless defined $user;
	my $authz = $r->authz;

	return unless ($authz->hasPermissions($userName, "modify_problem_sets"));

	# Now one action we have to deal with here
	if ($r->param('edit_local')) {
		my $urlpath  = $r->urlpath;
		my $db       = $r->db;
		my $checkset = $db->getGlobalSet($r->param('local_sets'));
		if (not defined($checkset)) {
			$self->{error} = 1;
			$self->addbadmessage($r->maketext('You need to select a "Target Set" before you can edit it.'));
		} else {
			my $page = $urlpath->newFromModule(
				'WeBWorK::ContentGenerator::Instructor::ProblemSetDetail', $r,
				setID    => $r->param('local_sets'),
				courseID => $urlpath->arg("courseID")
			);
			my $url = $self->systemLink($page);
			$self->reply_with_redirect($url);
		}
	}

	# Next, lots of set up so that errors can be reported with message()

	# List of problems we have already printed
	# If we don't end up reusing problems, this will be wiped out.
	# If we do redisplay the same problems, we must adjust this accordingly.
	$self->{past_problems} = get_past_problem_files($r);

	my $none_shown            = @{ $self->{past_problems} } == 0;
	my @pg_files              = ();
	my $use_previous_problems = 1;
	my $first_shown           = $r->param('first_shown') || 0;
	my $last_shown            = $r->param('last_shown');
	if (not defined($last_shown)) {
		$last_shown = -1;
	}
	my $first_index = $r->param('first_index') || 0;
	my $last_index  = $r->param('last_index');
	if (not defined($last_index)) {
		$last_index = -1;
	}
	my $total_probs   = $r->param('total_probs') || 0;
	my @all_past_list = ();                              # These include requested, but not shown
	my ($j, $count, $omlt, $nmlt, $hold) = (0, 0, -1, 0, 0);
	while (defined($r->param("all_past_list$j"))) {
		$nmlt = $r->param("all_past_mlt$j") || 0;
		push @all_past_list, { 'filepath' => $r->param("all_past_list$j"), 'morelt' => $nmlt };
		if ($nmlt != $omlt or $nmlt == 0) {
			$count++ if ($j > 0);
			if ($j > $hold + 1) {
				$all_past_list[$hold]->{children} = [ 2 .. ($j - $hold) ];
			}
			$omlt = $nmlt;
			$hold = $j;
		} else {    # equal and nonzero, so a child
			$all_past_list[$j]->{noshow} = 1;
		}
		$j++;
	}
	if ($nmlt && $j - $hold > 1) { $all_past_list[$hold]->{children} = [ 2 .. ($j - $hold) ]; }
	$count++ if ($j > 0);

	# Default of which problem selector to display
	my $browse_which = $r->param('browse_which') || 'browse_npl_library';

	# Check for problem lib buttons
	my $browse_lib = '';
	for my $lib (keys %{ $self->{problibs} }) {
		if ($r->param("browse_$lib")) {
			$browse_lib = "browse_$lib";
			last;
		}
	}

	# Start the logic through if elsif elsif ...
	debug("browse_lib",         $r->param("$browse_lib"));
	debug("browse_npl_library", $r->param("browse_npl_library"));
	debug("browse_course_sets", $r->param("browse_course_sets"));
	debug("browse_setdefs",     $r->param("browse_setdefs"));
	# Asked to browse certain problems
	if ($browse_lib ne '') {
		$browse_which                = $browse_lib;
		$self->{current_library_set} = "";
		$use_previous_problems       = 0;
		@pg_files                    = ();
	} elsif ($r->param('browse_npl_library')) {
		$browse_which                = 'browse_npl_library';
		$self->{current_library_set} = "";
		$use_previous_problems       = 0;
		@pg_files                    = ();
	} elsif ($r->param('browse_local')) {
		$browse_which          = 'browse_local';
		$use_previous_problems = 0;
		@pg_files              = ();
	} elsif ($r->param('browse_course_sets')) {
		$browse_which          = 'browse_course_sets';
		$use_previous_problems = 0;
		@pg_files              = ();
	} elsif ($r->param('browse_setdefs')) {
		$browse_which                = 'browse_setdefs';
		$self->{current_library_set} = "";
		$use_previous_problems       = 0;
		@pg_files                    = ();
	} elsif ($r->param('rerandomize')) {
		# Change the seed value
		$self->{problem_seed} = 1 + $self->{problem_seed};
		$self->addbadmessage($r->maketext('Changing the problem seed for display, but there are no problems showing.'))
			if $none_shown;
	} elsif ($r->param('cleardisplay')) {
		# Clear the display
		@pg_files              = ();
		$use_previous_problems = 0;
	} elsif ($r->param('view_local_set')) {
		# View problems selected from the local list
		my $set_to_display = $self->{current_library_set};
		if (!defined $set_to_display || $set_to_display eq '') {
			$self->addbadmessage($r->maketext('You need to select a set to view.'));
		} else {
			$set_to_display        = '.'                      if $set_to_display eq $r->maketext(MY_PROBLEMS);
			$set_to_display        = substr($browse_which, 7) if $set_to_display eq $r->maketext(MAIN_PROBLEMS);
			@pg_files              = $self->list_pg_files($ce->{courseDirs}{templates}, "$set_to_display");
			@pg_files              = map { { 'filepath' => $_, 'morelt' => 0 } } @pg_files;
			$use_previous_problems = 0;
		}
	} elsif ($r->param('view_course_set')) {
		# View problems selected from the a set in this course
		my $set_to_display = $self->{current_library_set};
		debug("set_to_display is $set_to_display");
		if (!defined $set_to_display || $set_to_display eq '') {
			$self->addbadmessage($r->maketext("You need to select a set from this course to view."));
		} else {
			@pg_files = map { { 'filepath' => $_->source_file, 'morelt' => 0 } }
				$db->getGlobalProblemsWhere({ set_id => $set_to_display });
			$use_previous_problems = 0;
		}
	} elsif ($r->param('lib_view')) {
		# View from the library database
		@pg_files = ();
		# TODO: deprecate OPLv1 -- replace getSectionListings with getDBListings($r,0)
		my @dbsearch = getSectionListings($r);
		@pg_files              = process_search($r, @dbsearch);
		$use_previous_problems = 0;
	} elsif ($r->param('view_setdef_set')) {
		# View a set from a set*.def
		my $set_to_display = $self->{current_library_set};
		debug("set_to_display is $set_to_display");
		if (!defined $set_to_display || $set_to_display eq '') {
			$self->addbadmessage($r->maketext("You need to select a set definition file to view."));
		} else {
			@pg_files = $self->read_set_def($set_to_display);
			@pg_files = map { { 'filepath' => $_, 'morelt' => 0 } } @pg_files;
		}
		$use_previous_problems = 0;
	} elsif ($r->param('edit_local')) {
		# Edit the current local homework set
		# Already handled
	} elsif ($r->param('new_local_set')) {
		# Make a new local homework set
		if ($r->param('new_set_name') !~ /^[\w .-]*$/) {
			$self->addbadmessage($r->maketext(
				'The name "[_1]" is not a valid set name.  '
					. 'Use only letters, digits, dashes, underscores, periods, and spaces.',
				$r->param('new_set_name')
			));
		} else {
			# If we want to munge the input set name, do it here.
			my $newSetName = format_set_name_internal($r->param('new_set_name'));
			debug("local_sets was ", $r->param('local_sets'));
			$r->param('local_sets', $newSetName);    ## use of two parameter param
			debug("new value of local_sets is ", $r->param('local_sets'));
			if (!$newSetName) {
				$self->addbadmessage($r->maketext("You did not specify a new set name."));
			} elsif (defined $db->getGlobalSet($newSetName)) {
				$self->addbadmessage($r->maketext(
					"The set name '[_1]' is already in use.  Pick a different name if you would like to start a new set.",
					$newSetName
				));
			} else {                                 # Do it!
				my $newSetRecord = $db->newGlobalSet();
				$newSetRecord->set_id($newSetName);
				$newSetRecord->set_header("defaultHeader");
				$newSetRecord->hardcopy_header("defaultHeader");
				# It's convenient to set the due date two weeks from now so that it is
				# not accidentally available to students.

				my $dueDate    = time + 2 * 60 * 60 * 24 * 7;
				my $display_tz = $ce->{siteDefaults}{timezone};
				my $fDueDate   = $self->formatDateTime($dueDate, $display_tz, "%m/%d/%Y at %I:%M%P");
				my $dueTime    = $ce->{pg}{timeAssignDue};

				# We replace the due time by the one from the config variable
				# and try to bring it back to unix time if possible
				$fDueDate =~ s/\d\d:\d\d(am|pm|AM|PM)/$dueTime/;

				$dueDate = $self->parseDateTime($fDueDate, $display_tz);
				$newSetRecord->open_date($dueDate - 60 * $ce->{pg}{assignOpenPriorToDue});
				$newSetRecord->due_date($dueDate);
				$newSetRecord->answer_date($dueDate + 60 * $ce->{pg}{answersOpenAfterDueDate});

				$newSetRecord->visible(1);
				$newSetRecord->enable_reduced_scoring(0);
				$newSetRecord->assignment_type('default');
				eval { $db->addGlobalSet($newSetRecord) };
				if ($@) {
					$self->addbadmessage("Problem creating set $newSetName<br> $@");
				} else {
					$self->addgoodmessage($r->maketext("Set [_1] has been created.", $newSetName));
					assignSetToUser($db, $userName, $newSetRecord);
					$self->addgoodmessage($r->maketext("Set [_1] was assigned to [_2]", $newSetName, $userName));
				}
			}
		}
	} elsif ($r->param('next_page')) {
		# Can set first/last problem, but not index yet
		$first_index = $last_index + 1;
		my $oli = 0;
		my $cnt = 0;
		while (($oli = next_prob_group($last_index, @all_past_list)) != -1 and $cnt < $maxShown) {
			$cnt++;
			$last_index = $oli;
		}
		$last_index = end_prob_group($last_index, @all_past_list);
	} elsif ($r->param('prev_page')) {
		# Can set first/last index, but not problem yet
		$last_index = $first_index - 1;
		my $oli = 0;
		my $cnt = 0;
		while (($oli = prev_prob_group($first_index, @all_past_list)) != -1 and $cnt < $maxShown) {
			$cnt++;
			$first_index = $oli;
		}
		$first_index = 0 if ($first_index < 0);
	} elsif ($r->param('library_basic')) {
		$library_basic = 1;
		for my $jj (qw(textchapter textsection textbook)) {
			$r->param('library_' . $jj, undef);
		}
	} elsif ($r->param('library_advanced')) {
		$library_basic = 2;
	} elsif ($r->param('library_reset')) {
		for my $jj (qw(chapters sections subjects textbook textchapter textsection keywords)) {
			$r->param('library_' . $jj, undef);
		}
		$r->param('level', undef);
	} else {
		# No action requested, probably our first time here
	}

	# Get the list of local sets sorted by set_id.
	my @all_db_sets = map { $_->[0] } $db->listGlobalSetsWhere({}, 'set_id');

	if ($use_previous_problems) {
		@pg_files    = @all_past_list;
		$first_shown = 0;
		$last_shown  = 0;
		my ($oli, $cnt) = (0, 0);
		while ($oli < $first_index and ($oli = next_prob_group($first_shown, @pg_files)) != -1) {
			$cnt++;
			$first_shown = $oli;
		}
		$first_shown = $cnt;
		$last_shown  = $oli;
		while ($oli <= $last_index and $oli != -1) {
			$oli = next_prob_group($last_shown, @pg_files);
			$cnt++;
			$last_shown = $oli;
		}
		$last_shown  = $cnt - 1;
		$total_probs = $count;
	} else {
		# Main place to set first/last shown for new problems
		$first_shown = 0;
		$first_index = 0;
		$last_index  = 0;
		$last_shown  = 1;
		$total_probs = 0;
		my $oli = 0;
		while (($oli = next_prob_group($last_index, @pg_files)) != -1 and $last_shown < $maxShown) {
			$last_shown++;
			$last_index = $oli;
		}
		$total_probs = $last_shown;
		# $last_index points to start of last group
		$last_shown--;    # first_shown = 0
		$last_index = end_prob_group($last_index, @pg_files);
		$oli        = $last_index;
		while (($oli = next_prob_group($oli, @pg_files)) != -1) {
			$total_probs++;
		}
	}

	my $library_stats_handler = '';

	if ($ce->{problemLibrary}{showLibraryGlobalStats}
		|| $ce->{problemLibrary}{showLibraryLocalStats})
	{
		$library_stats_handler = WeBWorK::Utils::LibraryStats->new($ce);
	}

	my @plist = map { $_->{filepath} } @pg_files[ $first_index .. $last_index ];

	# If there are problems to view and a target set is selected, then create a hash of source files in the target set.
	if (@plist) {
		my $setName = $r->param('local_sets');
		if (defined $setName) {
			$self->{isInSet} =
				{ map { $_->[0] => 1 } $r->db->{problem}->get_fields_where(['source_file'], { set_id => $setName }) };
		}
	}

	# Now store data in self for retreival by body
	$self->{first_shown}           = $first_shown;
	$self->{last_shown}            = $last_shown;
	$self->{first_index}           = $first_index;
	$self->{last_index}            = $last_index;
	$self->{total_probs}           = $total_probs;
	$self->{browse_which}          = $browse_which;
	$self->{all_db_sets}           = \@all_db_sets;
	$self->{library_basic}         = $library_basic;
	$self->{library_stats_handler} = $library_stats_handler;
	$r->stash->{pg_files}          = \@pg_files;
	$r->stash->{plist}             = \@plist;

	return;
}

1;
