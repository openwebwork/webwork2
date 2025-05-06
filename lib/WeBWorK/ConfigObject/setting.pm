package WeBWorK::ConfigObject::setting;
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;

# Configure settings in the course's setting table.

sub get_value ($self, $ce) {
	# If the course name of the controller's course environment is the same as the passed course environment, then
	# return the value from the database.  Otherwise this is the default site wide setting. So return the empty string
	# (there is no default).
	return $self->{c}->ce->{courseName} eq $ce->{courseName}
		? ($self->{c}->db->getSettingValue($self->{var}) // '')
		: '';
}

# This actually changes a database value, and so must return the empty string
# so that it is not represented in the course's simple.conf file.
sub save_string ($self, $oldval, $use_current = 0) {
	return '' if $use_current;
	$self->{c}->db->setSettingValue($self->{var}, scalar $self->{c}->param($self->{var}));
	return '';
}

sub help_title           ($self) { return $self->{c}->maketext('Setting Documentation') }
sub help_name            ($self) { return $self->{c}->maketext('[_1] setting',                   $self->{var}) }
sub help_link_aria_label ($self) { return $self->{c}->maketext('Setting documentation for [_1]', $self->{var}) }

1;
