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
use WeBWorK::Utils qw(readFile);

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
			$lengths[$column] = length $csv[$row]->[$column] if length $csv[$row]->[$column] > $lengths[$column];
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
