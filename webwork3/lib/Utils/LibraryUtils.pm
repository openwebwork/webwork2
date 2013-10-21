## This is a number of common subroutines needed when processing the routes.  


package Utils::LibraryUtils;
use base qw(Exporter);
use Dancer;
use Dancer::Plugin::Database;
use Data::Dumper;
use WeBWorK::Utils qw(readDirectory sortByName);
our @EXPORT    = ();
our @EXPORT_OK = qw(list_pg_files get_section_problems get_chapter_problems get_subject_problems);

my %ignoredir = (
	'.' => 1, '..' => 1, 'CVS' => 1, 'tmpEdit' => 1,
	'headers' => 1, 'macros' => 1, 'email' => 1, '.svn' => 1, 'achievements' => 1,
);

## this returns all problems in the library that matches the given subject


sub get_subject_problems {
	my ($subject) = @_;

	my $queryString = "select path.path,pg.filename "
					. "from OPL_DBsubject AS sub "
					. "INNER JOIN OPL_DBchapter AS ch ON sub.DBsubject_id = ch.DBsubject_id " 
					. "INNER JOIN OPL_DBsection AS sect ON sect.DBchapter_id = ch.DBchapter_id "
					. "INNER JOIN OPL_pgfile AS pg ON sect.DBsection_id = pg.DBsection_id "
					. "INNER JOIN OPL_path AS path ON pg.path_id = path.path_id "
					. "WHERE sub.name='" . $subject . "';";

	my $sth = database->prepare($queryString);
	$sth->execute;
	my $results = $sth->fetchall_arrayref;
	
	return $results;

}

## this returns all problems in the library that matches the given subject/chapter


sub get_chapter_problems {
	my ($subject,$chapter) = @_;

	my $queryString = "select path.path,pg.filename "
					. "from OPL_DBsection AS sect "
					. "INNER JOIN OPL_DBsubject AS sub "
					. "INNER JOIN OPL_DBchapter AS ch ON ch.DBchapter_id = sect.DBchapter_id "
					. "INNER JOIN OPL_pgfile AS pg ON sect.DBsection_id = pg.DBsection_id "
					. "INNER JOIN OPL_path AS path ON pg.path_id = path.path_id "
					. "WHERE ch.name='" . $chapter . "' and sub.name='" . $subject . "';";

	my $sth = database->prepare($queryString);
	$sth->execute;
	my $results = $sth->fetchall_arrayref;
	
	return $results;
}



## this returns all problems in the library that matches the given subject/chapter/section


