#!/usr/bin/perl

use open IO => ':encoding(UTF-8)';

# ==================================================================

# 2 subroutines copied from lib/WeBWorK/Utils.pm from WW 2.16 version

sub cryptPassword($) {
	my ($clearPassword) = @_;
	#Use an SHA512 salt with 16 digits
	my $salt = '$6$';
	for (my $i=0; $i<16; $i++) {
		$salt .= ('.','/','0'..'9','A'..'Z','a'..'z')[rand 64];
	}

	my $cryptPassword = crypt(trim_spaces($clearPassword), $salt);
	return $cryptPassword;
}

## Utility function to trim whitespace off the start and end of its input
sub trim_spaces {
	my $in = shift;
	return '' unless $in;  # skip blank spaces
	$in =~ s/^\s*|\s*$//g;
	return($in);
}

# ==================================================================
my $inputfile = shift;
my $outfile = "crypted_" . $inputfile;

if ( -e $inputfile && -r $inputfile ) {
	my $fh; my $outfh;
	open( my $fh, "<", $inputfile ) or die "cannot open $inputfile";
	open( my $outfh, ">", $outfile ) or die "cannot open $outfile";
	my $line;
	my @fields;
	while ( $line = <$fh> ) {
		if ( $line =~ /^#/ ) {
			# Do not process comment lines
			print $outfh $line;
		} else {
			@fields = split( ",", $line );
			$fields[9] = cryptPassword( $fields[9] );
			print $outfh join(",",@fields);
		}
	}
	close $outfh or die "cannot close $outfile";
	close $fh or die "cannot close $inputfile";
	print "Output is in the file $outfile\n";
} else {
	print "Usage: crypt_passwords_in_classlist.pl filename";
}
