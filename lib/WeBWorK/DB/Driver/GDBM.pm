################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Driver/GDBM.pm,v 1.8 2004/01/23 22:04:20 gage Exp $
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

package WeBWorK::DB::Driver::GDBM;
use base qw(WeBWorK::DB::Driver);

=head1 NAME

WeBWorK::DB::Driver::GDBM - hash style interface to GDBM databases.

=cut

use strict;
use warnings;
use File::Spec;
use GDBM_File;

use constant STYLE => "hash";

use constant MAX_TIE_ATTEMPTS => 30;
use constant TIE_RETRY_DELAY  => 2;
use constant TIE_PERMISSION   => 0660;

################################################################################
# constructor - GDBM-specific settings
################################################################################

sub new($$$) {
	my ($proto, $source, $params) = @_;
	
	my $self = $proto->SUPER::new($source, $params);
	
	# hashref for tied hash
	$self->{hash} = {};
	
	return $self;
}

################################################################################
# common methods
################################################################################

sub connect($$) {
	my ($self, $mode) = @_;
	$mode = lc $mode;
	my $hash = $self->{hash};
	my $source = $self->{source};
	
	# if we're already tied, say so
	return 1 if tied %$hash;
	
	# file exists, but it's not readable
	die "GDBM file '$source' exists but is not readable.\n"
		if -e $source and not -r $source;
	
	# we're connecting read/write, file exists, but it's not writeable
	die "GDBM file '$source' exists but is not writeable.\n"
		if $mode eq "rw" and -e $source and not -w $source;
	
	# if we're trying to read and the file doesn't exist, quickly connect
	# read/write and disconnect to create it.
	if ($mode eq "ro" and not -e $source) {
		eval { $self->connectOnce("rw") };
		$@ and die "GDBM file '$source' does not exist and creation failed: $@\n";
		$self->disconnect;
	}
	
	# what flags are we going to pass to GDBM_File?
	my $flags = $mode eq "rw" ? GDBM_WRCREAT() : GDBM_READER();
	
	my $error_message;
	
	foreach (1 .. MAX_TIE_ATTEMPTS) {
		# Try connecting once, return if successful
		return 1 if eval { $self->connectOnce($mode) };
		
		# if there was an exception, store it as the error message
		$error_message = $@ if $@;
		
		# Wait before we try again
		sleep TIE_RETRY_DELAY;
	}
	
	# If we're here, it means we ran out of attempts without connecting
	# successfully. Bail! Bail!
	die "failed to connect($mode) to GDBM file '$source': $error_message";
}

sub disconnect($) {
	my $self = shift;
	return 1 unless tied %{$self->{hash}}; # not tied!
	return untie %{$self->{hash}}; 
}

################################################################################
# hash-style methods
################################################################################

# Attempt to connect once. Throw exception on failure. Assumes we are not
# already connected, $mode has already been downcased, etc.
sub connectOnce {
	my ($self, $mode) = @_;
	
	my $hash = $self->{hash};
	my $source = $self->{source};
	my $flags = $mode eq "rw" ? GDBM_WRCREAT() : GDBM_READER();
	
	return 1 if tie %$hash,
		"GDBM_File",    # class
		$source,        # file name
		$flags,         # I/O flags
		TIE_PERMISSION; # access mode
	
	# still here? bail out!
	die $!;
}

sub hash($) {
	my ($self) = @_;
	die "hash not tied"
		unless tied %{$self->{hash}};
	return $self->{hash};
}

1;
