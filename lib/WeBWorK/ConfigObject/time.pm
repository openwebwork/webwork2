################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.	 See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::ConfigObject::time;
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;

# Just like WeBWorK::ConfigObject::text, but it validates the time before saving.

sub save_string ($self, $oldval, $use_current = 0) {
	my $newval = $self->convert_newval_source($use_current);
	return '' if $self->comparison_value($oldval) eq $newval;

	if ($newval !~ /^(01|1|02|2|03|3|04|4|05|5|06|6|07|7|08|8|09|9|10|11|12):[0-5]\d(am|pm|AM|PM)$/) {
		$self->{c}->addbadmessage(qq{String "$newval" is not a valid time.  Reverting to the system default value.});
		return '';
	}

	return "\$$self->{var} = '$newval';\n";
}

1;
