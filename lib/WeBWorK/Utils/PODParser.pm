package WeBWorK::Utils::PODParser;
use parent qw(Pod::Simple::XHTML);

use strict;
use warnings;

use Pod::Simple::XHTML;
use File::Basename qw(basename);

# $podFiles must be provided in order for pod links to local files to work.  It should be the
# first return value of the POD::Simple::Search survey method.
sub new {
	my ($invocant, $podFiles) = @_;
	my $class = ref $invocant || $invocant;
	my $self  = $class->SUPER::new(@_);
	$self->perldoc_url_prefix("https://metacpan.org/pod/");
	$self->index(1);
	$self->backlink(1);
	$self->html_charset('UTF-8');
	$self->{podFiles} = $podFiles // {};
	return bless $self, $class;
}

# Attempt to resolve links to local files.  If a local file is not found, then
# let Pod::Simple::XHTML resolve to a cpan link.
sub resolve_pod_page_link {
	my ($self, $target, $section) = @_;

	unless (defined $target) {
		print "Using internal page link.\n" if $self->{verbose} > 2;
		return $self->SUPER::resolve_pod_page_link($target, $section);
	}

	my $podFound;
	for (keys %{ $self->{podFiles} }) {
		if ($target eq $_ =~ s/lib:://r || $target eq basename($self->{podFiles}{$_}) =~ s/\.pod$//r) {
			$podFound =
				$self->{assert_html_ext} ? ($self->{podFiles}{$_} =~ s/\.(pm|pl|pod)$/.html/r) : $self->{podFiles}{$_};
			last;
		}
	}

	if ($podFound) {
		my $pod_url = $self->encode_entities($podFound =~ s/^$self->{source_root}/$self->{base_url}/r)
			. ($section ? '#' . $self->idify($self->encode_entities($section), 1) : '');
		print "Resolved local pod link for $target" . ($section ? "/$section" : '') . " to $pod_url\n"
			if $self->{verbose} > 2;
		return $pod_url;
	}

	print "Using cpan pod link for $target" . ($section ? "/$section" : '') . "\n" if $self->{verbose} > 2;
	return $self->SUPER::resolve_pod_page_link($target, $section);
}

# Trim spaces from the beginning of each line in code blocks.  This attempts to
# trim spaces from all lines in the code block in the same amount as there are
# spaces at the beginning of the first line. Note that Pod::Simple::XHTML has
# already converted tab characters into 8 spaces.
sub handle_code {
	my ($self, $code) = @_;
	my $start_spaces = length(($code =~ /^( *)/)[0]) || '';
	$self->SUPER::handle_code($code =~ s/^( {1,$start_spaces})//gmr);
	return;
}

1;
