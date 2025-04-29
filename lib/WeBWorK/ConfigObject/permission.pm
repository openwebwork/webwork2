package WeBWorK::ConfigObject::permission;
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;

sub comparison_value ($self, $val) {
	return $val // 'nobody';
}

# This tries to produce a string from a permission number.  If you feed it a string, that's what you get back.
sub display_value ($self, $val) {
	my $c = $self->{c};
	return $c->maketext('nobody') if !defined $val;
	my %reverseUserRoles = reverse %{ $c->ce->{userRoles} };
	return defined $reverseUserRoles{$val} ? $c->maketext($reverseUserRoles{$val}) : $c->maketext($val);
}

sub save_string ($self, $oldval, $use_current = 0) {
	my $newval = $self->convert_newval_source($use_current);
	return '' if $self->comparison_value($oldval) eq $newval;
	return "\$$self->{var} = '$newval';\n";
}

sub entry_widget ($self, $default, $is_secret = 0) {
	my $c = $self->{c};

	# The value of a permission can be undefined (for nobody), a standard permission number, or some other number
	my %userRoles = %{ $c->ce->{userRoles} };
	my @values    = sort { $userRoles{$a} <=> $userRoles{$b} } keys %userRoles;

	return $c->select_field(
		$self->{name} =>
			[ map { [ $c->maketext($_) => $_, ($default // 'nobody') eq $_ ? (selected => undef) : () ] } @values ],
		id    => $self->{name},
		class => 'form-select form-select-sm',
	);
}

1;
