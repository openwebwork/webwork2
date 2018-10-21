################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/File/Scoring.pm,v 1.2 2007/08/09 17:22:37 sh002i Exp $
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

package WeBWorK::File::Scoring;
use base qw/Exporter/;

=head1 NAME

WeBWorK::File::Scoring - parse scoring files.

=cut

use strict;
use warnings;
use IO::File;

our $MIN_FIELDS = 6; # there are six "info" fields. we need at least those
#our $MAX_FIELDS; # no maximum in scoring files

our $KEY_INDEX = 0; # index of field to use for record key in resulting hash

our @EXPORT = qw/parse_scoring_file/;

sub parse_scoring_file($) {
	my ($file) = @_;
	
	my $fh = new IO::File($file, "<")
		or die "Failed to open scoring file '$file' for reading: $!\n";
	
	my %records;
	
	while (<$fh>) {
		chomp;
		next if /^#/;
		next unless /\S/;
		s/^\s*//;
		s/\s*$//;
		
		my @fields = split /\s*,\s*/, $_, -1; # -1 == don't delete empty trailing fields
		my $fields = @fields;
		if ($fields < $MIN_FIELDS) {
			warn "Skipped invalid line $. of scoring files '$file': expected at least $MIN_FIELDS fields, got $fields fields.\n";
			next;
		}
		
		$records{$fields[$KEY_INDEX]} = \@fields;
	}
	
	$fh->close;
	
	return \%records;
}

1;
