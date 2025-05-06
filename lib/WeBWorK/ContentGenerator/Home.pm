package WeBWorK::ContentGenerator::Home;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Home - display a list of courses.

=cut

use WeBWorK::Utils::Files qw(readFile);

sub info ($c) {
	my $result;

	# This section should be kept in sync with the Login.pm version
	my $site_info = $c->ce->{webworkFiles}{site_info};
	if ($site_info && -f $site_info) {
		# Show the site info file.
		my $text = eval { readFile($site_info) };
		if ($@) {
			$result = $c->tag('div', class => 'alert alert-danger p-1 mb-0', $@);
		} elsif ($text =~ /\S/) {
			$result = $text;
		}
	}

	return $result ? $c->c($c->tag('h2', $c->maketext('Site Information')), $result)->join('') : '';
}

# Override the can method to disable links for the home page.
sub can ($c, $arg) {
	return $arg eq 'links' ? 0 : $c->SUPER::can($arg);
}

1;
