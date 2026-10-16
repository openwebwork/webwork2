package WeBWorK::ConfigObject::time;
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;

# Just like WeBWorK::ConfigObject::text, but it validates the time before saving.

sub save_string ($self, $oldval, $use_current = 0) {
	my $newval = $self->convert_newval_source($use_current);
	return '' if $self->comparison_value($oldval) eq $newval;

	my ($hour, $ampm) = $newval =~ /^\s*(\d{1,2})\s*:\s*[0-5]\d\s*(am|pm|AM|PM)?\s*\z/;
	return $self->reject($oldval, $use_current, $self->{c}->maketext('String "[_1]" is not a valid time.', $newval))
		unless defined $hour && ($ampm ? $hour >= 1 && $hour <= 12 : $hour <= 23);

	return "\$$self->{var} = '$newval';\n";
}

1;
