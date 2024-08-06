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

package WeBWorK::Authen::LTIAdvanced::Nonce;

use strict;
use warnings;
use experimental 'signatures';

# This controls how often the key database is scrubbed for old nonces.
use constant NONCE_PURGE_FREQUENCY => 7200;    # 2 hours

# This controls how old a nonce is before it is purged.
use constant NONCE_LIFETIME => 21600;          # 6 hours

sub new ($invocant, $c, $nonce, $timestamp) {
	return bless { c => $c, nonce => $nonce, timestamp => $timestamp }, ref($invocant) || $invocant;
}

sub ok ($self) {
	my $c  = $self->{c};
	my $ce = $c->ce;
	my $db = $c->db;

	$self->maybe_purge_nonces;

	if ($self->{timestamp} < time - $ce->{LTI}{v1p1}{NonceLifeTime}) {
		if ($ce->{debug_lti_parameters}) {
			warn('Nonce Expired.  Your NonceLifeTime may be too short');
		}
		return 0;
	}

	my $key = $db->getKey($self->{nonce});

	if (!defined $key) {
		# The nonce has not been used before, and so it is okay. Add the nonce so it is not used again.
		$key = $db->newKey(user_id => $self->{nonce}, key => 'nonce', timestamp => $self->{timestamp});
		$db->addKey($key);
		return 1;
	} else {
		# The nonce is in the database which means it was used "recently".  So it should NOT be allowed.
		if ($key->timestamp < $self->{timestamp}) {
			# Update the timestamp so that deletion will be delayed from the most recent time it was used.
			$key->timestamp($self->{timestamp});
			$db->putKey($key);
		}
		return 0;
	}
}

sub maybe_purge_nonces ($self) {
	my $c  = $self->{c};
	my $ce = $c->ce;
	my $db = $c->db;

	my $time      = time;
	my $lastPurge = $db->getSettingValue('lastNoncePurge');

	# Only purge if there has not been a purge yet, or if last purge was before NONCE_PURGE_FREQUENCY seconds ago.
	if (!defined $lastPurge || $time - $lastPurge > NONCE_PURGE_FREQUENCY) {
		# Delete any "nonce" keys that are older than NONCE_LIFETIME
		for my $key ($db->getKeys($db->listKeys)) {
			$db->deleteKey($key->user_id) if $key->key eq 'nonce' && $time - $key->timestamp > NONCE_LIFETIME;
		}

		$db->setSettingValue('lastNoncePurge', $time);
	}

	return;
}

1;
