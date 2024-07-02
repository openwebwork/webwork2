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

package WeBWorK::ConfigObject::number;
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;

sub save_string ($self, $oldval, $use_current = 0) {
	my $newval = $self->convert_newval_source($use_current) =~ s/['"`]//gr;
	if ($newval !~ m/^[-+]?(\d+(\.\d*)?|\.\d+)$/) {
		$self->{c}->addbadmessage(qq{Invalid numeric value "$newval" for variable \$$self->{var}.  }
				. 'Reverting to the system default value.');
		return '';
	}

	return '' if $self->comparison_value($oldval) == +$newval;
	return "\$$self->{var} = $newval;\n";
}

1;