sub get_section_problems {
	my ($subject,$chapter,$section) = @_;

	my $queryString = "select path.path,pg.filename "
					. "from OPL_DBsection AS sect "
					. "INNER JOIN OPL_DBchapter AS ch INNER JOIN OPL_DBsubject AS sub "
					. "INNER JOIN OPL_pgfile AS pg ON sect.DBsection_id = pg.DBsection_id "
					. "INNER JOIN OPL_path AS path ON pg.path_id = path.path_id "
					. "WHERE sect.name='" . $section . "' AND ch.name='" . $chapter . "'"
					. "and sub.name='" . $subject . "';";

	my $sth = database->prepare($queryString);
	$sth->execute;
	my $results = $sth->fetchall_arrayref;
	
	return $results;
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

# sub get_library_sets {
	
# 	my ($top,$base,$dir,$probLib) = @_;
# 	# ignore directories that give us an error
# 	my @lis = eval { readDirectory($dir) };
# 	if ($@) {
# 		warn $@;
# 		return (0);
# 	}
# 	return (0) if grep /^=library-ignore$/, @lis;

# 	my @pgfiles = grep { m/\.pg$/ and (not m/(Header|-text)(File)?\.pg$/) and -f "$dir/$_"} @lis;
# 	my $pgcount = scalar(@pgfiles);
# 	my $pgname = $dir; $pgname =~ s!.*/!!; $pgname .= '.pg';
# 	my $combineUp = ($pgcount == 1 && $pgname eq $pgfiles[0] && !(grep /^=library-no-combine$/, @lis));

# 	my @pgdirs;
# 	my @dirs = grep {!$ignoredir{$_} and -d "$dir/$_"} @lis;
# 	if ($top == 1) {@dirs = grep {!$problib{$_}} @dirs}
# 	# Never include Library at the top level
# 	if ($top == 1) {@dirs = grep {$_ ne 'Library'} @dirs} 
# 	foreach my $subdir (@dirs) {
# 		my @results = get_library_sets(0, "$dir/$subdir");
# 		$pgcount += shift @results; push(@pgdirs,@results);
# 	}

# 	return ($pgcount, @pgdirs) if $top || $combineUp || grep /^=library-combine-up$/, @lis;
# 	return (0,@pgdirs,$dir);
# }


# sub get_library_pgs {

# 	#print join(",",@_) . "\n";

# 	my ($top,$base,$dir,$probLib) = @_;

# 	debug "top: $top  base: $base dir:  $dir probLib: $probLib \n";
# 	debug Dumper($probLib);
# 	my @lis = readDirectory("$base/$dir");
# 	return () if grep /^=library-ignore$/, @lis;
# 	return () if !$top && grep /^=library-no-combine$/, @lis;

# 	my @pgs = grep { m/\.pg$/ and (not m/(Header|-text)\.pg$/) and -f "$base/$dir/$_"} @lis;
# 	my $others = scalar(grep { (!m/\.pg$/ || m/(Header|-text)\.pg$/) &&
# 	                            !m/(\.(tmp|bak)|~)$/ && -f "$base/$dir/$_" } @lis);

# 	my @dirs = grep {!$ignoredir{$_} and -d "$base/$dir/$_"} @lis;
# 	if ($top == 1) {@dirs = grep {!$problib->{$_}} @dirs}

# 	debug Dumper(@dirs);

# 	foreach my $subdir (@dirs) {push(@pgs, get_library_pgs(0,"$base/$dir",$subdir,$probLib))}

# 	return () unless $top || (scalar(@pgs) == 1 && $others) || grep /^=library-combine-up$/, @lis;
# 	return (map {"$dir/$_"} @pgs);
# } 

sub list_pg_files {
	my ($templates,$dir,$probLib) = @_;
	#print "templates: $templates    dir: $dir   problib: $probLib \n";
	my $top = ($dir eq '.')? 1 : 2;
	my @pgs = get_library_pgs($top,$templates,$dir,$probLib);
	return sortByName(undef,@pgs);
}

## Search for set definition files

sub get_set_defs {
	my $topdir = shift;
	my @found_set_defs;
	# get_set_defs_wanted is a closure over @found_set_defs
	my $get_set_defs_wanted = sub {
		#my $fn = $_;
		#my $fdir = $File::Find::dir;
		#return() if($fn !~ /^set.*\.def$/);
		##return() if(not -T $fn);
		#push @found_set_defs, "$fdir/$fn";
		push @found_set_defs, $_ if m|/set[^/]*\.def$|;
	};
	find({ wanted => $get_set_defs_wanted, follow_fast=>1, no_chdir=>1}, $topdir);
	map { $_ =~ s|^$topdir/?|| } @found_set_defs;
	return @found_set_defs;
}

## Try to make reading of set defs more flexible.  Additional strategies
## for fixing a path can be added here.

sub munge_pg_file_path {
	my $self = shift;
	my $pg_path = shift;
	my $path_to_set_def = shift;
	my $end_path = $pg_path;
	# if the path is ok, don't fix it
	return($pg_path) if(-e $self->r->ce->{courseDirs}{templates}."/$pg_path");
	# if we have followed a link into a self contained course to get
	# to the set.def file, we need to insert the start of the path to
	# the set.def file
	$end_path = "$path_to_set_def/$pg_path";
	return($end_path) if(-e $self->r->ce->{courseDirs}{templates}."/$end_path");
	# if we got this far, this path is bad, but we let it produce
	# an error so the user knows there is a troublesome path in the
	# set.def file.
	return($pg_path);
}