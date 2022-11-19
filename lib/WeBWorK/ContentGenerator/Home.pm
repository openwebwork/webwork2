################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::ContentGenerator::Home;
use parent qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Home - display a list of courses.

=cut

use strict;
use warnings;

use WeBWorK::Utils qw(readFile);
use WeBWorK::Localize;

sub info {
	my ($self) = @_;
	my $r = $self->r;

	my $result;

	# This section should be kept in sync with the Login.pm version
	my $site_info = $r->ce->{webworkFiles}{site_info};
	if ($site_info && -f $site_info) {
		# Show the site info file.
		my $text = eval { readFile($site_info) };
		if ($@) {
			$result = $r->tag('div', class => 'alert alert-danger p-1 mb-0', $@);
		} elsif ($text =~ /\S/) {
			$result = $text;
		}
	}

	return $result ? $r->c($r->tag('h2', $r->maketext('Site Information')), $result)->join('') : '';
}

# Override the can method to disable links for the home page.
sub can {
	my ($self, $arg) = @_;
	return $arg eq 'links' ? 0 : $self->SUPER::can($arg);
}

1;
