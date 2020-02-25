################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authen/Proctor.pm,v 1.5 2007/04/04 15:05:27 glarose Exp $
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

package WeBWorK::Authen::XMLRPC;
use base "WeBWorK::Authen";

=head1 NAME

WeBWorK::Authen::XMLRPC - Authenticate xmlrpc requests.

=cut

use strict;
use warnings;
use WeBWorK::Debug;
use Digest::SHA qw(sha256_hex);
use Encode qw(encode);

# Instead of being called with an apache request object $r 
# this authentication method gets its data  
# from an HTML data form.  It creates a WeBWorK::Authen::XMLRPC object  
# which fakes the essential properties of the WeBWorK::Request object needed for authentication


# sub new {
# 	my $class = shift;    
# 	my $fake_r = shift;
# 	my $user_authen_module = WeBWorK::Authen::class($ce, "user_module");
#     # runtime_use $user_authen_module;
#     $GENERIC_ERROR_MESSAGE = $fake_r->maketext("Invalid user ID or password.");
# 	my $authen = $user_authen_module->new($fake_r);
# 	return $authen;
# }

# ==========================================================================

# This code was inspired by approach used in lib/WeBWorK/Authen/Proctor.pm.
# Rewrite the userID to have the structure
#    userID,sessionDataHash,x
# where sessionDataHash is the 64 hex character output from applying
# Digest::SHAsha256_hex() to a string with all the "protected" session
# settings.
# The third field ",x" is required as used by lib/WeBWorK/DB.pm to
# recognize this usage of a special string, and differentiate it from
# the format used by lib/WeBWorK/Authen/Proctor.pm.

# sessionDataHash key ID rewriter
sub sessionDataHash_key_id {
	my $r = shift;

	my $sd_key_id = join( ",", ( $r->{user_id},
		$r->{sessionDataHash}, "x" ) );

        return $sd_key_id;
}

sub getIDtoUse {
	my $self = shift;
	my $id_to_use = shift;
	my $r = shift;
	if ( defined( $r->{use_sessionDataHash} ) &&
	     ( $r->{use_sessionDataHash} == 1 ) &&
	     defined( $r->{user_id} ) &&
	     defined( $r->{sessionDataHash} ) &&
	     ( $r->{sessionDataHash} =~ /^[0-9a-f]{64}$/ )
	   ) {
		$id_to_use = sessionDataHash_key_id( $r );
	}
	debug("getIDtoUse setting result to $id_to_use");
	return $id_to_use;
}

# create_session and check_session use
#     sessionDataHash_key_id()
# to set the first parameter IF use_sessionDataHash is 1
# and all the data seems available

sub create_session {
	my ($self, $userID, $newKey) = @_;
	my $r = $self->{r};
	my $id_to_use = $self->getIDtoUse( $userID, $self->{r} );
	debug("called create_session for $userID ($id_to_use)");
	return $self->SUPER::create_session( $id_to_use, $newKey );
}

