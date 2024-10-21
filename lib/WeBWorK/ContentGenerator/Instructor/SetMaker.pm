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
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::SetMaker - Make homework sets.

=cut

use Mojo::File;

use WeBWorK::Debug;
use WeBWorK::Utils             qw(sortByName x);
use WeBWorK::Utils::DateTime   qw(getDefaultSetDueDate);
use WeBWorK::Utils::Instructor qw(assignSetToUser assignProblemToAllSetUsers addProblemToSet);
use WeBWorK::Utils::LibraryStats;
use WeBWorK::Utils::ListingDB qw(getDBListings);
use WeBWorK::Utils::Sets      qw(format_set_name_internal);
use WeBWorK::Utils::Tags;

# Use x to mark strings for maketext
use constant MY_PROBLEMS   => x('My Problems');
use constant MAIN_PROBLEMS => x('Unclassified Problems');

# Flags for operations on files
use constant ADDED   => 1;
use constant HIDDEN  => (1 << 1);
use constant SUCCESS => (1 << 2);

my %ignoredir = (
	'tmpEdit'      => 1,
	'headers'      => 1,
	'macros'       => 1,
	'email'        => 1,
	'graphics'     => 1,
	'achievements' => 1,
);

sub prepare_activity_entry ($c) {
	my $user = $c->param('user') || 'NO_USER';
	return ("In SetMaker as user $user");
}

# This searches the disk for directories containing pg files.  To make the
# recursion work, this returns an array where the first item is the number of pg
# files in the directory followed by a list of directories which contain pg
# files.
#
# If a directory contains only one pg file, the directory name is the same as
# the file name, and there are other files in the directory (that are not set
# header files, tmp files or bak files) then the directory is considered to be
# part of the parent directory (it is probably in a separate directory only
# because it has auxiliary files that want to be kept together with the pg
# file).
#
# If a directory has a file named "=library-ignore", it is never included in the
# directory menu.  If a directory contains a file called "=library-combine-up",
# then its pg are included with those in the parent directory (and the directory
# does not appear in the menu).  If it has a file called "=library-no-combine"
# then it is always listed as a separate directory even if it contains only one
# pg file.
sub get_course_pg_dirs ($c, $top, $dir) {
	# Note that this does not include hidden files or directories.
	my $lis = eval { $dir->list({ dir => 1 }) };

	# Ignore directories that give an error.
	return 0 if $@;

	return 0 if $lis->grep(sub { $_->basename eq '=library-ignore' })->size;

	my $pgfiles = $lis->grep(sub { -f && m/\.pg$/ && !m/(Header|-text)(File)?\.pg$/ });
	my $pgcount = $pgfiles->size;

	my $dirs = $lis->grep(sub { !$ignoredir{ $_->basename } && -d });
	$dirs = $dirs->grep(sub { !$c->{problibs}{ $_->basename } }) if $top == 1;

	# Never include Library or Contrib at the top level
	$dirs = $dirs->grep(sub { $_->basename ne 'Library' && $_->basename ne 'Contrib' }) if $top == 1;

	my @pgdirs;
	for my $subdir (@$dirs) {
		my @results = $c->get_course_pg_dirs(0, $subdir);
		$pgcount += shift @results;
		push(@pgdirs, @results);
	}

	return ($pgcount, @pgdirs)
		if $top
		|| ($pgfiles->size == 1
			&& ($dir->basename . '.pg') eq $pgfiles->first->basename
			&& $lis->grep(sub { -f && (!m/\.pg$/ || m/(Header|-text)\.pg$/) && !m/(\.(tmp|bak)|~)$/ })->size
			&& !$lis->grep(sub { $_->basename eq '=library-no-combine' })->size)
		|| $lis->grep(sub { $_->basename eq '=library-combine-up' })->size
		|| !$pgcount;
	return (0, @pgdirs, $dir->to_string);
}

