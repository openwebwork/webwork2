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
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;

sub display_value ($self, $val) {
	my $c = $self->{c};
	return $c->b('&nbsp;') if ref $val ne 'ARRAY';
	my $str = $c->c(@$val)->join(',' . $c->tag('br'));
	return $str =~ /\S/ ? $str : $c->b('&nbsp;');
}

sub comparison_value ($self, $val) {
	return join(',', @{ $val // [] });
}

sub save_string ($self, $oldval, $use_current = 0) {
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

sub entry_widget ($self, $default, $is_secret = 0) {
	my $str = join(', ', @{ $default // [] });
	return $self->{c}->text_area(
		$self->{name} => $str =~ /\S/ ? $str : '',
		id            => $self->{name},
		rows          => 4,
		class         => 'form-control form-control-sm'
	);
}

1;
