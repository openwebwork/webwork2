################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Instructor::Scoring;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME
 
WeBWorK::ContentGenerator::Instructor::Scoring - Generate scoring data files

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(readFile formatDateTime);
use WeBWorK::DB::Utils qw(initializeUserProblem);
use WeBWorK::Timing;

sub initialize {
	my ($self) = @_;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
	my $scoringDir = $ce->{courseDirs}->{scoring};
	my $courseName = $ce->{courseName};
	my $user = $r->param('user');

	unless ($authz->hasPermissions($user, "score_sets")) {
		$self->{submitError} = "You aren't authorized to score problem sets";
		return;
	}

	if (defined $r->param('scoreSelected')) {
		my @selected = $r->param('selectedSet');
		my @totals = ();
		foreach my $setID (@selected) {
			my @everything = $self->scoreSet($setID, "everything");
			my @normal = $self->everything2normal(@everything);
			my @full = $self->everything2full(@everything);
			my @info = $self->everything2info(@everything);
			my @totalsColumn = $self->everything2totals(@everything);
			@totals = @info unless @totals;
			$self->appendColumns(\@totals, \@totalsColumn);
			$self->writeCSV("$scoringDir/s${setID}scr.csv", @normal);
			$self->writeCSV("$scoringDir/s${setID}ful.csv", @full);
		}
		$self->writeCSV("$scoringDir/${courseName}_totals.csv", @totals);
	}
}

sub title {
	"Scoring data for ".(shift)->{ce}->{courseName};
}

sub body {
	my ($self) = @_;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
	my $scoringDir = $ce->{courseDirs}->{scoring};
	my $courseName = $ce->{courseName};
	my $user = $r->param('user');
	
	if ($authz->hasPermissions($user, "score_sets")) {
		my @selected = $r->param('selectedSet');
		print CGI::p("All of these files will also be made available for mail merge");
		foreach my $setID (@selected) {
			print CGI::h2("$setID");
			foreach my $type ("scr", "ful") {
				my $filename = "s$setID$type.csv";
				my $path = "$scoringDir/$filename";
				if (-f $path) {
					print CGI::a({href=>"../scoringDownload/?getFile=${filename}&".$self->url_authen_args}, $filename);
					print CGI::br();
				}
			}
			print CGI::hr();
		}
		print CGI::h2("Totals");
		print CGI::a({href=>"../scoringDownload/?getFile=${courseName}_totals.csv&".$self->url_authen_args}, "${courseName}_totals.csv");
	}
	
	return "";
}

