################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/NPL.pm,v 1.1 2007/10/17 16:56:16 sh002i Exp $
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
# 
# Contributed by W.H. Freeman; Bedford, Freeman, and Worth Publishing Group.
################################################################################

package WeBWorK::NPL;
use base 'Exporter';

=head1 NAME

WeBWorK::NPL - Parse formats used by the National Problem Library.

=head1 SYNOPSIS

	use WeBWorK::NPL qw/read_textbooks read_tags format_tags gen_find_tags/;
	
	open TEXTS, "<", "Textbooks";
	my $textbooks = [];
	read_textbooks(\*TEXTS, $textbooks);
	
	open PGFILE, "<", "file.pg";
	my $tags = {};
	read_tags(\*PGFILE, $tags);
	
	foreach my $string (format_tags($tags)) {
		$string =~ s/^/## /gm;
		print "TAG: $string\n";
	}
	
	use File::Find;
	my $process = sub { print "Found: $_[0]\n" };
	my $wanted = gen_find_tags({author=>'Rogawski'}, $process);
	find({wanted=>$wanted}, @ARGV);

=head1 DESCRIPTION

This package contains parsing routines for the various data formats associated
with the National Problem Library.

=cut

use strict;
use warnings;
use Data::Dumper;

our @EXPORT_OK = qw(
	read_textbooks
	read_tags
	format_tags
	gen_find_tags
);

our @global_fields = qw(DESCRIPTION KEYWORDS DBsubject DBchapter DBsection Date
Institution Author UsesAuxiliaryFiles);
our @textbook_fields = qw(title edition author chapter section problem);

our %tag2field = ( TitleText => "title", EditionText => "edition",
AuthorText => "author", Section => "section", Problem => "problem", );
our %field2tag = reverse %tag2field;

=head1 FUNCTIONS

=head2 read_textbooks

	read_textbooks($fh, $arrayref)

Reads a Textbooks file opened for reading on $fh and appends its contents to
$arrayref. Each item appended to $arrayref is a reference to a hash containing
the following keys:

	_title      The title of the textbook
	_edition    The edition of the textbook
	_author     The author of the textbook
	1           The name of chapter 1
	1.1         The name of section 1.1
	1.2         The name of section 1.2
	...
	2           The name of chapter 2
	2.1         The name of section 2.1
	...

Since the number of sections in a textbook is typically small, it is not terribly
inefficient to pull chapters or sections out:

	@chapters = grep { /^\d+$/ } keys %textbook;
	@sections = grep { /^\d+\.\d+$/ } keys %textbook;

=cut

sub read_textbooks {
	my ($fh, $result) = @_;
	
	my %curr_textbook;
	
	while (<$fh>) {
		s/#.*$//g;
		next unless /\S/;
		s/^\s*//;
		s/\s*$//;
		
		if (/^(TitleText|EditionText|AuthorText)\(\s*'(.*?)'\s*\)/) {
			my $field = $tag2field{$1};
			my $value = $2;
			if (exists $curr_textbook{"_$field"}) {
				# repeated tag -- this is a new textbook
				push @$result, {%curr_textbook};
				%curr_textbook = ();
			}
			$curr_textbook{"_$field"} = $value;
		} elsif (/^(\d+)(?:\.(\d+))?\s*>>>\s*(.*)$/) {
			my $chapter = $1;
			my $section = $2;
			my $name = $3;
			if (defined $section and length $section > 0) {
				$curr_textbook{"$chapter.$section"} = $name;
			} else {
				$curr_textbook{$chapter} = $name;
			}
		}
	}
	push @$result, {%curr_textbook};
}

=head2 read_tags

	read_tags($fh, $hashref, $extra_editing_info);

Reads the NPL tags from a PG file opened for reading on $fh and stores the tags
in %$hashref. The following keys may be added to %$hashref:

	DESCRIPTION
	KEYWORDS
	DBsubject
	DBchapter
	DBsection
	Date
	Institution
	Author
	UsesAuxiliaryFiles      (experimental, subject to change)
	textbooks               (arrayref)

The value for the C<textbooks> key will be a reference to an array of textbook
hashes containing the textbook tags from the source file. In each textbook hash,
entries with empty values (e.g. C<TitleText1('')>) will be omitted. This is to
deal with the large number of empty-valued tags in the NPL. The keys of each
textbook hash will be among:

	title
	edition
	author
	chapter
	section
	problem        (arrayref)

The value for the C<problem> key will be a reference to an array of problem
numbers.

If $extra_editing_info is true, special hash items _pos, _rest, and _maxtextbook
will also be added to %$hashref.

