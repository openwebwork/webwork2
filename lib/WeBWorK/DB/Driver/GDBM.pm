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
use Carp;

use constant STYLE => "hash";

# GDBM settings
use constant MAX_TIE_ATTEMPTS => 30;
use constant TIE_RETRY_DELAY  => 2;
use constant TIE_PERMISSION => 0660;

################################################################################
# static functions
################################################################################

sub style() {
	return STYLE;
}

################################################################################
# constructor
################################################################################

sub new($$$) {
	my ($proto, $source, $params) = @_;
	my $class = ref($proto) || $proto;
	my $self = {
		hash   => {},
		source => $source,
		params => $params,
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
	die "$source: must exist to open for reading"
		if lc $mode eq "ro" and not -e $source;
	my $flags = lc $mode eq "rw" ? GDBM_WRCREAT() : GDBM_READER();
	foreach (1 .. MAX_TIE_ATTEMPTS) {
		return 1 if tie %$hash,
			"GDBM_File",    # class
			$source,        # file name
			$flags,         # I/O flags
			TIE_PERMISSION; # access mode
		sleep TIE_RETRY_DELAY;
	}
	die "$source: connection failed";
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
	croak "hash not tied"
		unless tied %{$self->{hash}};
	return $self->{hash};
}

1;
