package WeBWorK::Utils;

use base qw(Exporter);

our @EXPORT    = ();
our @EXPORT_OK = qw(runtime_use readFile);

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
