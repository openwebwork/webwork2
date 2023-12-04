package WeBWorK::SafeTemplate;
use Mojo::Base 'Mojo::Template';

# The Mojo::Template _wrap method adds "use Mojo::Base -strict" and "no warnings 'ambiguous'" to the code generated in
# this method.  When that is called later it causes an error in the safe compartment because "require" is trapped. So
# instead this imports strict, warnings, and utf8 which is equivalent to calling "use Mojo::Base -strict". Calling "no
# warnings 'ambiguous'" prevents warnings from a lack of parentheses on a scalar call in the generated code.  So if this
# package is used, those warnings need to be prevented in another way.
sub _wrap {
	my ($self, $body, $vars) = @_;

	# Variables
	my $args = '';
	if ($self->vars && (my @vars = grep {/^\w+$/} keys %$vars)) {
		$args = 'my (' . join(',', map {"\$$_"} @vars) . ')';
		$args .= '= @{shift()}{qw(' . join(' ', @vars) . ')};';
	}

	# Wrap lines
	my $num  = () = $body =~ /\n/g;
	my $code = $self->_line(1) . "\npackage @{[$self->namespace]};";
	$code .= 'BEGIN { strict->import; warnings->import; utf8->import; }';
	$code .= "sub { my \$_O = ''; @{[$self->prepend]};{ $args { $body\n";
	$code .= $self->_line($num + 1) . "\n;}@{[$self->append]}; } \$_O };";

	return $code;
}

1;
