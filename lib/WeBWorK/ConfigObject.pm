package WeBWorK::ConfigObject;

# Base object class for all config objects

use strict;
use warnings;

use URI::Escape;

sub new {
	my ($class, $self, $module) = @_;
	# The module should be a content generator module.
	$self->{Module} = $module;
	$self->{name}   = ($self->{var} =~ s/[{]/_/gr) =~ s/[}]//gr;
	return bless $self, $class;
}

# Only input is a value to display, and should produce an html string.
sub display_value {
	my ($self, $val) = @_;
	return $val;
}

# This should return the value to compare to the new value.  This is *not* what is displayed.
sub comparison_value {
	my ($self, $val) = @_;
	return $val;
}

# Get the value of the corresponding variable in the provided course environment.
sub get_value {
	my ($self, $ce) = @_;

	my @keys = $self->{var} =~ m/([^{}]+)/g;
	return '' unless @keys;

	my $value = $ce;
	for (@keys) {
		$value = $value->{$_};
	}
	return $value;
}

# If use_current is true then return the current course environment value for this setting.
# Otherwise use the value of the html form element.
sub convert_newval_source {
	my ($self, $use_current) = @_;
	if ($use_current) {
		return $self->comparison_value($self->get_value($self->{Module}->r->ce));
	} else {
		return $self->{Module}->r->param($self->{name}) // '';
	}
}

# Bit of text to put in the configuration file.  The result should be an assignment which is executable by perl.  oldval
# will be the value of the perl variable, and newval will be whatever an entry widget produces.
sub save_string {
	my ($self, $oldval, $use_current) = @_;

	my $newval = $self->convert_newval_source($use_current);
	return '' if $self->comparison_value($oldval) eq $newval;

	$newval =~ s/['"`]//g;
	return "\$$self->{var} = '$newval';\n";
}

# A widget to interact with the user
sub entry_widget {
	my ($self, $default) = @_;
	return $self->{Module}->r->text_field(
		$self->{name} => $default,
		id            => $self->{name},
		size          => $self->{width} || 15,
		class         => 'form-control form-control-sm'
	);
}

# This produces the documentation string and image link to more documentation.  It is the same for all config types.
sub what_string {
	my ($self) = @_;
	my $r = $self->{Module}->r;

	return $r->tag(
		'div',
		class => 'd-flex justify-content-between align-items-center',
		$r->c(
			$r->tag(
				'div',
				ref $self eq 'WeBWorK::ConfigObject::checkboxlist'
				? $r->b($r->maketext($self->{doc}))
				: $r->label_for($self->{name} => $r->b($r->maketext($self->{doc})))
			),
			$r->link_to(
				$r->tag(
					'i',
					class         => 'icon fas fa-question-circle',
					'aria-hidden' => 'true',
					data          => { alt => 'help' },
					''
				) => $self->{Module}->systemLink(
					$r->urlpath->new(
						type => 'instructor_config',
						args => { courseID => $r->urlpath->arg('courseID') }
					),
					params => { show_long_doc => 1, var_name => uri_escape($self->{var}) }
				),
				target => '_blank'
			)
		)->join('')
	);
}

1;
