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

package WeBWorK::ConfigObject::list;
use parent qw(WeBWorK::ConfigObject);

use strict;
use warnings;

sub display_value {
	my ($self, $val) = @_;
	my $r = $self->{Module}->r;
	return $r->b('&nbsp;') if ref $val ne 'ARRAY';
	my $str = $r->c(@$val)->join(',' . $r->tag('br'));
	return $str =~ /\S/ ? $str : $r->b('&nbsp');
}

sub comparison_value {
	my ($self, $val) = @_;
	return join(',', @{ $val // [] });
}

sub save_string {
	my ($self, $oldval, $use_current) = @_;
	my $newval = $self->convert_newval_source($use_current);
	$oldval = $self->comparison_value($oldval);

	return '' if $oldval eq $newval;

	$oldval =~ s/^\s*|\s*$//g;
	$newval =~ s/^\s*|\s*$//g;
	$oldval =~ s/[\s,]+/,/sg;
	$newval =~ s/[\s,]+/,/sg;
	return '' if $newval eq $oldval;

	# This is a new value.  Turn it back into a string and return it.
	return "\$$self->{var} = [" . join(',', map {"'$_'"} map { $_ =~ s/['"`]//gr } split(',', $newval)) . "];\n";
}

sub entry_widget {
	my ($self, $default) = @_;
	my $str = join(', ', @{ $default // [] });
	return $self->{Module}->r->text_area(
		$self->{name} => $str =~ /\S/ ? $str : '',
		id            => $self->{name},
		rows          => 4,
		class         => 'form-control form-control-sm'
	);
}

1;