_pos will contain the position of the first byte of the next line after the last
tag in the file. _rest will contain the bytes of the "rest" of the file, after
all tags, starting at _pos. _maxtextbook will contain the highest number used to
identify a textbook in the file. (e.g. If TitleText1 and TitleText3 appear in
the  file, there will only be two items in the textbooks array, but _maxtextbook
will be 3.)

This is useful for appending tags to a file which contains existing tags, where
the new tags should appear immediately after the existing tags:

	open PGFILE, "+<", "file.pg";
	my $tags = {};
	read_tags(\*PGFILE, $tags, 1);
	my $pos = $tags{_pos};
	my $rest = $tags{_rest};
	seek PGFILE, $pos, 0;
	print PGFILE "## SomeNewTag('foo','bar')\n";
	print PGFILE $rest;
	close PGFILE;

=cut

sub read_tags {
	my ($file, $result, $extra_editing_info) = @_;
	
	my $fh;
	if (ref $file) {
		$fh = $file;
	} elsif (defined $file and not ref $file) {
		$fh = new IO::File($file, 'r');
	}
	
	my $pos;
	my $rest = '';
	my $maxtextbook;
	while (<$fh>) {
		#if (0) {
		if (/^(.*?\#.*?)(\s*)DESCRIPTION/) {
			my $prefix = $1;
			my $whitespace = $2;
			my $description = '';
			while (<$fh>) {
				if (/\#.*ENDDESCRIPTION/) {
					chomp $description;
					$result->{DESCRIPTION} = $description if length $description > 0;
					last;
				} else {
					# handle prefix and whitespace separately so that we can still
					# chop the prefix off even if people are being careless about
					# whitespace. :P
					s/^$prefix//;
					s/^$whitespace//;
					$description .= $_;
				}
			}
			if ($extra_editing_info) {
				$pos = tell $fh;
				$rest = '';
			}
		} elsif (/\#.*KEYWORDS\((.*)\)/) {
			my $keywords = $1;
			push @{$result->{KEYWORDS}}, parse_keywords($keywords);
			if ($extra_editing_info) {
				$pos = tell $fh;
				$rest = '';
			}
		} elsif (/\#.*(DBsubject|DBchapter|DBsection|Date|Institution|Author)\(\s*(.*?)\s*\)/) {
			my $field = $1;
			my $value = $2;
			my ($parsed_value, $parse_errors) = parse_normal_value($field, $value);
			if (@$parse_errors) {
				warn "error while parsing value \"$value\" in field $field:\n"
					. join('', @$parse_errors)
					. "value may be incomplete. use with caution.\n"
					. "(line $. of file $file)\n";
			}
			$result->{$field} = $parsed_value;
			if ($extra_editing_info) {
				$pos = tell $fh;
				$rest = '';
			}
		} elsif (/\#.*(TitleText|EditionText|AuthorText|Section|Problem)(\d+)\(\s*'(.*?)'\s*\)/) {
			my $field = $tag2field{$1};
			my $num = $2;
			my $value = $3;
			next unless $value =~ /\S/;
			$value = [ parse_problems($value) ] if $field eq "problem";
			if ($field eq "section") {
				my ($ch, $sec) = split /\./, $value;
				$result->{textbooks}[$num]{chapter} = $ch;
				$result->{textbooks}[$num]{section} = $sec if defined $sec and length $sec > 0;
			} else {
				$result->{textbooks}[$num]{$field} = $value;
			}
			if ($extra_editing_info) {
				$pos = tell $fh;
				$rest = '';
				$maxtextbook = $num if not defined $maxtextbook or $num > $maxtextbook;
			}
		} elsif (/\#.*(UsesAuxiliaryFiles)\(\s*(.*?)\s*\)/) {
			my $field = $1;
			my $value = $2;
			my ($parsed_value, $parse_errors) = parse_normal_list($field, $value);
			if (@$parse_errors) {
				warn "error while parsing list value \"$value\" in field $field:\n"
					. join('', @$parse_errors)
					. "value may be incomplete. use with caution.\n"
					. "(line $. of file $file)\n";
			}
			$result->{$field} = $parsed_value;
			if ($extra_editing_info) {
				$pos = tell $fh;
				$rest = '';
			}
		} else {
			if ($extra_editing_info) {
				$rest .= $_;
			}
		}
	}
	
	# remove holes in textbook numbering
	@{$result->{textbooks}} = grep { defined } @{$result->{textbooks}};
	delete $result->{textbooks} unless @{$result->{textbooks}};
	
	if ($extra_editing_info) {
		$result->{_pos} = $pos;
		$result->{_rest} = $rest;
		$result->{_maxtextbook} = $maxtextbook;
	}
}

sub parse_normal_list {
	my ($name, $string) = @_;
	
	use constant NRM=>0;
	use constant STR=>1;
	use constant ESC=>2;
	use constant STP=>3;
	my $state = NRM;
	my @errors;
	my @items;
	my $curr_item = '';
	my $next_item = 0;
	foreach my $i (0 .. length($string)-1) {
		my $c = substr($string,$i,1);
		#print "i=$i c=$c state=$state curr_item=$curr_item next_item=$next_item\n";
		# state changes
		if ($state == NRM) {
			if ($c eq "'") {
				$state = STR;
			} elsif ($c eq ',' or $c eq ' ') {
				# do nothing -- closequote already consumed curr_item
			} else {
				push @errors, 
					"illegal char '$c' in state NRM while parsing value for $name.\n"
					. "    $string\n"
					. '    ' . ' 'x$i . "^\n";
				$next_item = 1;
				$state = STP;
			}
		} elsif ($state == STR) {
			if ($c eq "'") {
				$state = NRM;
				$next_item = 1;
			} elsif ($c eq '\\') {
				$state = ESC;
			} else {
				$curr_item .= $c;
			}
		} elsif ($state == ESC) {
			$curr_item .= $c;
			$state = STR;
		} elsif ($state == STP) {
			last;
		} else {
			die "unexpected state $state while parsing value for $name.\n";
		}
		#print "i=$i c=$c state=$state curr_item=$curr_item next_item=$next_item\n";
		# actions
		if ($next_item) {
			push @items, $curr_item;
			$curr_item = '';
			$next_item = 0;
			#print "stored item to list\n";
		}
	}
	
	return \@items, \@errors;
}

sub parse_normal_value {
	my ($name, $string) = @_;
	my ($items, $errors) = parse_normal_list($name, $string);
	push @$errors, "only one item allowed in value for $name.\n" if @$items > 1;
	return shift @$items, $errors;
}

# this now works for keywords is embedded spaces (which are later stripped out
# by kwtidy) but now it doesn't work for values with double quotes or no quotes!
sub parse_keywords {
	my $string = shift;
	my ($items, $errors) = parse_normal_list('KEYWORDS', $string);
	if (@$errors) {
		warn "errors while parsing KEYWORDS list:\n@$errors\n"
			. "Partially-parsed KEYWORDS: @$items\n"
			. "Resorting to old-style KEYWORDS parsing...\n";
		@$items = split /(?:,|\s)+/, $string;
		warn "Old-style parse result: ", join('|', @$items), "\n";
	}
	return map { kwtidy($_) } @$items;
}

sub kwtidy {
	my $keyword = shift;
	$keyword =~ s/\W//g;
	$keyword =~ s/_//g;
	return lc $keyword;
}

sub parse_problems {
	my $string = shift;
	$string =~ s/\D/ /g;
	return grep { /\S/ } split /\s+/, $string;
}

=head2 format_tags

	format_tags($tags, $mintextbook);

Given a reference to a hash of tags, return a list of strings representing said
tags. The strings do not begin with the standard NPL comment prefix ("## ") or
end with newlines. These must be added by the caller if the strings are to be
inserted into a PG source file.

One complication is the DESCRIPTION field, which contains embedded newlines. If
a DESCRIPTION tag occurs in %$tags, it will be formatted with embedded newlines
but without a trailing newline. For example, after this code executes,

	$tags = { DESCRIPTION => "line one\nline two\nline three" };
	($desc) = format_tags($tags);

$desc will contain the string:

	"DESCRIPTION\nline one\nline two\nline three\nENDDESCRIPTION"

To account for this when writing to a PG file, you could use:

	foreach my $string (format_tags($tags)) {
		$string =~ s/^/## /gm;
		print PGFILE "$string\n";
	}

=cut

sub format_tags {
	my ($tags, $mintextbook) = @_;
	$mintextbook ||= 1;
	my @result;
	my @ordered_fields = grep { exists $tags->{$_} } @global_fields, "textbooks";
	foreach my $field (@ordered_fields) {
		my $value = $tags->{$field};
		if ($field eq "DESCRIPTION") {
			push @result, format_description($value);
		} elsif ($field eq "textbooks") {
			push @result, format_textbooks($value, $mintextbook);
		} else {
			push @result, format_tag($field, $value);
		}
	}
	return @result;
}

sub format_tag {
	my ($field, $value, $n) = @_;
	my $tag = $field2tag{$field} || $field;
	
	# problems are always listed in a single string in the tag.
	if ($field eq "problem") {
		$value = format_problems($value);
	}
	
	# if we have an arrayref, we represent it as multiple strings in one tag.
	if (ref $value) {
		$value = join(',', map { "'$_'" } @$value);
	} elsif (defined $value) {
		$value = "'$value'";
	} else {
		warn "value is not defined for field $field!\n";
		$value = "''";
	}
	
	if (defined $n) {
		return "$tag$n($value)";
	} else {
		return "$tag($value)";
	}
}

sub format_description {
	my $value = shift;
	return "DESCRIPTION\n$value\nENDDESCRIPTION";
}

sub format_textbooks {
	my ($textbook, $n) = @_;
	my @textbooks = @$textbook;
	my @result;
	foreach my $textbook (@textbooks) {
		push @result, format_textbook($textbook, $n);
		$n++;
	}
	return @result;
}

sub format_textbook {
	my ($textbook, $n) = @_;
	
	# combine chapter/section into single section tag
	my $chapter = $textbook->{chapter};
	my $section = $textbook->{section};
	if (defined $chapter or defined $section) {
		$section = ".$section" if defined $section;
		$section = "$chapter$section" if defined $chapter;
		delete $textbook->{chapter};
		$textbook->{section} = $section;
	}
	
	my @result;
	my @ordered_fields = grep { exists $textbook->{$_} } @textbook_fields;
	foreach my $field (@ordered_fields) {
		my $value = $textbook->{$field};
		push @result, format_tag($field, $value, $n);
	}
	return @result;
}

sub format_problems {
	my $first = shift;
	my @problems;
	if (ref $first) {
		@problems = @$first;
	} else {
		@problems = ($first, @_);
	}
	
	return join(',', @problems);
}

=head2 gen_find_tags

	gen_find_tags($pattern, $action, $extra_editing_info);

Generates an anonymous subroutine suitable for passing the the find() function
of the File::Find module. The no_chdir=>1 option must be passed to find() for
the generated subroutine to operate properly.

$pattern is a reference to a hash describing the fields that must match. $action
is a reference to a subroutine that will be called if all fields match. 
$extra_editing_info is passed to read_tags().

Legal fields for $pattern are as follows:

B<Global fields:> DESCRIPTION, KEYWORDS, DBsubject, DBchapter, DBsection, Date,
Institution, Author. (The experimental UsesAuxiliaryFiles field may be supported
in the future.)

B<Text-specific fields:> title, edition, author, chapter, section, problem.

If multiple text-specific keys are given, then all must match for a single
textbook.

$action is called as follows:

	$action->($path, $tags, $text_index)

There $path the path to the matching file, $tags a reference to the tag hash for
the matching file, and $text_index the index into the @{$tags->{textbooks}} array
if $pattern included textbook-specific tags.

=cut

sub gen_find_tags {
	my ($pattern, $action, $extra_editing_info) = @_;
	return sub {
		return unless /\.pg$/ and -f $File::Find::name;
		
		my $name = $File::Find::name;
		#my $relpath = $name;
		#$relpath =~ s/^$src\///;
		
		my %tags;
		
		open my $fh, "<", $name or do {
			warn "skipping $name: $!\n";
			return;
		};
		read_tags($fh, \%tags, $extra_editing_info);
		close $fh;
		
		my (%global_pattern, %textbook_pattern);
		foreach my $field (@global_fields) {
			$global_pattern{$field} = $pattern->{$field} if exists $pattern->{$field};
		}
		foreach my $field (@textbook_fields) {
			$textbook_pattern{$field} = $pattern->{$field} if exists $pattern->{$field};
		}
		
		if (%global_pattern) {
			return unless match_global(\%tags, \%global_pattern);
		}
		my $text_index;
		if (%textbook_pattern) {
			$text_index = match_textbook(\%tags, \%textbook_pattern);
			return unless $text_index >= 0;
		}
		
		$action->($name, \%tags, $text_index);
	};
}

sub match_global {
	my ($tags, $matches) = @_;
	foreach my $field (keys %$matches) {
		return 0 unless $tags->{$field} eq $matches->{$field};
	}
	return 1;
}

sub match_textbook {
	my ($tags, $matches) = @_;
	return -1 unless defined $tags->{textbooks};
	my @textbooks = @{$tags->{textbooks}};
	
	#textbook: foreach my $textbook (@{$tags->{textbooks}}) {
	textbook: foreach my $i (0 .. $#{$tags->{textbooks}}) {
		my $textbook = $tags->{textbooks}[$i];
		foreach my $field (keys %$matches) {
			next if $field !~ /^(title|edition|author|chapter|section|problem)$/;
			next textbook unless $textbook->{$field} eq $matches->{$field};
		}
		#warn "matched text i=$i: ", Dumper($textbook);
		return $i;
	}
	return -1;
}

1;
