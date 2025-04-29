package WeBWorK::ConfigObject::popuplist;
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;

sub display_value ($self, $val) {
	my $c = $self->{c};
	$val //= 'ur';
	return $c->c($c->maketext($self->{labels}{$val}))->join($c->tag('br')) if ($self->{labels}{$val});
	return $c->c($val)->join($c->tag('br'));
}

sub save_string ($self, $oldval, $use_current = 0) {
	my $newval = $self->convert_newval_source($use_current);
	return '' if $self->comparison_value($oldval) eq $newval;
	return ("\$$self->{var} = '$newval';\n");
}

sub entry_widget ($self, $default, $is_secret = 0) {
	my $c = $self->{c};
	return $c->select_field(
		$self->{name} => [
			map { [ $c->maketext($self->{labels}{$_} // $_) => $_, $default eq $_ ? (selected => undef) : () ] }
				@{ $self->{values} }
		],
		id    => $self->{name},
		class => 'form-select form-select-sm',
	);
}

1;