# If, some day, it becomes possible to assign a different number of problems to each student, this code
# will have to be rewritten some.
# $format can be any of "normal", "full", "everything", "info", or "totals".  An undefined value defaults to "normal"
#   normal: student info, the status of each problem in the set, and a "totals" column
#   full: student info, the status of each problem, and the number of correct and incorrect attempts
#   everything: "full" plus a totals column
#   info: student info columns only
#   totals: total column only
sub scoreSet {
	my ($self, $setID, $format) = @_;
	my $db = $self->{db};
	my @scoringData;
	
	$format = "normal" unless defined $format;
	$format = "normal" unless $format eq "full" or $format eq "everything" or $format eq "totals" or $format eq "info";
	my $columnsPerProblem = ($format eq "full" or $format eq "everything") ? 3 : 1;
	my $setRecord = $db->getGlobalSet($setID);
	my %users;
	foreach my $userID ($db->listUsers()) {
		my $userRecord = $db->getUser($userID);
		# The key is what we'd like to sort by.
		$users{$userRecord->student_id} = $userRecord;
	}
	my @problemIDs = $db->listGlobalProblems($setID);

	# Initialize a two-dimensional array of the proper size
	for (my $i = 0; $i < keys(%users) + 7; $i++) { # 7 is how many descriptive fields there are in each column
		push @scoringData, [];
	}
	
	unless ($format eq "totals") {
		$scoringData[0][0] = "NO OF FIELDS";
		$scoringData[1][0] = "SET NAME";
		$scoringData[2][0] = "PROB NUMBER";
		$scoringData[3][0] = "DUE DATE";
		$scoringData[4][0] = "DUE TIME";
		$scoringData[5][0] = "PROB VALUE";
	}
	
	my @userInfoColumnHeadings = ("STUDENT ID", "LAST NAME", "FIRST NAME", "SECTION", "RECITATION");
	my @userInfoFields = ("student_id", "last_name", "first_name", "section", "recitation");
	my @userKeys = sort keys %users;
	
	# Write identifying information about the users
	unless ($format eq "totals") {
		for (my $field=0; $field < @userInfoFields; $field++) {
			if ($field > 0) {
				for (my $i = 0; $i < 6; $i++) {
					$scoringData[$i][$field] = "";
				}
			}
			$scoringData[6][$field] = $userInfoColumnHeadings[$field];
			for (my $user = 0; $user < @userKeys; $user++) {
				my $fieldName = $userInfoFields[$field];
				$scoringData[7 + $user][$field] = $users{$userKeys[$user]}->$fieldName;
			}
		}
	}
	return @scoringData if $format eq "info";
	
	# Write the problem data
	my $dueDateString = formatDateTime($setRecord->due_date);
	my ($dueDate, $dueTime) = $dueDateString =~ m/^([^\s]*)\s*([^\s]*)$/;
	my $valueTotal = 0;
	my %userStatusTotals = ();
	for (my $problem = 0; $problem < @problemIDs; $problem++) {
		my $globalProblem = $db->getGlobalProblem($setID, $problemIDs[$problem]);
		my $column = 5 + $problem * $columnsPerProblem;
		unless ($format eq "totals") {
			$scoringData[0][$column] = "";
			$scoringData[1][$column] = $setRecord->set_id;
			$scoringData[2][$column] = $globalProblem->problem_id;
			$scoringData[3][$column] = $dueDate;
			$scoringData[4][$column] = $dueTime;
			$scoringData[5][$column] = $globalProblem->value;
			$scoringData[6][$column] = "STATUS";
			if ($format eq "full" or $format eq "everything") { # Fill in with blanks, or maybe the problem number
				for (my $row = 0; $row < 6; $row++) {
					for (my $col = $column+1; $col <= $column + 2; $col++) {
						if ($row == 2) {
							$scoringData[$row][$col] = $globalProblem->problem_id;
						} else {
							$scoringData[$row][$col] = "";
						}
					}
				}
				$scoringData[6][$column + 1] = "#corr";
				$scoringData[6][$column + 2] = "#incorr";
			}
		}
		$valueTotal += $globalProblem->value;
		for (my $user = 0; $user < @userKeys; $user++) {
			my $userProblem = $db->getMergedProblem($users{$userKeys[$user]}->user_id, $setID, $problemIDs[$problem]);
			unless (defined $userProblem) { # assume an empty problem record if the problem isn't assigned to this user
				$userProblem = $db->newUserProblem;
				$userProblem->status(0);
				$userProblem->value(0);
				$userProblem->num_correct(0);
				$userProblem->num_incorrect(0);
			}
			$userStatusTotals{$user} = 0 unless exists $userStatusTotals{$user};
			$userStatusTotals{$user} += $userProblem->status * $userProblem->value;
			unless ($format eq "totals") {
				$scoringData[7 + $user][$column] = $userProblem->status;
				if ($format eq "full" or $format eq "everything") {
					$scoringData[7 + $user][$column + 1] = $userProblem->num_correct;
					$scoringData[7 + $user][$column + 2] = $userProblem->num_incorrect;
				}
			}
		}
	}
	
	# write the status totals
	unless ($format eq "full") { # Ironic, isn't it?
		my $totalsColumn = $format eq "totals" ? 0 : 5 + @problemIDs * $columnsPerProblem;
		$scoringData[0][$totalsColumn] = "";
		$scoringData[1][$totalsColumn] = $setRecord->set_id;
		$scoringData[2][$totalsColumn] = "";
		$scoringData[3][$totalsColumn] = "";
		$scoringData[4][$totalsColumn] = "";
		$scoringData[5][$totalsColumn] = $valueTotal;
		$scoringData[6][$totalsColumn] = "total";
		for (my $user = 0; $user < @userKeys; $user++) {
			$scoringData[7+$user][$totalsColumn] = $userStatusTotals{$user};
		}
	}
	
	return @scoringData;
}

# Often it's more efficient to just get everything out of the database
# and then pick out what you want later.  Hence, these "everything2*" functions
sub everything2info {
	my ($self, @everything) = @_;
	my @result = ();
	foreach my $row (@everything) {
		push @result, [@{$row}[0..4]];
	}
	return @result;
}

sub everything2normal {
	my ($self, @everything) = @_;
	my @result = ();
	foreach my $row (@everything) {
		my @row = @$row;
		my @newRow = ();
		push @newRow, @row[0..4];
		for (my $i = 5; $i < @row; $i+=3) {
			push @newRow, $row[$i];
		}
		#push @newRow, $row[$#row];
		push @result, [@newRow];
	}
	return @result;
}

