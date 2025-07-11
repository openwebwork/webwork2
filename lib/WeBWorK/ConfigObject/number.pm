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
