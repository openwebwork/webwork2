package WeBWorK::ConfigObject::list;
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;

sub display_value ($self, $val) {
	my $c = $self->{c};
	return $c->b('&nbsp;') if ref $val ne 'ARRAY';
	my $str = $c->c(@$val)->join(',' . $c->tag('br'));
	return $str =~ /\S/ ? $str : $c->b('&nbsp;');
}

sub comparison_value ($self, $val) {
	return join(',', @{ $val // [] });
}

sub save_string ($self, $oldval, $use_current = 0) {
	my $newval    = $self->convert_newval_source($use_current);
	my $oldString = $self->comparison_value($oldval);

	return '' if $oldString eq $newval;

	$oldString =~ s/^\s*|\s*$//g;
	$newval    =~ s/^\s*|\s*$//g;
	$oldString =~ s/[\s,]+/,/sg;
	$newval    =~ s/[\s,]+/,/sg;
	return '' if $newval eq $oldString;

	my @newvals = split(',', $newval);

	if (!$use_current) {
		my $error = $self->validate(\@newvals);
		return $self->reject($oldval, $use_current, $error) if $error;
	}

	return "\$$self->{var} = [" . join(',', map { $self->quote($_) } @newvals) . "];\n";
}

sub entry_widget ($self, $default, $is_secret = 0) {
	my $str = join(', ', @{ $default // [] });
	return $self->{c}->text_area(
		$self->{name} => $str =~ /\S/ ? $str : '',
		id            => $self->{name},
		rows          => 4,
		class         => 'form-control form-control-sm'
	);
}

1;
