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

package WeBWorK::AchievementItems::Surprise;
use parent qw(WeBWorK::AchievementItems);

# Item to print a suprise message

use strict;
use warnings;

use WeBWorK::Utils qw(x);

sub new {
	my ($class) = @_;

	return bless {
		id          => 'Surprise',
		name        => x('Mysterious Package (with Ribbons)'),
		description => x('What could be inside?')
	}, $class;
}

sub print_form {
	my ($self, $sets, $setProblemCount, $r) = @_;

	# The form opens the file "suprise_message.txt" in the achievements
	# folder and prints the contents of the file.

	open my $MESSAGE, '<', "$r->{ce}{courseDirs}{achievements}/surprise_message.txt"
		or return $r->tag('p', $r->maketext(q{I couldn't find the file [ACHIEVEMENT_DIR]/surprise_message.txt!}));
	local $/ = undef;
	my $message = <$MESSAGE>;
	close $MESSAGE;

	return $r->tag('div', $r->b($message));
}

sub use_item {
	# This doesn't do anything.
}

1;