sub everything2full {
	my ($self, @everything) = @_;
	my @result = ();
	foreach my $row (@everything) {
		push @result, [@{$row}[0..($#{$row}-1)]];
	}
	return @result;
}

sub everything2totals {
	my ($self, @everything) = @_;
	my @result = ();
	foreach my $row (@everything) {
		push @result, [${$row}[$#{$row}]];
	}
	return @result;
}

sub appendColumns {
	my ($self, $a1, $a2) = @_;
	my @a1 = @$a1;
	my @a2 = @$a2;
	for (my $i = 0; $i < @a1; $i++) {
		push @{$a1[$i]}, @{$a2[$i]};
	}
}

# Reads a CSV file and returns an array of arrayrefs, each containing a
# row of data:
# (["c1r1", "c1r2", "c1r3"], ["c2r1", "c2r2", "c2r3"])
sub readCSV {
	my ($self, $fileName) = @_;
	my @result = ();
	my @rows = split m/\n/, readFile($fileName);
	foreach my $row (@rows) {
		push @result, [split m/\s*,\s*/, $row];
	}
	return @result;
}

# Write a CSV file from an array in the same format that readCSV produces
sub writeCSV {
	my ($self, $filename, @csv) = @_;
	
	my @lengths = ();
	for (my $row = 0; $row < @csv; $row++) {
		for (my $column = 0; $column < @{$csv[$row]}; $column++) {
			$lengths[$column] = 0 unless defined $lengths[$column];
			$lengths[$column] = length $csv[$row][$column] if length $csv[$row][$column] > $lengths[$column];
		}
	}
	
	open my $fh, ">", $filename;
	foreach my $row (@csv) {
		my @rowPadded = ();
		foreach (my $column = 0; $column < @$row; $column++) {
			push @rowPadded, $self->pad($row->[$column], $lengths[$column] + 1);
		}
		print $fh join(",", @rowPadded);
		print $fh "\n";
	}
	close $fh;
}

# As soon as backwards compatability is no longer a concern and we don't expect to have
# to use old ww1.x code to read the output anymore, I recommend switching to using
# these routines, which are more versatile and compatable with other programs which
# deal with CSV files.
sub readStandardCSV {
	my ($self, $fileName) = @_;
	my @result = ();
	my @rows = split m/\n/, readFile($fileName);
	foreach my $row (@rows) {
		push @result, [$self->splitQuoted($row)];
	}
	return @result;
}

sub writeStandardCSV {
	my ($self, $filename, @csv) = @_;
	open my $fh, ">", $filename;
	foreach my $row (@csv) {
		print $fh (join ",", map {$self->quote($_)} @$row);
		print $fh "\n";
	}
	close $fh;
}

###

# This particular unquote method unquotes (optionally) quoted strings in the
# traditional CSV style (double-quote for literal quote, etc.)
sub unquote {
	my ($self, $string) = @_;
	if ($string =~ m/^"(.*)"$/) {
		$string = $1;
		$string =~ s/""/"/;
	}
	return $string;
}

# Should you wish to treat whitespace differently, this routine has been designed
# to make it easy to do so.
sub splitQuoted {
	my ($self, $string) = @_;
	my ($leadingSpace, $preText, $quoted, $postText, $trailingSpace, $result);
	my @result = ();
	my $continue = 1;
	while ($continue) {
		$string =~ m/\G(\s*)/gc;
		$leadingSpace = $1;
		$string =~ m/\G([^",]*)/gc;
		$preText = $1;
		if ($string =~ m/\G"((?:[^"]|"")*)"/gc) {
			$quoted = $1;
		}
		$string =~ m/\G([^,]*?)(\s*)(,?)/gc;
		($postText, $trailingSpace, $continue) = ($1, $2, $3);

		$preText = "" unless defined $preText;
		$postText = "" unless defined $postText;
		$quoted = "" unless defined $quoted;

		if ($quoted and (not $preText and not $postText)) {
				$quoted =~ s/""/"/;
				$result = $quoted;
		} else {
			$result = "$preText$quoted$postText";
		}
		push @result, $result;
	}
	return @result;
}

# This particular quoting method does CSV-style (double a quote to escape it) quoting when necessary.
sub quote {
	my ($self, $string) = @_;
	if ($string =~ m/[", ]/) {
		$string =~ s/"/""/;
		$string = "\"$string\"";
	}
	return $string;
}

sub pad {
	my ($self, $string, $padTo) = @_;
	my $spaces = $padTo - length $string;
	return $string . " "x$spaces;
}

sub maxLength {
	my ($self, $arrayRef) = @_;
	my $max = 0;
	foreach my $cell (@$arrayRef) {
		$max = length $cell unless length $cell < $max;
	}
	return $max;
}

1;
