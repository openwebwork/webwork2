package WeBWorK::File::Scoring;
use parent qw(Exporter);

=head1 NAME

WeBWorK::File::Scoring - parse scoring files.

=cut

use strict;
use warnings;

use IO::File;

our @EXPORT_OK = qw(parse_scoring_file);

our $MIN_FIELDS = 6;    # There are six "info" fields. we need at least those.
our $KEY_INDEX  = 0;    # Index of field to use for record key in resulting hash.

sub parse_scoring_file {
	my ($file) = @_;

	my $fh = IO::File->new($file, '<')
		or die "Failed to open scoring file '$file' for reading: $!\n";

	my %records;

	while (my $line = <$fh>) {
		chomp $line;
		next if $line     =~ /^#/;
		next unless $line =~ /\S/;
		$line             =~ s/^\s*//;
		$line             =~ s/\s*$//;

		my @fields = split /\s*,\s*/, $line, -1;    # -1 == don't delete empty trailing fields
		my $fields = @fields;
		if ($fields < $MIN_FIELDS) {
			warn "Skipped invalid line $. of scoring files '$file': "
				. "expected at least $MIN_FIELDS fields, got $fields fields.\n";
			next;
		}

		$records{ $fields[$KEY_INDEX] } = \@fields;
	}

	$fh->close;

	return \%records;
}

1;
