package WeBWorK::DB::Record::SetVersion;
use base WeBWorK::DB::Record::UserSet;

=head1 NAME

WeBWorK::DB::Record::SetVersion - represent a record from the virtual
set_version table.

=cut

use strict;
use warnings;

BEGIN {
	our @ISA;
	my $base         = $ISA[0];
	my $field_data   = $base->FIELD_DATA;
	my @nonkeyfields = map { $_ => $field_data->{$_} } $base->NONKEYFIELDS;
	__PACKAGE__->_fields(
		user_id    => { type => "VARCHAR(100) NOT NULL", key => 1 },
		set_id     => { type => "VARCHAR(100) NOT NULL", key => 1 },
		version_id => { type => "INT NOT NULL",          key => 1 },
		@nonkeyfields,
	);
}

1;
