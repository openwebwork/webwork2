################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/DB/Driver/GDBM.pm,v 1.7 2003/12/09 01:12:31 sh002i Exp $
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
	my $hash = $self->{hash};
	my $source = $self->{source};
	
	return 1 if tied %$hash; # already tied!
	if (lc $mode eq "ro" and not -e $source) {
		$self->connect("rw");
		$self->disconnect;
	}
	my $flags = lc $mode eq "rw" ? GDBM_WRCREAT() : GDBM_READER();
	my $error_message;
	foreach (1 .. MAX_TIE_ATTEMPTS) {
		return 1 if tie %$hash,
			"GDBM_File",    # class
			$source,        # file name
			$flags,         # I/O flags
			TIE_PERMISSION; # access mode
		#warn __PACKAGE__, ": tie failed with error $!, (attempt $_)\n";
		$error_message    =  ": tie failed with error $!, (attempt $_)\n";
		sleep TIE_RETRY_DELAY;
	}
	die "$source: connection failed.  $error_message";
}

sub disconnect($) {
	my $self = shift;
	return 1 unless tied %{$self->{hash}}; # not tied!
	return untie %{$self->{hash}}; 
}

################################################################################
# hash-style methods
################################################################################

sub hash($) {
	my ($self) = @_;
	die "hash not tied"
		unless tied %{$self->{hash}};
	return $self->{hash};
}

1;
