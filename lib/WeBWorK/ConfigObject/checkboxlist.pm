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

package WeBWorK::ConfigObject::checkboxlist;
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;

sub display_value ($self, $val) {
	return $self->{c}->c(@{ $val // [] })->join($self->{c}->tag('br'));
}

# r->param() returns an array, so a custom version of convert_newval_source is needed.
sub convert_newval_source ($self, $use_current) {
	if ($use_current) {
		return @{ $self->get_value($self->{c}->ce) };
	} else {
		return $self->{c}->param($self->{name});
	}
}

sub save_string ($self, $oldval, $use_current = 0) {
	my @newvals = $self->convert_newval_source($use_current);
	if ($self->{min} && scalar(@newvals) < $self->{min}) {
		$self->{c}->addbadmessage(qq!You need to select at least $self->{min} option for "$self->{doc}".!);
		return '' if $use_current;
		return $self->save_string($oldval, 1);
	}
	return '' if $self->comparison_value($oldval) eq $self->comparison_value(\@newvals);
	return "\$$self->{var} = [" . join(',', map {"'$_'"} @newvals) . "];\n";
}

sub comparison_value ($self, $val) {
	return join(',', @{ $val // [] });
}

sub entry_widget ($self, $default) {
	my $c = $self->{c};
	return $c->c(
		map {
			$c->tag(
				'div',
				class => 'form-check',
				$c->tag(
					'label',
					class => 'form-check-label',
					$c->c(
						$c->check_box(
							$self->{name} => $_,
							{ map { $_ => 1 } @$default }->{$_} ? (checked => undef) : (),
							class => 'form-check-input',
						),
						$_
					)->join('')
				)
			)
		} @{ $self->{values} }
	)->join('');
}

1;
