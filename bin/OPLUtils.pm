

package OPLUtils;
use base qw(Exporter);

# This file contains the subroutines that build JSON files from the database to help speed up the client side. 
#
#  The following files are created:
#		1. $webwork_htdocs/DATA/library-directory-tree.json  (the directory structure of the library)
#		2. $webwork_htdocs/DATA/library-subject-tree.json  (the subject/chapter/section struture of the library)
#		3. 

# This is used to create the file library-directory-tree.json which can be used to load in 
# directory information for the OPL.  It writes the file as a JSON of directories to be easily loaded. 

use strict;
use warnings;
use File::Find::Rule;
use File::Basename;
use open qw/:std :utf8/;
# use Cwd;
# use DBI;
use JSON;

our @EXPORT    = ();
our @EXPORT_OK = qw(build_library_directory_tree build_library_subject_tree build_library_textbook_tree);

### Data for creating the database tables


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





sub build_library_directory_tree {
	my $ce = shift;

	print "Creating the Directory Tree\n";
	my $libraryRoot = $ce->{problemLibrary}->{root};
	$libraryRoot =~ s|/+$||;

	my $libraryVersion = $ce->{problemLibrary}->{version};

	my($filename, $directories) = fileparse($libraryRoot);

	my @dirArray = ();
	push(@dirArray,buildTree($libraryRoot));

	my $webwork_htdocs = $ce->{webwork_dir}."/htdocs";
	my $file = "$webwork_htdocs/DATA/library-directory-tree.json";

	# use a variable for the file handle
	my $OUTFILE;

	# use the three arguments version of open
	# and check for errors
	open $OUTFILE, '>encoding(UTF-8)', $file  or die "Cannot open $file";

	# you can check for errors (e.g., if after opening the disk gets full)
	print { $OUTFILE } to_json(\@dirArray) or die "Cannot write to $file";

	# check for errors
	close $OUTFILE or die "Cannot close $file";


	print "Wrote Library Directory Tree to $file\n";

}

sub buildTree {
	my $absoluteDir = shift;
	my $branch = {};
	my ($name,$dir) = fileparse($absoluteDir);
	$branch->{name} = $name;
	my @dirs = File::Find::Rule->maxdepth(1)->relative(1)->directory->in($absoluteDir);
	if (scalar(@dirs)==0){
		return undef;
	}

	my @branches = ();

	for my $dir (@dirs){
		my $theBranch = buildTree($absoluteDir . "/" . $dir);
		if ($theBranch) {
			my @files = File::Find::Rule->file()->name("*.pg")->in($absoluteDir . "/" . $dir);
			$theBranch->{num_files} = scalar(@files);
			push(@branches,$theBranch)
		} else {
			$b = {};
			$b->{name} = $dir;
			
			my @files = File::Find::Rule->file()->name("*.pg")->in($absoluteDir . "/" . $dir);
			
			#print $absoluteDir . "/" . $dir . "   " . $b->{num_files} . "\n";
			if (scalar(@files)>0){
				$b->{num_files} = scalar(@files);
				push(@branches,$b);
			}
		}
	}

	$branch->{subfields} = \@branches;
	my @files = File::Find::Rule->file()->name("*.pg")->in($absoluteDir);
	$branch->{num_files} = scalar(@files);


	return $branch;
}


