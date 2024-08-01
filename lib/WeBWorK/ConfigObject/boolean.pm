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

package WeBWorK::ConfigObject::boolean;
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;

sub comparison_value ($self, $value) { return $value ? 1 : 0; }

sub display_value ($self, $val) {
	return $self->{c}->maketext('True') if $val;
	return $self->{c}->maketext('False');
}

sub save_string ($self, $oldval, $use_current = 0) {
	my $newval = $self->convert_newval_source($use_current);
	return '' if $self->comparison_value($oldval) eq $newval;
	return "\$$self->{var} = $newval;\n";
}

sub entry_widget ($self, $default, $is_secret) {
	return $self->{c}->select_field(
		$self->{name} => [
			[ $self->{c}->maketext('True')  => 1, $default == 1 ? (selected => undef) : () ],
			[ $self->{c}->maketext('False') => 0, $default == 0 ? (selected => undef) : () ]
		],
		id    => $self->{name},
		class => 'form-select form-select-sm'
	);
}

1;