# Important: Make sure that the list of pg files that this returns is kept in sync with the directories that are
# returned by the above method.  Most importantly, if a directory is not listed by the above method and it does not
# contain a file named =library-ignore, then the pg files in that directory should be listed with the pg files of the
# parent directory, and if a directory is listed by the above method, then the pg files in that directory should not be
# listed for the parent directory.
sub get_pg_files_in_dir ($c, $top, $base, $dir) {
	my $lis = $base->child($dir)->list({ dir => 1 });
	return if $lis->grep(sub { $_->basename eq '=library-ignore' })->size;
	return if !$top && $lis->grep(sub { $_->basename eq '=library-no-combine' })->size;

	my $pgs = $lis->grep(sub { m/\.pg$/ && !m/(Header|-text)\.pg$/ && -f })->map('basename');

	my $dirs = $lis->grep(sub { !$ignoredir{ $_->basename } && -d });
	$dirs = $dirs->grep(sub { !$c->{problibs}{ $_->basename } }) if $top == 1;

	for my $subdir (@$dirs) { push(@$pgs, $c->get_pg_files_in_dir(0, $base->child($dir), $subdir->basename)) }

	return
		unless $top
		|| ($pgs->size == 1
			&& $pgs->first eq "$dir.pg"
			&& $lis->grep(sub { -f && (!m/\.pg$/ || m/(Header|-text)\.pg$/) && !m/(\.(tmp|bak)|~)$/ })->size)
		|| $lis->grep(sub { $_->basename eq '=library-combine-up' })->size;
	return @{ $pgs->map(sub {"$dir/$_"}) };
}

sub list_pg_files ($c, $templates, $dir) {
	my $top = ($dir eq '.') ? 1 : 2;
	my @pgs = $c->get_pg_files_in_dir($top, Mojo::File->new($templates), $dir);
	return sortByName(undef, @pgs);
}

## Try to make reading of set defs more flexible.  Additional strategies
## for fixing a path can be added here.

sub munge_pg_file_path ($c, $pg_path, $path_to_set_def) {
	my $end_path = $pg_path;
	# if the path is ok, don't fix it
	return ($pg_path) if (-e $c->ce->{courseDirs}{templates} . "/$pg_path");
	# if we have followed a link into a self contained course to get
	# to the set.def file, we need to insert the start of the path to
	# the set.def file
	$end_path = "$path_to_set_def/$pg_path";
	return ($end_path) if (-e $c->ce->{courseDirs}{templates} . "/$end_path");
	# if we got this far, this path is bad, but we let it produce
	# an error so the user knows there is a troublesome path in the
	# set.def file.
	return ($pg_path);
}

## Problems straight from the OPL database come with MO and static
## tag information.  This is for other times, like next/prev page.

sub getDBextras ($c, $sourceFileName) {
	if ($sourceFileName =~ /^Library/) {
		return @{ WeBWorK::Utils::ListingDB::getDBextras($c, $sourceFileName) };
	}

	my $filePath = $c->ce->{courseDirs}{templates} . "/$sourceFileName";
	return (0, 0) unless -r $filePath;

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
sub read_set_def ($c, $filePathOrig) {
	my $filePath = $c->ce->{courseDirs}{templates} . "/$filePathOrig";
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
		$c->addbadmessage($c->maketext("Cannot open [_1]", $filePath));
	}
	# This is where we would potentially munge the pg file paths
	# One possibility
	@pg_files = map { $c->munge_pg_file_path($_, $filePathOrig) } @pg_files;
	return (@pg_files);
}

## go through past page getting a list of identifiers for the problems
## and whether or not they are selected, and whether or not they should
## be hidden

sub get_past_problem_files ($c) {
	my @found = ();
	my $count = 1;
	while (defined($c->param("filetrial$count"))) {
		my $val = 0;
		$val |= ADDED  if ($c->param("trial$count"));
		$val |= HIDDEN if ($c->param("hideme$count"));
		push @found, [ $c->param("filetrial$count"), $val ];
		$count++;
	}
	return (\@found);
}

#### For adding new problems

