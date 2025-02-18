################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to print a suprise message

use WeBWorK::Utils qw(x);

sub new ($class) {
	return bless {
		id          => 'Surprise',
		name        => x('Mysterious Package (with Ribbons)'),
		description => x('What could be inside?')
	}, $class;
}

# Override to not print number of items that remain.
sub remaining_title ($self, $c) {
	return $c->maketext($self->name);
}

sub can_use ($self, $set, $records) { return 1; }

sub print_form ($self, $set, $records, $c) {
	$self->{hideUseButton} = 1;

	# The form opens the file "surprise_message.txt" in the achievements
	# folder and prints the contents of the file.
	open my $MESSAGE, '<', "$c->{ce}{courseDirs}{achievements}/surprise_message.txt"
		or return $c->tag('p', $c->maketext(q{I couldn't find the file [ACHIEVEMENT_DIR]/surprise_message.txt!}));
	local $/ = undef;
	my $message = <$MESSAGE>;
	close $MESSAGE;

	return $c->tag('div', $c->b($message));
}

sub use_item ($self, $set, $records, $c) {
	# This doesn't do anything.
}

1;
