package WeBWorK::RuntimeUse;

use base qw(Exporter);

our @EXPORT    = ();
our @EXPORT_OK = qw(runtime_use);

sub runtime_use($) {
	return unless @_;
	eval "require $_[0]; import $_[0]";
	die $@ if $@;
}
