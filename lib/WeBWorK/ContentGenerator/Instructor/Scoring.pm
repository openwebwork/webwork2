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
	open my $fh, ">", $filename;
	foreach my $row (@csv) {
		my $maxLength = $self->maxLength($row) + 1;
		print $fh (join ",", map {$self->pad($_, $maxLength)} @$row);
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
		push @result, [$self->splitQuote($row)];
	}
	return @result;
}

sub writeStandardCSV {
	my ($self, $filename, @csv) = @_;
	open my $fh, ">", $filename;
	foreach my $row (@csv) {
		print (join ",", map {$self->quote} @$row);
		print "\n";
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
		$string =~ m/\G(\s*)/;
		$leadingSpace = $1;
		$string =~ m/\G([^",]*)/;
		$preText = $1;
		if ($string =~ m/\G"((?:[^"]|"")*)"/) {
			$quoted = $1;
		}
		$string =~ m/\G([^,]*?)(\s*)(,?)/;
		($postText, $trailingSpace, $continue) = ($1, $2, $3);
		if (defined $quoted and (not defined $preText and not defined $postText)) {
				$quoted = s/""/"/;
				$result = $quoted;
		} else {
			$preText = "" unless defined $preText;
			$postText = "" unless defined $postText;
			$quoted = "" unless defined $quoted;
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
		$string =~ "\"$string\"";
		return $string;
	}
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
