package WeBWorK::Utils;
use base qw(Exporter);

use strict;
use warnings;
use Date::Format;
use Date::Parse;

our @EXPORT    = ();
our @EXPORT_OK = qw(runtime_use readFile formatDate);

sub runtime_use($) {
	return unless @_;
	eval "require $_[0]; import $_[0]";
	die $@ if $@;
}

sub readFile($) {
	my $fileName = shift;
	open INPUTFILE, "<", $fileName
		or die "Failed to read $fileName: $!";
	local $/ = undef;
	my $result = <INPUTFILE>;
	close INPUTFILE;
	return $result;
}

sub formatDateTime($) {
	my $dateTime = shift;
	# "standard" WeBWorK date/time format:
	# %m 	month number, starting with 01
	# %d 	numeric day of the month, with leading zeros (eg 01..31)
	# %y	year (2 digits)
	# %I 	hour, 12 hour clock, leading 0's)
	# %M 	minute, leading 0's
	# %P 	am or pm (Yes %p and %P are backwards :)
	return time2str "%m/%d/%y %I:%M%P", $dateTime;
}

sub parseDateTime($) {
	$string = shift;
	return str2time $string;
}
