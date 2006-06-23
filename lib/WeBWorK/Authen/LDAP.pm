################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Authen/Moodle.pm,v 1.5 2006/06/08 23:27:02 sh002i Exp $
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

## Make sure we have the Net::LDAPS module
use Net::LDAPS qw(:all);

use strict;
use warnings;
use WeBWorK::Debug;


## Set up some constants for LDAP
my $TIMEOUT = '30';
my $PORT = '636';
my $VERSION = '3';
my $BASE = "ou=people,dc=rochester,dc=edu";
my @HOST = [ 'corona-dmc.its.rochester.edu', 'corona-dmb.acs.rochester.edu' ];



# these are the only function that needs to be overridden


sub checkPassword {
	my ($self, $userID, $possibleClearPassword) = @_;
	my $db = $self->{r}->db;
	
	debug("LDAP module is doing the password checking.\n");
	
    # FIXME -- we still need to insure that 
    #  the user is in the course
	# check against LDAP password database
    return 1 if $self->authn($userID, $possibleClearPassword);
    warn "Couldn't authenticate using LDAP";
    
    return 1 if $self->SUPER::checkPassword($userID, $possibleClearPassword);
	
	# check site-specific verification method
	# FIXME do we really want to call this here?
	return 1 if $self->site_checkPassword($userID, $possibleClearPassword);
	
	# fail by default
	return 0;
}




#########################################
sub authn( $$$ ) {
	my $self = shift;  #(not currently used)
    ## Input:  Username and password
    ## Output: Returns 1 if the combination is valid, 0 otherwise


    ## Get the username and password from the calling program
    my $netid = shift;
    my $pass = shift;

    return 0 if (! ($netid && $pass) );

    ## Open the connection
    my $ldap = Net::LDAPS->new(
                                @HOST,
                                timeout => $TIMEOUT,
			        port    => $PORT,
			        version => $VERSION 
                              ) or return 0;


    ## Bind anonymously and get the user's DN
    $ldap->bind;
    my $mesg = $ldap->search( 
                              base     => $BASE,
			      filter   => "uid=$netid" 
                            );

    ## Give up if there is an error
    $mesg->code && return 0;

    ## Give up if there is less or more than one matching entry; 
    ## something is wrong!
    return 0 if ($mesg->count != 1);

    my $entry = $mesg->shift_entry;
    my $dn = $entry->dn;

    if ($dn) {
	## Bind as the user, return 1 if successful
	if ($ldap->bind( $dn, password => $pass)->code == 0) {
	    $ldap->unbind;
	    return 1;
	} 
    }

    $ldap->unbind;
    return 0;

}

## Perldoc info
=head1 NAME

WeBWorK::Authen::LDAP - LDAP-related functions for webwork

=head1 SYNOPSIS

 use ITS::LDAP;

 $valid = LDAP::authn( $netid, $password);
 if ($valid) {
     ## Password is valid
 } else {
     ## Password is invalid
 }

=head1 DESCRIPTION

This code is adapted from ITS::LDAP::authn which was written by Christina Plummer.
-- Mike Gage (gage@math.rochester.edu)

check_password(userID, password) returns 1 or 0 depending on whether 
the userID/password pair is authenticated by the LDAP database.  It also
checks to insure that the userID exists in the course.



authen() is a simple function used to authenticate a user 
against the ITS-supported LDAP servers using LDAPS (LDAP over SSL).  
It requires two parameters, NetID and password.  It will return 1 if the
NetID/password combination is valid, and 0 if it is invalid.

At this time (March 2005), it does no certificate checking to validate that 
DNS has not been hijacked.  It does include support for failover; i.e. it
will query the secondary LDAP server if the primary is unavailable.

=head1 NOTES

Install this module into site_perl/ITS/LDAP.pm.

The authn function is intended to be called one time, not multiple
times within a single script.  It will make a new connection to the LDAP 
server every time the function is called.

The function will also fail (return 0) for reasons other than a bad 
password, such as multiple DNs in LDAP matching the given NetID (uid), or 
being unable to contact the LDAP server.

=head1 AUTHOR

Christina Plummer <christina.plummer@rochester.edu>

=cut

## Package itself needs a return value
1;
