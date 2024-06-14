################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

WeBWorK::File::Classlist - parse and write classlist files.

=cut

use IO::File;
use Text::CSV;

our @EXPORT_OK = qw(parse_classlist write_classlist);

our $MIN_FIELDS = 9;
our $MAX_FIELDS = 12;

our @FIELD_ORDER = qw/student_id last_name first_name status comment
	section recitation email_address user_id password permission unencrypted_password/;

sub parse_classlist ($file) {
	# assume classlist is utf8 encoded
	my $fh = IO::File->new($file, '<:encoding(UTF-8)')
		or die "Failed to open classlist '$file' for reading: $!\n";

	my (@records);

	my $csv = Text::CSV->new({ binary => 1, allow_whitespace => 1 });
	# binary for utf8 compat, allow_whitespace to strip all whitespace from start and end of each field

	while (my $line = <$fh>) {
		chomp $line;
		next if $line     =~ /^#/;
		next unless $line =~ /\S/;

		# Remove a byte order mark from the beginning of the file if present.  Excel inserts this on some systems, and
		# the presence of this multibyte character causes a classlist import to fail.
		$line =~ s/^\x{FEFF}//;

		$line =~ s/^\s*|\s*$//g;

		if (!$csv->parse($line)) {
			warn "Unable to parse line $. of classlist '$file' as CSV.";
			next;
		}
		my @fields = $csv->fields;

		my $fields = @fields;
		if (@fields < $MIN_FIELDS) {
			warn "Skipped invalid line $. of classlist '$file': "
				. "expected at least $MIN_FIELDS fields, got $fields fields.\n";
			next;
		}

		if ($fields > $MAX_FIELDS) {
			my $extra = $fields - $MAX_FIELDS;
			warn "$extra extra fields in line $. of classlist '$file' ignored.\n";
			$fields = $MAX_FIELDS;
		}

		my %record;
		@record{ @FIELD_ORDER[ 0 .. $fields - 1 ] } = @fields[ 0 .. $fields - 1 ];

		push @records, \%record;
	}

	$fh->close;

	return @records;
}

sub write_classlist ($file, @records) {
	my $fh = IO::File->new($file, '>:encoding(UTF-8)')
		or die "Failed to open classist '$file' for writing: $!\n";

	my $csv = Text::CSV->new({ binary => 1 });
	# binary for utf8 compat

	print $fh "# Field order: ", join(",", @FIELD_ORDER), "\n";

	for my $i (0 .. $#records) {
		my $record = $records[$i];
		unless (ref $record eq "HASH") {
			warn "Skipping record $i: not a reference to a hash.\n";
			next;
		}

		my %record = %$record;
		my @fields = @record{@FIELD_ORDER};

		warn "Couldn't form CSV line for user " . $record{user_id}
			unless ($csv->combine(@fields));

		my $string = $csv->string();

		print $fh "$string\n";
	}

	$fh->close;

	return;
}

1;
