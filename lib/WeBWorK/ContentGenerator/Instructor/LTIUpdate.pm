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

use WeBWorK::Utils::Sets qw(format_set_name_display);
use WeBWorK::Authen::LTI::GradePassback qw(massUpdate);

sub initialize ($c) {
	my $db = $c->db;
	my $ce = $c->ce;

	# Make sure these are defined for the template.
	$c->stash->{sets}       = [];
	$c->stash->{users}      = [];
	$c->stash->{lastUpdate} = 0;

	return unless ($c->authz->hasPermissions($c->param('user'), 'score_sets') && $ce->{LTIGradeMode});

	$c->stash->{sets}       = [ sort $db->listGlobalSets ] if $ce->{LTIGradeMode} eq 'homework';
	$c->stash->{users}      = [ sort $db->listUsers ];
	$c->stash->{lastUpdate} = $db->getSettingValue('LTILastUpdate') || 0;

	return unless ($c->param('updateLTI'));

	my $setID       = $c->param('updateSetID');
	my $userID      = $c->param('updateUserID');
	my $prettySetID = format_set_name_display($setID // '');

	# Test if setID and userID are valid.
	if ($userID && !$db->getUser($userID)) {
		$c->addbadmessage($c->maketext('Update aborted. Invalid user [_1].', $userID));
		return;
	}
	if ($ce->{LTIGradeMode} eq 'homework' && $setID && !$db->getGlobalSet($setID)) {
		$c->addbadmessage($c->maketext('Update aborted. Invalid set [_1].', $prettySetID));
		return;
	}

	if ($setID && $userID && $ce->{LTIGradeMode} eq 'homework') {
		$c->addgoodmessage($c->maketext('LTI update of user [_1] and set [_2] queued.', $userID, $prettySetID));
	} elsif ($setID && $ce->{LTIGradeMode} eq 'homework') {
		$c->addgoodmessage($c->maketext('LTI update of set [_1] queued.', $prettySetID));
	} elsif ($userID) {
		$c->addgoodmessage($c->maketext('LTI update of user [_1] queued.', $userID));
	} else {
		$c->addgoodmessage($ce->{LTIGradeMode} eq 'homework'
			? $c->maketext('LTI update of all users and sets queued.')
			: $c->maketext('LTI update of all users queued.'));
	}

	# Note that if somehow this point is reached with a setID and grade mode is "course",
	# then the setID will be ignored by the job.

	massUpdate($c, 1, $userID, $setID);

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
