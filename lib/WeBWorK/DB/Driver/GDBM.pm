################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Driver::GDBM;

=head1 NAME

WeBWorK::DB::Driver::GDBM - hash style interface to GDBM databases.

=cut

use strict;
use warnings;
use GDBM_File;

use constant STYLE => "hash";

# GDBM settings
use constant MAX_TIE_ATTEMPTS => 30;
use constant TIE_RETRY_DELAY  => 2;
use constant TIE_PERMISSION => 0660;

################################################################################
# static function
################################################################################

sub style() {
	return STYLE;
}

################################################################################
# constructor
################################################################################

sub new($$) {
	my ($proto, $source) = @_;
	my $class = ref($proto) || $proto;
	my $self = {
		hash   => {},
		source => $source,
	};
	bless $self, $class;
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
	my $flags = lc $mode eq "rw" ? GDBM_WRCREAT() : GDBM_READER();
	return 0 if lc $mode eq "ro" and not -e $self->{source};
	foreach (1 .. MAX_TIE_ATTEMPTS) {
		return 1 if tie %$hash,
			"GDBM_File",    # class
			$source,        # file name
			$flags,         # I/O flags
			TIE_PERMISSION; # access mode
		sleep TIE_RETRY_DELAY;
	}
	return 0;
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
	return 0 unless tied %{$self->{hash}}; # not tied!
	return $self->{hash};
}

1;
