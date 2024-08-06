#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';

use Mojo::File qw(curfile path);

BEGIN {
	use Env qw(WEBWORK_ROOT);
	$WEBWORK_ROOT = curfile->dirname->dirname;
}

use lib "$ENV{WEBWORK_ROOT}/lib";

use WeBWorK::Utils qw(cryptPassword);
use WeBWorK::File::Classlist qw(parse_classlist write_classlist);

unless (@ARGV == 1) {
	say 'Usage: crypt_passwords_in_classlist.pl filename';
	exit 0;
}

my $infile  = shift;
my $outfile = "crypted_$infile";

if (-e $outfile) {
	print qq{The file "$outfile" exists. Do you want to proceed and overwrite "$outfile"? (Y/n) };
	my $input = <>;
	chomp $input;
	unless ($input eq 'Y') {
		say 'Aborting.';
		exit 0;
	}
}

if (-e $infile && -r $infile) {
	my @classlist = parse_classlist($infile);
	for (@classlist) {
		$_->{password} = cryptPassword($_->{password} || $_->{user_id});
	}
	write_classlist($outfile, @classlist);
	say qq{Output written to the file "$outfile".};
} else {
	say qq{The file "$infile" is does not exist or is not readable.};
}