# rewrite the userID to include bith the proctor's and the student's user ID
# and then call the default check_session method.
sub check_session {
	my ($self, $userID, $possibleKey1, $updateTimestamp) = @_;
	my $r = $self->{r};

	# Note $possibleKey1 which arrives here seems to be the session_key
	# from the front end connection, we prefer to try to use the
	# session_key sent in the form submission.
	my $possibleKey2 = $r->{session_key} // "no second session key";

	my $currTime = time; # used as current "time" for this entire call instead of calling time again and again

	my $id_to_use = $self->getIDtoUse( $userID, $r );

	debug("Starting checksession for userID = $userID, possibleKey1 = $possibleKey1, possibleKey2 = $possibleKey2, and id_to_use = $id_to_use");

	# ====================================================================================

	if ( $id_to_use eq $userID ) {
		# We want the regular behavior in this case
		debug("called check_session for $possibleKey1 and need regular behavior. ($id_to_use)");
		return $self->SUPER::check_session($id_to_use, $possibleKey1, $updateTimestamp);
	}

	# ====================================================================================

	# On the initial login we probably have a session for the "plain" user_id.
	my $ce = $r->ce;
	my $db = $r->db;

	my $skto = $ce->{sessionKeyTimeout};
	my $sktoMin = $skto / 60;
	debug("sessionKeyTimeout for this course is $sktoMin minutes ($skto seconds)");

	my $had_Valid_internal_WW2_secret = $r->{had_Valid_internal_WW2_secret} // 0;

	my $Key1 = $db->getKey( $userID    );
	my $Key2 = $db->getKey( $id_to_use );
	my $Key3; # for internal use and to be the one we will eventually save

	my $key_string = "";
	my $make_new_key_string = 0;
	my $needToSearchForAltKeys = 0;

	if ( defined( $Key2 ) ) {
		# If Key2 is defined, then there was an authenticated "session"
		# for THIS data, but it may have a different session_key and
		# it might have expired.

		my $keyMatches = (defined $possibleKey2 and $possibleKey2 eq $Key2->key);
		my $timestampValid = ( $currTime <= ( $Key2->timestamp() + $ce->{sessionKeyTimeout} ) );

		$keyMatches = 0 if ( ! $keyMatches );         # Make it visible in the logs as "0:
		$timestampValid = 0 if ( ! $timestampValid ); #   same

		debug("extended session_key exists: keyMatches = $keyMatches timestampValid = $timestampValid ($id_to_use)");

		if ( $timestampValid ) {
			# Valid, so keep it, and if necessary replace the session_key parameters to use it
			my $tmpKey = $Key2->key;
			$self->{session_key} = $Key2->key;
			if ( ! $keyMatches ) {
				# We received a different session_id for the same userID+sessionDataHash
				# data, so adopt this one. In principle this allows session hijacking
				# if the connection authenticated and got passed on to WebworkWebService.pm.
				# This would only allow someone who guesses that a given other user has an open
				# session for this particular "problem" = sessionDataHash, in which case the
				# hijacker could then impersonate the target. Given that XMLRPC does not limit
				# the number of attempts, and that scores would be passed back to the credit of
				# the target in the originating LMS - we are not considering this a terribly
				# damaging problem.
				debug("For $id_to_use replace no-longer existent key $possibleKey2 with current key2 $tmpKey");
			} else {
				debug("key2 $tmpKey for ${id_to_use} matches and still valid");
			}
			if ( $updateTimestamp ) {
				debug("updating key timestamp on $tmpKey for $id_to_use");
				$Key2->timestamp( $currTime );
				eval { $db->putKey( $Key2 ) };
				if ( $@ ) {
					my $tmp1 = $@;
					debug("Couldn't put timestamp updated key2 $tmpKey for userID+sessionDataHash for ${id_to_use}: $tmp1");
					return (1, 1,  $timestampValid);
				} else {
					return (1, 1, 1);
				}
			} else {
				return (1, 1, $timestampValid);
			}
		} else {
			# No longer valid, so the session has timed-out
			my $tmpKey = $Key2->key;
			debug("Session $tmpKey for $id_to_use has timed-out, key is being deleted");
			$self->{session_key} = "";
			eval { $db->deleteKeyForSession( $id_to_use,$Key2->key) }; # delete the old key
			if ( $@ ) {
				debug("Error deleting $tmpKey for ${id_to_use}: $@ ");
			}

			# Are we starting a new session or is there a parallel recent session ?
			if ( $had_Valid_internal_WW2_secret ) {
				# If WebworkWebserver.pm received the valid internal_WW2_secret we accept that as a valid authentication
				$make_new_key_string = 1;
			} else {
				# Since there was a key in the database for this sessionDataHash,
				# we assume that the data was NOT tampered with, so we are willing to
				# authenticate the user is there is a recent key for the user.
				$needToSearchForAltKeys = 1;
			}
		}
		# End of handling of case where there is a Key2 (which depends on the sessionDataHash).
	} else {
		# Key2 does NOT exist, so there is no authenticated session on the "back-end"
		# html2xml / WebworkWebservice side. In this case we ideally want authentication
		# to depend on a valid Key1, but since many LMS calls can arrive in a short period
		# of time, Key1 may not have the $possibleKey1 anymore.

		# Since there is NO Key2, we have not authenticated the sessionDataHash to prevent
		# tampering with the critical parameters. As such - we should NOT allow
		# authentication to occur based on a parallel session key UNLESS this is
		# the ORIGINAL request after the LTI authentication.

		# See what we can do with a Key1 if we got one
		if (  defined( $Key1 ) ) {
			# This may or may not be the key from the original LTI authentication
			# depending on the speed/order of LTI requests

			my $timestampValid = ( $currTime <= ( $Key1->timestamp() + $ce->{sessionKeyTimeout} ) );
			$timestampValid = 0 if ( ! $timestampValid ); # Make it visible in the logs as "0:

			if ( ! $timestampValid ) {
				debug("Saw expired key for plain user $userID ... ($id_to_use)");
				# Make sure to only delete THIS specific key
				eval { $db->deleteKeyForSession($userID,$Key1->key) }; # delete the key
				my $tmpKey = $Key1->key;
				if ( $@ ) {
					debug("Error deleting expired $tmpKey for ${userID}: $@ ");
				}
				if ( $had_Valid_internal_WW2_secret ) {
					# since this is an ORIGINAL LTI connection we will accept
					# the sessionDataHash data and authenticate if we can find
					# ANY recent parallel key.
					debug("   since this was an original LTI connection - we will try to authenticate using a recent parallel key. ($id_to_use)");
					$needToSearchForAltKeys = 1;
				} else {
					# but if it is NOT an original LTI connection - we declare an authentication failure.
					debug("   since this was NOT an original LTI connection - we cannot authenticate using a recent parallel key as that would permit tampering with the critical data. ($id_to_use)");
					$needToSearchForAltKeys = 0;
					$self->{session_key} = "";
					return 0; # so we declare an authentication failure
				}
			} else {
				# Key1 is still valid
				my $tmpKey = $Key1->key;
				if (   defined( $possibleKey1 )       &&
					 ( $possibleKey1 eq $Key1->key )     ) {
					# We have a matching key (should be from the initial LTI authentication)
					# and need to replace it with one for the id+sessionDataHash instead
					# but can reuse the session_key string
					debug("Found a current key for the plain user $userID with $possibleKey1 and will try to use that session_key and delete the plain id version. ($id_to_use)");
					# Make sure to only delete THIS specific key
					$key_string = $possibleKey1;
					eval { $db->deleteKeyForSession($userID,$Key1->key) }; # delete the key
					if ( $@ ) {
						debug("Error deleting prior $tmpKey for ${userID}: $@ ($id_to_use)");
					}
				} else {
					# The key proves succesful authentication on the front-end
					# leave it alone for the session it is part of.
					debug("Found a current key for the plain user with a different key1 $tmpKey. We can only allow authentication if this is an initial LTI connection, otherwise data tampering would be possible. ($id_to_use)");

					if ( $had_Valid_internal_WW2_secret ) {
						# If WebworkWebserver.pm received the valid internal_WW2_secret we accept that as a
						# valid authentication for the critical session data passed in.
						$make_new_key_string = 1;
						debug("   since this was an original LTI connection - we authenticate but need to create a new session_key. ($id_to_use)");
					} else {
						# We did NOT find any key for this sessionDataHash in the database,
						# so we have NO reason to assume the data was NOT tampered with, so we
						# CANNOT authenticate this connection.
						$needToSearchForAltKeys = 0;
						debug("   since this was NOT an original LTI connection - we cannot authenticate using a recent parallel key as that would permit tampering with the critical data. ($id_to_use)");
						$self->{session_key} = "";
						return 0; # so we declare an authentication failure
					}
				}
			}
		} else {
			# We did not find any "plain" key (Key1) for the user or one for this sessionData (Key2)
			$self->{session_key} = "";
			if ( $had_Valid_internal_WW2_secret ) {
				# If WebworkWebserver.pm received the valid internal_WW2_secret we accept that as a valid authentication
				debug("We did not find any valid session key but since this was an original LTI connection - we authenticate and must create a new session_key. ($id_to_use)");
				$make_new_key_string = 1;
			} else {
				# We did NOT find any key for this sessionDataHash in the database,
				# and this is NOT an original LTI connection,
				# so we have NO reason to assume the data was NOT tampered with,
				# and thus we CANNOT authenticate this connection.
				$needToSearchForAltKeys = 0;
				debug("We did not find a key to use to authenticate and since this was NOT an original LTI connection - we cannot authenticate using a recent parallel key as that would permit tampering with the critical data. ($id_to_use)");
				return 0; # so we declare an authentication failure
			}
		}
		# End handling case where there is no Key2
	}


	# If we need to search for other recent keys
	if ( $needToSearchForAltKeys ) {
		# Get all keys for this user.
		my @allUserKeys = $db->getKeysExtended( $userID );
		my $mostRecentTimeStamp = -1;
		my $mostRecentSessionKey = "";
		foreach $Key3 ( @allUserKeys ) {
			if ( ( $currTime <= ( $Key3->timestamp() + $ce->{sessionKeyTimeout} ) ) &&
				   ( $Key3->timestamp() > $mostRecentTimeStamp ) ) {
				$mostRecentTimeStamp  = $Key3->timestamp();
				$mostRecentSessionKey = $Key3->key;
			}
		}
		# Did we find a sufficiently recent one?
		if (    ( $mostRecentTimeStamp > -1 )
			 && ( $currTime <= ( $mostRecentTimeStamp + 30 ) ) ) {
			# is recent enough to accept (at most 30 seconds old)
			debug("Found a recent key for the user $userID with a different key $mostRecentSessionKey and timestamp $mostRecentTimeStamp. Accepting authentication. ($id_to_use)");
			$make_new_key_string = 1;
		} else {
			debug("Did not find any sufficiently recent key for the user $userID - rejecing authentication. ($id_to_use)");
			$make_new_key_string = 0;
			$self->{session_key} = "";
			return 0; # so we declare an authentication failure
		}
	}

	if ( $make_new_key_string ) {
		my @chars = @{ $ce->{sessionKeyChars} };
		my $length = $ce->{sessionKeyLength};
		srand;
		$key_string = join ("", @chars[map rand(@chars), 1 .. $length]);
		debug("Creating a new key for userID+sessionDataHash $id_to_use with session_id $key_string");
	}

	if ( $key_string ne "" ) {
		# We found or created a key_string to use
		$Key3 = $db->newKey(user_id=>$id_to_use, key=>$key_string, timestamp=>$currTime);

		# DBFIXME this should be a REPLACE
		eval { $db->deleteKeyForSession( $id_to_use,$key_string) }; # delete if it already exists
		eval { $db->addKey( $Key3 ) };
		if ( $@ ) {
			my $msg = $@;
			debug("addKey failed on the new key with $key_string for userID+sessionDataHash $id_to_use: $msg ");
			eval { $db->putKey( $Key3 ) };
			if ( $@ ) {
				$msg = $@;
				debug("putKey failed on the new key with $key_string for userID+sessionDataHash $id_to_use: $msg");
				debug("FAILED to create the session");
				$self->{session_key} = "";
				return 0;
			} else {
				# putKey succeeded
				debug("putKey succeeded on the new key with $key_string for userID+sessionDataHash $id_to_use.");
				$self->{session_key} = $key_string;
				return (1, 1, 1);
			}
		} else {
			# addKey succeeded
			debug("addKey succeeded on the new key with $key_string for userID+sessionDataHash $id_to_use.");
			$self->{session_key} = $key_string;
			return (1, 1, 1);
		}
	}

	debug("Reached end of check_session with no valid authentication or session_key. ($id_to_use)");
	$self->{session_key} = "";
	return 0; # If we got here nothing worked
}

# ==========================================================================


# disable cookie functionality for xmlrpc
sub connection {
	return 0;  #indicate that there is no connection
}
sub maybe_send_cookie {}
sub fetchCookie {}
sub sendCookie {}
sub killCookie {}



1;