sub build_library_subject_tree {
	my ($ce,$dbh) = @_;

	my $libraryRoot = $ce->{problemLibrary}->{root};
	$libraryRoot =~ s|/+$||;
	my $libraryVersion = $ce->{problemLibrary}->{version};


	my %tables = ($libraryVersion eq '2.5')? %OPLtables : %NPLtables;


	my $selectClause = "select subj.name, ch.name, sect.name, path.path,pg.filename from `$tables{dbsection}` AS sect "
		."JOIN `$tables{dbchapter}` AS ch ON ch.DBchapter_id = sect.DBchapter_id "
		."JOIN `$tables{dbsubject}` AS subj ON subj.DBsubject_id = ch.DBsubject_id "
		."JOIN `$tables{pgfile}` AS pg ON sect.DBsection_id = pg.DBsection_id "
		."JOIN `$tables{path}` AS path ON pg.path_id = path.path_id ";

	my $tree;  # the library subject tree will be stored as arrays of objects. 

	my $results = $dbh->selectall_arrayref("select subj.name from `$tables{dbsubject}` AS subj");

	my @subject_names = map { $_->[0]} @{$results};

	my $i=0; # counter to print to the screen.

	print "Building the subject-tree.  There are " . scalar(@subject_names) . " subjects\n";

	my @subject_tree;  # array to store the individual library tree for each subject 

	for my $subj_name (@subject_names){
		
		my $subj = $subj_name;
		$subj =~ s/'/\'/g;


		my $results = $dbh->selectall_arrayref("select ch.name from `$tables{dbsubject}` AS subj JOIN `$tables{dbchapter}` AS ch "
				. " ON subj.DBsubject_id = ch.DBsubject_id WHERE subj.name='$subj';");
		my @chapter_names = map {$_->[0]} @{$results};

		my @chapter_tree; # array to store the individual library tree for each chapter

		#print Dumper(\@chapter_names);

		for my  $ch_name (@chapter_names){
		
			my $ch = $ch_name;
			$ch =~ s/'/\'/g;

			my $results = $dbh->selectall_arrayref("SELECT sect.name from `$tables{dbsubject}` AS subj "
					."JOIN `$tables{dbchapter}` AS ch ON subj.DBsubject_id = ch.DBsubject_id "
					."JOIN `$tables{dbsection}` AS sect ON sect.DBchapter_id = ch.DBchapter_id "
					."WHERE subj.name='$subj' AND ch.name='$ch';");

			my @section_names = map { $_->[0]} @{$results};

			my @subfields = ();
			
			for my $sect_name (@section_names){
				my $section_tree = {};
				$section_tree->{name} = $sect_name;
				## Determine the number of files that falls into each

				my $sect = $section_tree->{name};
				$sect =~ s/'/\\'/g;

				my $whereClause ="WHERE sect.name='$sect' AND ch.name='$ch' AND subj.name='$subj'";

				my $sth = $dbh->prepare($selectClause.$whereClause);
				$sth->execute;
				my $numFiles= scalar @{$sth->fetchall_arrayref()};

				$section_tree->{num_files} = $numFiles;

				my $clone = { %{ $section_tree } };  # need to clone it before pushing into the @subfield array.

			    push(@subfields,$clone);
		    }

			my $chapter_tree;
			$chapter_tree->{name} = $ch_name;
			$chapter_tree->{subfields} = \@subfields;

			## determine the number of files in each chapter

			my $whereClause ="WHERE subj.name='$subj' AND ch.name='$ch'";


			my $sth = $dbh->prepare($selectClause.$whereClause);
			$sth->execute;
			my $numFiles = scalar @{$sth->fetchall_arrayref()};
			# my $allFiles = $sth->fetchall_arrayref;
			 $chapter_tree->{num_files} = $numFiles;

			my $clone = { %{ $chapter_tree } };  # need to clone it before pushing into the @chapter_tree array.
			push(@chapter_tree,$clone);



		}

		my $subject_tree; 
		$subject_tree->{name} = $subj_name;
		$subject_tree->{subfields} = \@chapter_tree; 

		## find the number of files on the subject level

		my $whereClause ="WHERE subj.name='$subj'";


		my $sth = $dbh->prepare($selectClause.$whereClause);
		$sth->execute;
		my $numFiles = scalar @{$sth->fetchall_arrayref()};
		$subject_tree->{num_files} = $numFiles;

		$i++;

		print sprintf("%3d", $i);

		if ($i%10 == 0) {
		    print "\n";
		}

		my $clone = { % {$subject_tree}};
		push (@subject_tree, $clone);
	}

	print "\n";

	my $webwork_htdocs = $ce->{webwork_dir}."/htdocs";
	my $file = "$webwork_htdocs/DATA/library-subject-tree.json";

	# use a variable for the file handle
	my $OUTFILE;

	# use the three arguments version of open
	# and check for errors
	open $OUTFILE, '>encoding(UTF-8)', $file  or die "Cannot open $file";

	# you can check for errors (e.g., if after opening the disk gets full)
	print { $OUTFILE } to_json(\@subject_tree,{pretty=>1}) or die "Cannot write to $file";

	# check for errors
	close $OUTFILE or die "Cannot close $file";


	print "Wrote Library Subject Tree to $file\n";
}

