package Helper;

use warnings;
use strict;
use base 'Exporter';

our @EXPORT_OK = 'runScript';

sub runScript {
	my $script_path = shift;
	unless (do $script_path) {
		warn "Execution of $script_path failed:\n";
		die $@ if $@;
	}
}

1;
