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

# This page is for triggering LTI grade updates

package WeBWorK::ContentGenerator::Instructor::LTIUpdate;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

use WeBWorK::Utils::Sets                qw(format_set_name_display);
use WeBWorK::Authen::LTI::GradePassback qw(massUpdate);

sub initialize ($c) {
	my $db = $c->db;
	my $ce = $c->ce;

	# Make sure these are defined for the template.
	$c->stash->{sets}       = [];
	$c->stash->{users}      = [];
	$c->stash->{lastUpdate} = 0;

	return unless ($c->authz->hasPermissions($c->param('user'), 'score_sets') && $ce->{LTIGradeMode});

	my $allUserSets = {};
	for ($db->listUserSetsWhere) { push(@{ $allUserSets->{ $_->[0] } }, $_->[1]) }

	$c->stash->{sets}       = [ sort $db->listGlobalSets ] if $ce->{LTIGradeMode} eq 'homework';
	$c->stash->{users}      = [ sort keys %$allUserSets ];
	$c->stash->{userSets}   = $allUserSets;
	$c->stash->{lastUpdate} = $db->getSettingValue('LTILastUpdate') || 0;

	return unless ($c->param('updateLTI'));

	my @setIDs = ($c->param('updateSetID'));
	my $userID = $c->param('updateUserID');

	# Test if setID and userID are valid.
	if ($userID && !$allUserSets->{$userID}) {
		$c->addbadmessage($c->maketext('Update aborted. Invalid user [_1].', $userID));
		return;
	}
	if ($ce->{LTIGradeMode} eq 'homework' && !@setIDs) {
		$c->addbadmessage($c->maketext('Update aborted. No sets selected.'));
		return;
	}

	if ($ce->{LTIGradeMode} eq 'homework') {
		my $nSets = scalar(@setIDs);
		# If all sets are selected, set @setIDs to be empty, and inform the user all sets are being updated.
		if (($userID && $nSets == @{ $allUserSets->{$userID} }) || (!$userID && $nSets == @{ $c->stash->{sets} })) {
			$nSets  = 0;
			@setIDs = ();
		}

		if ($userID) {
			if ($nSets) {
				$c->addgoodmessage(
					$c->maketext('LTI update of [_1] [plural,_1,set] for user [_2] queued.', $nSets, $userID));
			} else {
				$c->addgoodmessage($c->maketext('LTI update of all sets for user [_1] queued.', $userID));
			}
		} elsif ($nSets) {
			$c->addgoodmessage($c->maketext('LTI update of [_1] [plural,_1,set] for all users queued.', $nSets));
		} else {
			$c->addgoodmessage($c->maketext('LTI update of all sets for all users queued.'));
		}
	} else {
		if ($userID) {
			$c->addgoodmessage($c->maketext('LTI update of course grade for user [_1] queued.', $userID));
		} else {
			$c->addgoodmessage($c->maketext('LTI update of course grade for all users queued.'));
		}
	}

	# Note that if somehow this point is reached with setIDs and grade mode is "course",
	# then the setIDs will be ignored by the job.

	massUpdate($c, 1, $userID, @setIDs ? \@setIDs : '');

	return;
}

sub format_interval ($c, $seconds) {
	my $minutes = int($seconds / 60);
	my $hours   = int($minutes / 60);
	my $days    = int($hours / 24);
	my $out     = '';

	return $c->maketext('0 seconds') unless $seconds > 0;

	$seconds = $seconds - 60 * $minutes;
	$minutes = $minutes - 60 * $hours;
	$hours   = $hours - 24 * $days;

	$out .= $c->maketext('[quant,_1,day]',    $days) . ' '    if $days;
	$out .= $c->maketext('[quant,_1,hour]',   $hours) . ' '   if $hours;
	$out .= $c->maketext('[quant,_1,minute]', $minutes) . ' ' if $minutes;
	$out .= $c->maketext('[quant,_1,second]', $seconds) . ' ' if $seconds;
	chop($out);

	return $out;
}

1;
