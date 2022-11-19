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
use parent qw(WeBWorK::ConfigObject);

use strict;
use warnings;

sub display_value {
	my ($self, $val) = @_;
	my $r = $self->{Module}->r;
	$val //= 'ur';
	return $r->c($r->maketext($self->{labels}{$val}))->join($r->tag('br')) if ($self->{labels}{$val});
	return $r->c($val)->join($r->tag('br'));
}

sub save_string {
	my ($self, $oldval, $use_current) = @_;
	my $newval = $self->convert_newval_source($use_current);
	return '' if $self->comparison_value($oldval) eq $newval;
	return ("\$$self->{var} = '$newval';\n");
}

sub entry_widget {
	my ($self, $default) = @_;
	my $r = $self->{Module}->r;
	return $r->select_field(
		$self->{name} => [
			map { [ $r->maketext($self->{labels}{$_} // $_) => $_, $default eq $_ ? (selected => undef) : () ] }
				@{ $self->{values} }
		],
		id    => $self->{name},
		class => 'form-select form-select-sm',
	);
}

1;
