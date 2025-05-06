package WeBWorK::ConfigObject::permission_checkboxlist;
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;
use WeBWorK::Utils 'role_and_above';

sub display_value ($self, $val) {
	$val = role_and_above($self->{c}->ce->{userRoles}, $val) unless ref($val) eq 'ARRAY';
	return $self->{c}->c(@{ $val // [] })->join($self->{c}->tag('br'));
}

# r->param() returns an array, so a custom version of convert_newval_source is needed.
sub convert_newval_source ($self, $use_current) {
	if ($use_current) {
		if (ref $self->get_value($self->{c}->ce) eq 'ARRAY') {
			return @{ $self->get_value($self->{c}->ce) };
		} else {
			return @{ role_and_above($self->{c}->ce->{userRoles}, $self->get_value($self->{c}->ce)) };
		}
	} else {
		return $self->{c}->param($self->{name});
	}
}

sub save_string ($self, $oldval, $use_current = 0) {
	my @newvals = $self->convert_newval_source($use_current);
	if ($self->{min} && scalar(@newvals) < $self->{min}) {
		$self->{c}->addbadmessage("You need to select at least $self->{min} display mode.");
		return '' if $use_current;
		return $self->save_string($oldval, 1);
	}
	return '' if $self->comparison_value($oldval) eq $self->comparison_value(\@newvals);
	return "\$$self->{var} = [" . join(',', map {"'$_'"} @newvals) . "];\n";
}

sub comparison_value ($self, $val) {
	$val = role_and_above($self->{c}->ce->{userRoles}, $val) unless ref($val) eq 'ARRAY';
	return join(',', @{ $val // [] });
}

sub entry_widget ($self, $default, $is_secret = 0) {
	my $c         = $self->{c};
	my $userRoles = $self->{c}->ce->{userRoles};
	$default = role_and_above($userRoles, $default) unless ref($default) eq 'ARRAY';
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
		} grep { $_ ne 'nobody' } sort { $userRoles->{$a} <=> $userRoles->{$b} } keys(%$userRoles)
	)->join('');
}

1;
