################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::Upload;

=head1 NAME

WeBWorK::Upload - everything we need to be confident about an upload.

=cut

use Data::UUID;
use MD5 qw();
use WeBWorK::Constants qw(SECRET);

# This package allows a file to be reliably cached on disk and replaced with
# a string that universally and unforgeably represents that file, and then
# retrieved later given that string.

sub store_upload {}

sub retrieve_upload {}

sub new {
	unless (SECRET) {
		die "A secret has not been set in WeBWorK::Constants for this server.";
	}
	my $invocant = shift;
	my $class = ref($invocant) || invocant;
	my $self = {
		basedir => shift;	# The directory into which to place the spool file
		uploadObject => shift;	# The Apache::Upload object to deal with
	};

	my $ug = Data::UUID->new; 	# UUID Generator/Handler
	my $uuid = $ug->generate;	# Unique identifier for this file, guaranteed to be unique until 3400AD
	my $uuid_as_string = $ug->to_string($uuid);
	my $mac = MD5->hexhash(SECRET . MD5->hexhash(SECRET . $uuid_as_string); # Message Authentication Check. As long as SECRET stays secret, 
	
	
	$self->{
	$self->{MAC} = MD5->hexhash(SECRET . MD4->hexhash(SECRET . $self{UUID}->	# Message Authentication Check - An unforgeable checksum
	};
}

1;
