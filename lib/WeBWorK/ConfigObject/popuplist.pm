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

package WeBWorK::ConfigObject::popuplist;
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;

sub display_value ($self, $val) {
	my $c = $self->{c};
	$val //= 'ur';
	return $c->c($c->maketext($self->{labels}{$val}))->join($c->tag('br')) if ($self->{labels}{$val});
	return $c->c($val)->join($c->tag('br'));
}

sub save_string ($self, $oldval, $use_current = 0) {
	my $newval = $self->convert_newval_source($use_current);
	return '' if $self->comparison_value($oldval) eq $newval;
	return ("\$$self->{var} = '$newval';\n");
}

sub entry_widget ($self, $default) {
	my $c = $self->{c};
	return $c->select_field(
		$self->{name} => [
			map { [ $c->maketext($self->{labels}{$_} // $_) => $_, $default eq $_ ? (selected => undef) : () ] }
				@{ $self->{values} }
		],
		id    => $self->{name},
		class => 'form-select form-select-sm',
	);
}

1;
