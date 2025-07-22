package WeBWorK::ConfigObject::timezone;
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;

# Just like WeBWorK::ConfigObject::text, but it validates the timezone before saving.

use DateTime::TimeZone;

sub save_string ($self, $oldval, $use_current = 0) {
	my $newval = $self->convert_newval_source($use_current);
	return '' if $self->comparison_value($oldval) eq $newval;

	if (not DateTime::TimeZone->is_valid_name($newval)) {
		$self->{c}->addbadmessage("String '$newval' is not a valid time zone.  Reverting to the system default value.");
		return '';
	}

	$newval =~ s/['"`]//g;
	return "\$$self->{var} = '$newval';\n";
}

1;
