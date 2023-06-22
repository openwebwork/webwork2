################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::Utils::PODParser;
use parent qw(Pod::Simple::XHTML);

use strict;
use warnings;

use Pod::Simple::XHTML;
use File::Find;

sub new {
	my $invocant = shift;
	my $class    = ref $invocant || $invocant;
	my $self     = $class->SUPER::new(@_);
	$self->perldoc_url_prefix("https://metacpan.org/pod/");
	$self->index(1);
	$self->backlink(1);
	return bless $self, $class;
}

# Attempt to resolve links to local files.  If a local file is not found, then
# let Pod::Simple::XHTML resolve to a cpan link.
# Really this is a workaround for invalid `L<...>` usage in the PG POD.
sub resolve_pod_page_link {
	my ($self, $to, $section) = @_;

	unless (defined $to) {
		print "Using internal page link.\n" if $self->{verbose} > 2;
		return $self->SUPER::resolve_pod_page_link($to, $section);
	}

	# This ignores $to if $section is set.  It would probably be better
	# to check for "$to/$section" if both are set.
	$self->{pod_search} = $section // $to;
	find({ wanted => $self->pod_wanted }, $self->{source_root});
	delete $self->{pod_search};

	if ($self->{pod_found}) {
		my $pod_url = $self->{pod_found} =~ s/^$self->{source_root}/$self->{base_url}/r;
		delete $self->{pod_found};
		print "Resolved local pod link $to" . ($section ? "/$section" : "") . " to $pod_url\n" if $self->{verbose} > 2;
		return $self->encode_entities($pod_url);
	}

	print "Using cpan pod link for $to" . ($section ? "/$section" : "") . "\n" if $self->{verbose} > 2;
	return $self->SUPER::resolve_pod_page_link($to, $section);
}

# This takes the first file found that matches.
sub pod_wanted {
	my $self = shift;
	return sub {
		my $filename = $_;
		my $path     = $File::Find::name;
		my $dir      = $File::Find::dir;

		if ($self->{pod_found}) {
			$File::Find::prune = 1;
			return;
		}

		if (-d $path && $filename =~ /^(\.git|\.github|t|htdocs)$/) {
			$File::Find::prune = 1;
			return;
		}

		if ($filename eq $self->{pod_search}) {
			$self->{pod_found} = $self->{assert_html_ext} ? ($path =~ s/\.(pm|pl)$/.html/r) : $path;
			$File::Find::prune = 1;
			return;
		}
	};
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
