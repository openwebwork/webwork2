################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authen/LDAP.pm,v 1.1 2006/06/23 18:42:31 gage Exp $
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
use WeBWorK::Debug;
use Net::LDAP qw/LDAP_INVALID_CREDENTIALS/;

sub checkPassword {
	my ($self, $userID, $possibleClearPassword) = @_;
	my $ce = $self->{r}->ce;
	my $failover = $ce->{authen}{ldap_options}{failover};
	
	debug("LDAP module is doing the password checking.\n");
	
	# check against LDAP server
	return 1 if $self->ldap_authen_uid($userID, $possibleClearPassword);
	
	# optional: fail over to superclass checkPassword
	if ($failover) {
		$self->write_log_entry("LDAP: authentication failed, deferring to superclass");
		return $self->SUPER::checkPassword($userID, $possibleClearPassword);
	}
	
	# fail by default
	return 0;
}

sub ldap_authen_uid {
	my ($self, $uid, $password) = @_;
	my $ce = $self->{r}->ce;
	my $hosts = $ce->{authen}{ldap_options}{net_ldap_hosts};
	my $opts = $ce->{authen}{ldap_options}{net_ldap_opts};
	my $base = $ce->{authen}{ldap_options}{net_ldap_base};
	
	# connect to LDAP server
	my $ldap = new Net::LDAP($hosts, @$opts);
	if (not defined $ldap) {
		warn "LDAP: couldn't connect to any of ", join(", ", @$hosts), ".\n";
		return 0;
	}
	
	my $msg;
	
	# bind anonymously
	$msg = $ldap->bind;
	if ($msg->is_error) {
		warn "LDAP: bind error ", $msg->code, ": ", $msg->error_text, ".\n";
		return 0;
	}
	
	# look up user's DN
	$msg = $ldap->search(base => $base, filter => "uid=$uid");
	if ($msg->is_error) {
		warn "LDAP: search error ", $msg->code, ": ", $msg->error_text, ".\n";
		return 0;
	}
	if ($msg->count > 1) {
		warn "LDAP: more than one result returned when searching for UID '$uid'.\n";
		return 0;
	}
	if ($msg->count == 0) {
		$self->write_log_entry("LDAP: UID '$uid' not found");
		return 0;
	}
	my $dn = $msg->shift_entry->dn;
	if (not defined $dn) {
		warn "LDAP: got null DN when looking up UID '$uid'.\n";
		return 0;
	}
	
	# re-bind as user. if that works, we've authenticated!
	$msg = $ldap->bind($dn, password => $password);
	if ($msg->code == LDAP_INVALID_CREDENTIALS) {
		$self->write_log_entry("LDAP: server rejected password for UID '$uid'.");
		return 0;
	}
	if ($msg->is_error) {
		warn "LDAP: bind error ", $msg->code, ": ", $msg->error_text, ".\n";
		return 0;
	}
	
	# it worked! we win!
	return 1;
}

1;
