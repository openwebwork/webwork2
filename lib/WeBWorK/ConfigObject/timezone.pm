package WeBWorK::ConfigObject::timezone;
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;

# Just like WeBWorK::ConfigObject::text, but it validates the timezone before saving.

use DateTime::TimeZone;

sub save_string ($self, $oldval, $use_current = 0) {
	my $newval = $self->convert_newval_source($use_current);
	return '' if $self->comparison_value($oldval) eq $newval;

	return $self->reject($oldval, $use_current,
		$self->{c}->maketext('String "[_1]" is not a valid time zone.', $newval))
		unless DateTime::TimeZone->is_valid_name($newval);

	return "\$$self->{var} = " . $self->quote($newval) . ";\n";
}

1;
