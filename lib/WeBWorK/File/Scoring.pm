package WeBWorK::File::Scoring;
use base qw/Exporter/;

=head1 NAME

WeBWorK::File::Scoring - parse scoring files.

=cut

use strict;
use warnings;
use IO::File;

our $MIN_FIELDS = 6;    # there are six "info" fields. we need at least those
#our $MAX_FIELDS; # no maximum in scoring files

our $KEY_INDEX = 0;     # index of field to use for record key in resulting hash

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

		my @fields = split /\s*,\s*/, $_, -1;    # -1 == don't delete empty trailing fields
		my $fields = @fields;
		if ($fields < $MIN_FIELDS) {
			warn
				"Skipped invalid line $. of scoring files '$file': expected at least $MIN_FIELDS fields, got $fields fields.\n";
			next;
		}

		$records{ $fields[$KEY_INDEX] } = \@fields;
	}

	$fh->close;

	return \%records;
}

1;
