################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authz.pm,v 1.17 2004/09/02 22:52:02 sh002i Exp $
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

WeBWorK::Authz - parse and write classlist files.

=cut

use strict;
use warnings;
use IO::File;

use constant FIELD_ORDER => qw/student_id last_name first_name status comment section recitation email_address user_id/;
our $nfields = FIELD_ORDER;

our @EXPORT = qw/parse_classlist write_classlist/;

sub parse_classlist($) {
	my ($file) = @_;
	
	my $fh = new IO::File($file, "<")
		or die "Failed to open classlist '$file' for reading: $!\n";
	
	my (@records);
	
	while (<$fh>) {
		chomp;
		s/#.*$//;
		next unless /\S/;
		s/^\s*//;
		s/\s*$//;
		
		my @fields = split /\s*,\s*/;
		my $fields = @fields;
		unless ($fields == $nfields) {
			warn "Skipped invalid line $. of classlist '$file': expected $nfields fields, got $fields fields.\n";
			next;
		}
		
		my %record;
		@record{FIELD_ORDER()} = @fields;
		
		push @records, \%record;
	}
	
	$fh->close;
	
	return @records;
}

sub write_classlist($@) {
	my ($file, @records) = @_;
	
	my $fh = new IO::File($file, ">")
		or die "Failed to open classist '$file' for writing: $!\n";
	
	foreach my $i (0 .. $#records) {
		my $record = $records[$i];
		unless (ref $record eq "HASH") {
			warn "Skipping record $i: not a reference to a hash.\n";
			next;
		}
		
		my %record = %$record;
		my @fields = @record{FIELD_ORDER()};
		my $fields = @fields;
		
		my $string = join ",", @fields;
		
		print $fh "$string\n";
	}
	
	$fh->close;
}
