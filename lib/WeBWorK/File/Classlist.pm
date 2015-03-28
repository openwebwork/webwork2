################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/File/Classlist.pm,v 1.10 2007/08/13 22:59:58 sh002i Exp $
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
################################################################################

package WeBWorK::File::Classlist;
use base qw/Exporter/;

=head1 NAME

WeBWorK::File::Classlist - parse and write classlist files.

=cut

use strict;
use warnings;
use IO::File;
use Text::CSV;

our $MIN_FIELDS = 9;
our $MAX_FIELDS = 11;

our @FIELD_ORDER = qw/student_id last_name first_name status comment
section recitation email_address user_id password permission/;

our @EXPORT = qw/parse_classlist write_classlist/;

sub parse_classlist($) {
	my ($file) = @_;
	
	use open qw( :encoding(UTF-8) :std ); # assume classlist is utf8 encoded
	my $fh = new IO::File($file, "<")
		or die "Failed to open classlist '$file' for reading: $!\n";
	
	my (@records);

  my $csv = Text::CSV->new({ binary => 1, allow_whitespace => 1 });
	   # binary for utf8 compat, allow_whitespace to strip all whitespace from start and end of each field

	
	while (<$fh>) {
		chomp;
		next if /^#/;
		next unless /\S/;
		s/^\s*//;
		s/\s*$//;
		
		if (!$csv->parse($_)) {
			warn "Unable to parse line $. of classlist '$file' as CSV.";
			next;
		}
		my @fields = $csv->fields;

		my $fields = @fields;
		if ($fields < $MIN_FIELDS) {
			warn "Skipped invalid line $. of classlist '$file': expected at least $MIN_FIELDS fields, got $fields fields.\n";
			next;
		}
		
		if ($fields > $MAX_FIELDS) {
			my $extra = $fields - $MAX_FIELDS;
			warn "$extra extra fields in line $. of classlist '$file' ignored.\n";
			$fields = $MAX_FIELDS;
		}
		
		my @fields_in_this_record = @FIELD_ORDER[0 .. $fields-1];
		my @data_in_this_record = @fields[0 .. $fields-1];
		
		my %record;
		@record{@fields_in_this_record} = @data_in_this_record;
		
		push @records, \%record;
	}
	
	$fh->close;
	
	return @records;
}

sub write_classlist($@) {
	my ($file, @records) = @_;
	
	my $fh = new IO::File($file, ">")
		or die "Failed to open classist '$file' for writing: $!\n";
	
	my $csv = Text::CSV->new({ binary => 1});
	# binary for utf8 compat
	
	print $fh "# Field order: ", join(",", @FIELD_ORDER), "\n";
	
	foreach my $i (0 .. $#records) {
		my $record = $records[$i];
		unless (ref $record eq "HASH") {
			warn "Skipping record $i: not a reference to a hash.\n";
			next;
		}
		
		my %record = %$record;
		my @fields = @record{@FIELD_ORDER};
		
		warn "Couldn't form CSV line for user ".$record{user_id}
		    unless ($csv->combine(@fields));
		
		my $string = $csv->string();
		
		print $fh "$string\n";
	}
	
	$fh->close;
}

1;
