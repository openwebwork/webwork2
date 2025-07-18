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

sub entry_widget ($self, $default, $is_secret = 0) {
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
