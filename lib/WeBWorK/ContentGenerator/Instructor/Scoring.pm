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
# column of data:
# (["c1r1", "c1r2", "c1r3"], ["c2r1", "c2r2", "c2r3"])
sub readCSV {
	my ($self, $filename) = @_;
	my @result = ();
	my @columns = split m/\n/, readFile($fileName);
	foreach my $column (@columns) {
		push @result, [split m/\s*,\s*/, $column];
	}
	return @result;
}

sub writeCSV {
	my ($self, $filename, @csv) = @_;
	open my $fh, ">", $filename;
	foreach my $column (@csv) {
		my $maxLength = $self->maxLength($column);
		print (join ",", map {$self->pad($_, $maxLength)} $@column);
		print "\n";
	}
	close $fh;
}

sub readStandardCSV {
	my ($self, $filename) = @_;
	my @result = ();
	my @colunms = split m/\n/, readFile($fileName);
	foreach my $column (@columns) {
		push @result, [$self->splitQuote($column)];
	}
	return @result;
}

sub writeStandardCSV {
	my ($self, $filename, @csv) = @_;
	open my $fh, ">", $filename;
	foreach my $column (@csv) {
		print (join ",", map {$self->quote} $@column);
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
	my $continue = 1
	while ($continue) {
		$string =~ m/\G(\s*)/;
		$leadingSpace = $1;
		$string =~ m/\G([^",]*)/;
		$preText = $1;
		if ($string =~ m/\G"((?:[^"]|"")*)"/) {
			$quoted = $1;
		}
		$string =~ m/\G([^,]*?)(\s*)(,?)/;
		$postText, $trailingSpace, $continue = ($1, $2, $3);
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
