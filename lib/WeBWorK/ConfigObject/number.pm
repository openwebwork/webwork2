package WeBWorK::ConfigObject::number;
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;

sub save_string ($self, $oldval, $use_current = 0) {
	my $newval = $self->convert_newval_source($use_current);
	return $self->reject($oldval, $use_current,
		$self->{c}->maketext('Invalid numeric value "[_1]" for variable $[_2].', $newval, $self->{var}))
		unless $newval =~ m/^[-+]?(\d+(\.\d*)?|\.\d+)$/;

	return '' if $self->comparison_value($oldval) == +$newval;
	return "\$$self->{var} = $newval;\n";
}

1;
