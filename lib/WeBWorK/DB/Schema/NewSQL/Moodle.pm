################################################################################
# WeBWorK Online Homework Delivery System - Moodle Integration
# Copyright (c) 2005 Peter Snoblin <pas@truman.edu>
# $Id$
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

package WeBWorK::DB::Schema::NewSQL::Moodle;
use base qw(WeBWorK::DB::Schema::NewSQL);

=head1 NAME

WeBWorK::DB::Schema::NewSQL::Moodle - Base class for Moodle schema modules.

=cut

use strict;
use warnings;
use Carp qw(croak);

use constant MOODLE_WEBWORK_BRIDGE_TABLE => 'wwassignment_bridge';

=head1 SUPPORTED PARAMS

This schema pays attention to the following items in the C<params> entry.

=over

=item tablePrefix

The prefix on all moodle tables.

=item courseName

The name of the current WeBWorK course.

=back

=cut

################################################################################
# constructor for Moodle-specific behavior
################################################################################

sub new {
	my $proto = shift;
	my $self = $proto->SUPER::new(@_);
	
	# prepend tablePrefix to all table names
	my $transform_table;
	if (defined $self->{params}{tablePrefix}) {
		$transform_table = sub {
			my $label = shift;
			return $self->{params}{tablePrefix} . $label;
		};
	}
	
	# add SQL statement generation object
	$self->{sql} = new WeBWorK::DB::Utils::SQLAbstractIdentTrans(
		quote_char => "`",
		name_sep => ".",
		transform_table => $transform_table,
	);
	
	return $self;
}

################################################################################
# utility methods
################################################################################

sub coursename {
	return shift->{params}{courseName};
}

# all the tables that moodle can handle have a single keypart (user_id) so this
# is somewhat easier that it might otherwise be :)
sub keyparts_to_where {
	my ($self, $userID) = @_;
	return defined $userID ? {username=>$userID} : {};
}

sub gen_update_hashes {
	croak "this would have a moodle-specific implementation if modification was supported";
}

*sql = *WeBWorK::DB::Schema::NewSQL::Std::sql;

1;