sub add_selected ($c, $db, $setName) {
	my @past_problems = @{ $c->{past_problems} };
	my @selected      = @past_problems;
	my $freeProblemID;

	my $addedcount = 0;

	for my $selected (@selected) {
		if ($selected->[1] & ADDED) {
			my $file          = $selected->[0];
			my $problemRecord = addProblemToSet(
				$db, $c->ce->{problemDefaults},
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

sub get_problem_directories ($c, $lib) {
	my $ce            = $c->ce;
	my $source        = $ce->{courseDirs}{templates};
	my $main_problems = $c->maketext(MY_PROBLEMS);
	my $isTop         = 1;
	if ($lib) { $source .= "/$lib"; $main_problems = $c->maketext(MAIN_PROBLEMS); $isTop = 2 }
	my @all_problem_directories = $c->get_course_pg_dirs($isTop, Mojo::File->new($source));
	my $includetop              = shift @all_problem_directories;

	for (my $j = 0; $j < scalar(@all_problem_directories); $j++) {
		$all_problem_directories[$j] =~ s|^$ce->{courseDirs}->{templates}/?||;
	}
	@all_problem_directories = sortByName(undef, @all_problem_directories);
	unshift @all_problem_directories, $main_problems if ($includetop);
	return (\@all_problem_directories);
}

### Mainly deal with more like this

sub process_search ($c, @dbsearch) {
	# Build a hash of MLT entries keyed by morelt_id
	my %mlt = ();
	my $mltind;
	for my $indx (0 .. $#dbsearch) {
		$dbsearch[$indx]{oindex} = $indx;
		if ($mltind = $dbsearch[$indx]{morelt}) {
			if (defined($mlt{$mltind})) {
				push @{ $mlt{$mltind} }, $indx;
			} else {
				$mlt{$mltind} = [$indx];
			}
		}
	}
	# Now we have a hash of mlt entries.

	# Find MLT leaders, mark entries for no show,
	# set up children array for leaders
	for my $mltid (keys %mlt) {
		my @idlist = @{ $mlt{$mltid} };
		if (scalar(@idlist) > 1) {
			my $leader = WeBWorK::Utils::ListingDB::getMLTleader($c, $mltid) || 0;
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

sub pre_header_initialize ($c) {
	# Make sure these are defined for the templates.
	$c->stash->{pg_files} = [];
	$c->stash->{plist}    = [];

	$c->{error} = 0;
	my $ce       = $c->ce;
	my $db       = $c->db;
	my $maxShown = $c->param('max_shown') || 20;
	$maxShown = 10000000 if ($maxShown eq 'All');    # let's hope there aren't more
	my $library_basic = $c->param('library_is_basic') || 1;
	$c->{problem_seed} = $c->param('problem_seed') || 1234;

	# Grab library sets to display from parameters list.  We will modify this as we go through the if/else tree.
	$c->{current_library_set} = $c->param('library_sets');

	# These directories will have individual buttons
	$c->{problibs} = $ce->{courseFiles}{problibs} // {};

	my $userName = $c->param('user');
	my $user     = $db->getUser($userName);          # checked
	die "record for user $userName (real user) does not exist."
		unless defined $user;
	my $authz = $c->authz;

	return unless ($authz->hasPermissions($userName, "modify_problem_sets"));

	# Now one action we have to deal with here
	if ($c->param('edit_local')) {
		my $db       = $c->db;
		my $checkset = $db->getGlobalSet($c->param('local_sets'));
		if (not defined($checkset)) {
			$c->{error} = 1;
			$c->addbadmessage($c->maketext('You need to select a "Target Set" before you can edit it.'));
		} else {
			$c->reply_with_redirect(
				$c->systemLink($c->url_for('instructor_set_detail', setID => $c->param('local_sets'))));
		}
	}

	# Next, lots of set up so that errors can be reported with message()

	# List of problems we have already printed
	# If we don't end up reusing problems, this will be wiped out.
	# If we do redisplay the same problems, we must adjust this accordingly.
	$c->{past_problems} = get_past_problem_files($c);

	my $none_shown            = @{ $c->{past_problems} } == 0;
	my @pg_files              = ();
	my $use_previous_problems = 1;
	my $first_shown           = $c->param('first_shown') || 0;
	my $last_shown            = $c->param('last_shown');
	if (not defined($last_shown)) {
		$last_shown = -1;
	}
	my $first_index = $c->param('first_index') || 0;
	my $last_index  = $c->param('last_index');
	if (not defined($last_index)) {
		$last_index = -1;
	}
	my $total_probs   = $c->param('total_probs') || 0;
	my @all_past_list = ();                              # These include requested, but not shown
	my ($j, $count, $omlt, $nmlt, $hold) = (0, 0, -1, 0, 0);
	while (defined($c->param("all_past_list$j"))) {
		$nmlt = $c->param("all_past_mlt$j") || 0;
		push @all_past_list, { 'filepath' => $c->param("all_past_list$j"), 'morelt' => $nmlt };
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
	my $browse_which = $c->param('browse_which') || 'browse_opl';

	# Check for problem lib buttons
	my $browse_lib = '';
	for my $lib (keys %{ $c->{problibs} }) {
		if ($c->param("browse_$lib")) {
			$browse_lib = "browse_$lib";
			last;
		}
	}

	# Start the logic through if elsif elsif ...
	debug("browse_lib",         $c->param("$browse_lib"));
	debug("browse_opl",         $c->param("browse_opl"));
	debug("browse_course_sets", $c->param("browse_course_sets"));
	debug("browse_setdefs",     $c->param("browse_setdefs"));
	# Asked to browse certain problems
	if ($browse_lib ne '') {
		$browse_which             = $browse_lib;
		$c->{current_library_set} = "";
		$use_previous_problems    = 0;
		@pg_files                 = ();
	} elsif ($c->param('browse_opl')) {
		$browse_which             = 'browse_opl';
		$c->{current_library_set} = "";
		$use_previous_problems    = 0;
		@pg_files                 = ();
	} elsif ($c->param('browse_local')) {
		$browse_which          = 'browse_local';
		$use_previous_problems = 0;
		@pg_files              = ();
	} elsif ($c->param('browse_course_sets')) {
		$browse_which          = 'browse_course_sets';
		$use_previous_problems = 0;
		@pg_files              = ();
	} elsif ($c->param('browse_setdefs')) {
		$browse_which             = 'browse_setdefs';
		$c->{current_library_set} = "";
		$use_previous_problems    = 0;
		@pg_files                 = ();
	} elsif ($c->param('rerandomize')) {
		# Change the seed value
		$c->{problem_seed} = 1 + $c->{problem_seed};
		$c->addbadmessage($c->maketext('Changing the problem seed for display, but there are no problems showing.'))
			if $none_shown;
	} elsif ($c->param('cleardisplay')) {
		# Clear the display
		@pg_files              = ();
		$use_previous_problems = 0;
	} elsif ($c->param('view_local_set')) {
		# View problems selected from the local list
		my $set_to_display = $c->{current_library_set};
		if (!defined $set_to_display || $set_to_display eq '') {
			$c->addbadmessage($c->maketext('You need to select a set to view.'));
		} else {
			$set_to_display        = '.'                      if $set_to_display eq $c->maketext(MY_PROBLEMS);
			$set_to_display        = substr($browse_which, 7) if $set_to_display eq $c->maketext(MAIN_PROBLEMS);
			@pg_files              = $c->list_pg_files($ce->{courseDirs}{templates}, $set_to_display);
			@pg_files              = map { { 'filepath' => $_, 'morelt' => 0 } } @pg_files;
			$use_previous_problems = 0;
		}
	} elsif ($c->param('view_course_set')) {
		# View problems selected from a set in this course
		my $set_to_display = $c->{current_library_set} // '';
		debug("set_to_display is $set_to_display");
		if ($set_to_display eq '') {
			$c->addbadmessage($c->maketext("You need to select a set from this course to view."));
		} else {
			@pg_files = map { { 'filepath' => $_->source_file, 'morelt' => 0 } }
				$db->getGlobalProblemsWhere({ set_id => $set_to_display });
			$use_previous_problems = 0;
		}
	} elsif ($c->param('lib_view')) {
		# View from the library database
		@pg_files              = process_search($c, getDBListings($c, 0));
		$use_previous_problems = 0;
	} elsif ($c->param('view_setdef_set')) {
		# View a set from a set*.def
		my $set_to_display = $c->{current_library_set} // '';
		debug("set_to_display is $set_to_display");
		if ($set_to_display eq '') {
			$c->addbadmessage($c->maketext("You need to select a set definition file to view."));
		} else {
			@pg_files = $c->read_set_def($set_to_display);
			@pg_files = map { { 'filepath' => $_, 'morelt' => 0 } } @pg_files;
		}
		$use_previous_problems = 0;
	} elsif ($c->param('edit_local')) {
		# Edit the current local homework set
		# Already handled
	} elsif ($c->param('new_local_set')) {
		# Make a new local homework set
		if ($c->param('new_set_name') !~ /^[\w .-]*$/) {
			$c->addbadmessage($c->maketext(
				'The name "[_1]" is not a valid set name.  '
					. 'Use only letters, digits, dashes, underscores, periods, and spaces.',
				$c->param('new_set_name')
			));
		} else {
			my $newSetName = format_set_name_internal($c->param('new_set_name'));
			debug("local_sets was ", $c->param('local_sets'));
			$c->param('local_sets', $newSetName);
			debug("new value of local_sets is ", $c->param('local_sets'));

			if (!$newSetName) {
				$c->addbadmessage($c->maketext('Please specify a new set name.'));
			} elsif (defined $db->getGlobalSet($newSetName)) {
				$c->addbadmessage($c->maketext('The set "[_1]" already exists.', $newSetName));
			} else {
				my $dueDate = getDefaultSetDueDate($ce);

				my $newSetRecord = $db->newGlobalSet();
				$newSetRecord->set_id($newSetName);
				$newSetRecord->set_header('defaultHeader');
				$newSetRecord->hardcopy_header('defaultHeader');
				$newSetRecord->open_date($dueDate - 60 * $ce->{pg}{assignOpenPriorToDue});
				$newSetRecord->reduced_scoring_date($dueDate - 60 * $ce->{pg}{ansEvalDefaults}{reducedScoringPeriod});
				$newSetRecord->due_date($dueDate);
				$newSetRecord->answer_date($dueDate + 60 * $ce->{pg}{answersOpenAfterDueDate});
				$newSetRecord->visible(1);
				$newSetRecord->enable_reduced_scoring(0);
				$newSetRecord->assignment_type('default');

				eval { $db->addGlobalSet($newSetRecord) };
				if ($@) {
					$c->addbadmessage($c->maketext('Problem creating set "[_1]": [_2]', $newSetName, $@));
				} else {
					$c->addgoodmessage($c->maketext("Set [_1] has been created.", $newSetName));
					assignSetToUser($db, $userName, $newSetRecord);
					$c->addgoodmessage($c->maketext("Set [_1] was assigned to [_2]", $newSetName, $userName));
				}
			}
		}
	} elsif ($c->param('next_page')) {
		# Can set first/last problem, but not index yet
		$first_index = $last_index + 1;
		my $oli = 0;
		my $cnt = 0;
		while (($oli = next_prob_group($last_index, @all_past_list)) != -1 and $cnt < $maxShown) {
			$cnt++;
			$last_index = $oli;
		}
		$last_index = end_prob_group($last_index, @all_past_list);
	} elsif ($c->param('prev_page')) {
		# Can set first/last index, but not problem yet
		$last_index = $first_index - 1;
		my $oli = 0;
		my $cnt = 0;
		while (($oli = prev_prob_group($first_index, @all_past_list)) != -1 and $cnt < $maxShown) {
			$cnt++;
			$first_index = $oli;
		}
		$first_index = 0 if ($first_index < 0);
	} elsif ($c->param('library_basic')) {
		$library_basic = 1;
		for my $jj (qw(textchapter textsection textbook)) {
			$c->param('library_' . $jj, undef);
		}
	} elsif ($c->param('library_advanced')) {
		$library_basic = 2;
	} elsif ($c->param('library_reset')) {
		for my $jj (qw(chapter section subject textbook textchapter textsection keywords)) {
			$c->param('library_' . $jj, undef);
		}
		$c->param('level', undef);
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
		my $setName = $c->param('local_sets');
		if (defined $setName) {
			$c->{isInSet} =
				{ map { $_->[0] => 1 } $c->db->{problem}->get_fields_where(['source_file'], { set_id => $setName }) };
		}
	}

	# Now store data in self for retreival by body
	$c->{first_shown}           = $first_shown;
	$c->{last_shown}            = $last_shown;
	$c->{first_index}           = $first_index;
	$c->{last_index}            = $last_index;
	$c->{total_probs}           = $total_probs;
	$c->{browse_which}          = $browse_which;
	$c->{all_db_sets}           = \@all_db_sets;
	$c->{library_basic}         = $library_basic;
	$c->{library_stats_handler} = $library_stats_handler;
	$c->stash->{pg_files}       = \@pg_files;
	$c->stash->{plist}          = \@plist;

	return;
}

1;
