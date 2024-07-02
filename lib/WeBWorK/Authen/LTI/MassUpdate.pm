###############################################################################
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

package WeBWorK::Authen::LTI::MassUpdate;
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

WeBWorK::Authen::LTI::MassUpdate - Mass update grades to the LMS with LTI authentication

=cut

our @EXPORT_OK = qw(mass_update);

# Perform a mass update of all grades.  This is all user grades for course grade mode and all user set grades for
# homework grade mode if $manual_update is false.  Otherwise what is updated is determined by a combination of the grade
# mode and the useriD and setID parameters.  Note that the only required parameter is $c which should be a
# WeBWorK::Controller object with a valid course environment and database.
sub mass_update ($c, $manual_update = 0, $userID = undef, $setID = undef) {
	my $ce = $c->ce;
	my $db = $c->db;

	# Sanity check.
	unless (ref($ce)) {
		warn('course environment is not defined');
		return;
	}
	unless (ref($db)) {
		warn('database reference is not defined');
		return;
	}

	# Only run an automatic update if the time interval has passed.
	if (!$manual_update) {
		my $lastUpdate     = $db->getSettingValue('LTILastUpdate') || 0;
		my $updateInterval = $ce->{LTIMassUpdateInterval} // -1;
		return unless ($updateInterval != -1 && time - $lastUpdate > $updateInterval);
		$db->setSettingValue('LTILastUpdate', time);
	}

	# Send warning if debug_lti_grade_passback is set.
	if ($ce->{debug_lti_grade_passback}) {
		if ($setID && $userID && $ce->{LTIGradeMode} eq 'homework') {
			warn "LTI Mass Update: Queueing grade update for user $userID and set $setID.\n";
		} elsif ($setID && $ce->{LTIGradeMode} eq 'homework') {
			warn "LTI Mass Update: Queueing grade update for all users assigned to set $setID.\n";
		} elsif ($userID) {
			warn "LTI Mass Update: Queueing grade update of all sets assigned to user $userID.\n";
		} else {
			warn "LTI Mass Update: Queueing grade update for all sets and users.\n";
		}
	}

	$c->minion->enqueue(lti_mass_update => [ $userID, $setID ], { notes => { courseID => $ce->{courseName} } });

	return;
}

1;
