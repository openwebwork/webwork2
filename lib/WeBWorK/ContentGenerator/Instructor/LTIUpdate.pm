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

# This page is for triggering LTI grade updates

package WeBWorK::ContentGenerator::Instructor::LTIUpdate;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

use WeBWorK::Utils(qw(format_set_name_display getAssetURL));

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

	my $setID       = $c->param('updateSetID')  || 'All Sets';
	my $userID      = $c->param('updateUserID') || 'All Users';
	my $prettySetID = format_set_name_display($setID);

	# Test if setID and userID are valid.
	unless ($userID eq 'All Users' || $db->getUser($userID)) {
		$c->addbadmessage($c->maketext('Update aborted. Invalid user [_1].', $userID));
		return;
	}
	unless ($ce->{LTIGradeMode} eq 'course' || $setID eq 'All Sets' || $db->getGlobalSet($setID)) {
		$c->addbadmessage($c->maketext('Update aborted. Invalid set [_1].', $prettySetID));
		return;
	}

	my @updateParms;
	if ($setID eq 'All Sets' && $userID eq 'All Users') {
		@updateParms = ('all');
		$c->addgoodmessage($ce->{LTIGradeMode} eq 'homework'
			? $c->maketext('LTI update of all users and sets started.')
			: $c->maketext('LTI update of all users started.'));
	} elsif ($setID eq 'All Sets') {
		@updateParms = ('user', $userID);
		$c->addgoodmessage($c->maketext('LTI update of user [_1] started.', $userID));
	} elsif ($userID eq 'All Users') {
		@updateParms = ('set', $setID);
		$c->addgoodmessage($c->maketext('LTI update of set [_1] started.', $prettySetID));
	} elsif ($ce->{LTIGradeMode} eq 'homework') {
		@updateParms = ('user_set', $userID, $setID);
		$c->addgoodmessage($c->maketext('LTI update of user [_1] and set [_2] started.', $userID, $prettySetID));
	} else {
		# Abort update. A post with a valid setID was sent in course LTIGradeMode,
		# but the page shouldn't allow this. Don't set an updateMessage for this case.
		return;
	}

	my $grader = WeBWorK::Authen::LTIAdvanced::SubmitGrade->new($c);
	$grader->mass_update(@updateParms);
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
