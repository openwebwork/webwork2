#!/usr/bin/perl
################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
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

use strict;
use warnings;

use Pod::Simple::XHTML;

package PODParser;
our @ISA = qw(Pod::Simple::XHTML);

use File::Find;

sub new {
	my $invocant = shift;
	my $class = ref $invocant || $invocant;
	my $self = $class->SUPER::new(@_);
	$self->perldoc_url_prefix("https://metacpan.org/pod/");
	$self->index(1);
	$self->backlink(1);
	return bless $self, $class;
}

# Attempt to resolve links to local files.  If a local file is not found, then
# let Pod::Simple::XHTML resolve to a cpan link.
sub resolve_pod_page_link {
	my ($self, $to, $section) = @_;

	# This ignores $to if $section is set.  It would probably be better
	# to check for "$to/$section" if both are set.
	$self->{pod_search} = $section // $to;
	find({ wanted => $self->pod_wanted }, $self->{source_root});
	undef $self->{pod_search};

	if ($self->{pod_found}) {
		my $pod_url = $self->{pod_found} =~ s/^$self->{source_root}/$self->{base_url}/r;
		undef $self->{pod_found};
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
		my $path = $File::Find::name;
		my $dir = $File::Find::dir;

		$File::Find::prune = 1, return if ($self->{pod_found});

		if (-d $path && $filename =~ /^(\.git|\.github|t|htdocs)$/) {
			$File::Find::prune = 1;
			return;
		}

		if ($filename eq $self->{pod_search}) {
			$self->{pod_found} = $path =~ s/\.(pm|pl)$/.html/r;
			$File::Find::prune = 1;
			return;
		}
	};
}

# Don't output anything for a malformed =head[1-4] with no header text.
# This is done in pg/lib/Matrix.pm, for example.
sub _end_head {
	my $self = shift;
	if ($self->{scratch}) {
		return $self->SUPER::_end_head(@_);
	}
	delete $self->{in_head};
	return "";
}

1;
