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

package WeBWorK::Authen::LDAP;
use base qw/WeBWorK::Authen/;

use strict;
use warnings;

use WeBWorK::Debug qw(debug);
use Net::LDAP      qw(LDAP_INVALID_CREDENTIALS);

sub checkPassword {
	my ($self, $userID, $possibleClearPassword) = @_;
	my $ce       = $self->{c}->ce;
	my $failover = $ce->{authen}{ldap_options}{failover};

	debug("LDAP module is doing the password checking.\n");

	# Don't attempt to check a password if one wasn't entered.
	return 0 unless $possibleClearPassword =~ /\S/;

	# check against LDAP server
	my $ret = $self->ldap_authen_uid($userID, $possibleClearPassword);
	return 1 if ($ret == 1);

	# optional: fail over to superclass checkPassword
	if ($failover eq "all" || $failover eq "1" || ($failover eq "local" && $ret < 0)) {
		$self->write_log_entry("AUTH LDAP: authentication failed, deferring to superclass");
		return $self->SUPER::checkPassword($userID, $possibleClearPassword);
	}

	# fail by default
	return 0;
}

sub ldap_authen_uid {
	my ($self, $uid, $password) = @_;
	my $ce           = $self->{c}->ce;
	my $hosts        = $ce->{authen}{ldap_options}{net_ldap_hosts};
	my $opts         = $ce->{authen}{ldap_options}{net_ldap_options} // {};
	my $base         = $ce->{authen}{ldap_options}{net_ldap_base};
	my $searchdn     = $ce->{authen}{ldap_options}{searchDN};
	my $bindAccount  = $ce->{authen}{ldap_options}{bindAccount};
	my $bindpassword = $ce->{authen}{ldap_options}{bindPassword};
	# Be backwards-compatible with releases that hardcode this value.
	my $rdn = $ce->{authen}{ldap_options}{net_ldap_rdn} // 'sAMAccountName';

	# connect to LDAP server
	my $ldap = Net::LDAP->new($hosts, ref($opts) eq 'HASH' ? %$opts : ());
	if (!defined $ldap) {
		warn "AUTH LDAP: couldn't connect to any of ", join(", ", @$hosts), ".\n";
		return 0;
	}

	my $msg;

	if ($bindAccount) {
		# bind with a bind USER
		$msg = $ldap->bind($searchdn, password => $bindpassword);
		if ($msg->is_error) {
			warn "AUTH LDAP: bind error ", $msg->code, ": ", $msg->error_text, ".\n";
			return 0;
		}
	} else {
		# bind anonymously
		$msg = $ldap->bind;
		if ($msg->is_error) {
			warn "AUTH LDAP: bind error ", $msg->code, ": ", $msg->error_text, ".\n";
			return 0;
		}
	}

	# look up user's DN
	$msg = $ldap->search(base => $base, filter => "$rdn=$uid");
	if ($msg->is_error) {
		warn "AUTH LDAP: search error ", $msg->code, ": ", $msg->error_text, ".\n", $searchdn, "\n", $base, "\n", $uid,
			"\n";
		return 0;
	}
	if ($msg->count > 1) {
		warn "AUTH LDAP: more than one result returned when searching for UID '$uid'.\n";
		return 0;
	}
	if ($msg->count == 0) {
		$self->write_log_entry("AUTH LDAP: UID not found");
		return -1;
	}
	my $dn = $msg->shift_entry->dn;
	if (!defined $dn) {
		warn "AUTH LDAP: got null DN when looking up UID '$uid'.\n";
		return 0;
	}

	# re-bind as user. if that works, we've authenticated!
	$msg = $ldap->bind($dn, password => $password);
	if ($msg->code == LDAP_INVALID_CREDENTIALS) {
		$self->write_log_entry("AUTH LDAP: server rejected password for UID.");
		return 0;
	}
	if ($msg->is_error) {
		warn "AUTH LDAP: bind error ", $msg->code, ": ", $msg->error_text, ".\n";
		return 0;
	}

	# it worked! we win!
	return 1;
}

1;