sub build_library_textbook_tree {

	my ($ce,$dbh) = @_;

	my $libraryRoot = $ce->{problemLibrary}->{root};
	$libraryRoot =~ s|/+$||;
	my $libraryVersion = $ce->{problemLibrary}->{version};

	my %tables = ($libraryVersion eq '2.5')? %OPLtables : %NPLtables;


	my $selectClause = "SELECT pg.pgfile_id from `$tables{path}` as path "
		."LEFT JOIN `$tables{pgfile}` AS pg ON pg.path_id=path.path_id "
		."LEFT JOIN `$tables{pgfile_problem}` AS pgprob ON pgprob.pgfile_id=pg.pgfile_id "
		."LEFT JOIN `$tables{problem}` AS prob ON prob.problem_id=pgprob.problem_id "
		."LEFT JOIN `$tables{section}` AS sect ON sect.section_id=prob.section_id "
		."LEFT JOIN `$tables{chapter}` AS ch ON ch.chapter_id=sect.chapter_id "
		."LEFT JOIN `$tables{textbook}` AS text ON text.textbook_id=ch.textbook_id ";

	my $results = $dbh->selectall_arrayref("select * from `$tables{textbook}` ORDER BY title;");

	my @textbooks=map { {textbook_id=>$_->[0],title=>$_->[1],edition=>$_->[2],
			author=>$_->[3],publisher=>$_->[4],isbn=>$_->[5],pubdate=>$_->[6]}} @{$results};

	my $i =0; ## index to alert user the length of the build

	print "Building the Textbook Library Tree\n";
	print "There are ". $#textbooks ." textbooks to process.\n";

	for my $textbook (@textbooks){
		$i++;
		printf("%4d",$i);
		print("\n") if ($i %10==0);

		my $results = $dbh->selectall_arrayref("select ch.chapter_id,ch.name,ch.number "
			. " from `$tables{chapter}` AS ch JOIN `$tables{textbook}` AS text ON ch.textbook_id=text.textbook_id "
			. " WHERE text.textbook_id='" . $textbook->{textbook_id} . "' ORDER BY ch.number;");

		my @chapters=map { {chapter_id=>$_->[0],name=>$_->[1],number=>$_->[2]}} @{$results};

		for my $chapter (@chapters){

			my $results = $dbh->selectall_arrayref("select sect.section_id,sect.name,sect.number "
				. "FROM `$tables{chapter}` AS ch "
				. "LEFT JOIN `$tables{textbook}` AS text ON ch.textbook_id=text.textbook_id "
				. "LEFT JOIN `$tables{section}` AS sect ON sect.chapter_id = ch.chapter_id "
				. "WHERE text.textbook_id='" .$textbook->{textbook_id}. "' AND "
				. "ch.chapter_id='".$chapter->{chapter_id}."' ORDER BY sect.number;");


			my @sections = map { {section_id=>$_->[0],name=>$_->[1],number=>$_->[2]}} @{$results};

			for my $section (@sections){

		   		my $whereClause ="WHERE sect.section_id='". $section->{section_id} 
		   			."' AND ch.chapter_id='". $chapter->{chapter_id}."' AND "
		   				."text.textbook_id='".$textbook->{textbook_id}."'";

				my $sth = $dbh->prepare($selectClause.$whereClause);
				$sth->execute;
				$section->{num_probs}=scalar @{$sth->fetchall_arrayref()};

			}
			my $whereClause ="WHERE ch.chapter_id='". $chapter->{chapter_id}."' AND "
	   				."text.textbook_id='".$textbook->{textbook_id}."'";

			my $sth = $dbh->prepare($selectClause.$whereClause);
			$sth->execute;
			$chapter->{num_probs}=scalar @{$sth->fetchall_arrayref()};

			$chapter->{sections}=\@sections;
		
		}
		my $whereClause ="WHERE text.textbook_id='".$textbook->{textbook_id}."'";

		my $sth = $dbh->prepare($selectClause.$whereClause);
		$sth->execute;
		$textbook->{num_probs}=scalar @{$sth->fetchall_arrayref()};

		$textbook->{chapters}=\@chapters;
	}

	print "\n";

	my $webwork_htdocs = $ce->{webwork_dir}."/htdocs";
	my $file = "$webwork_htdocs/DATA/textbook-tree.json";

	# use a variable for the file handle
	my $OUTFILE;

	# use the three arguments version of open
	# and check for errors
	open $OUTFILE, '>', $file  or die "Cannot open $file";

	# you can check for errors (e.g., if after opening the disk gets full)
	print { $OUTFILE } to_json(\@textbooks,{pretty=>1}) or die "Cannot write to $file";

	# check for errors
	close $OUTFILE or die "Cannot close $file";


	print "Wrote Library Textbook Tree to $file\n";

}


1;
