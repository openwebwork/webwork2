################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Driver::SQL;

=head1 NAME

WeBWorK::DB::Driver::SQ - SQL style interface to SQL databases.

=cut

use strict;
use warnings;
use DBI;

use constant STYLE => "sql";

################################################################################
# static functions
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
		handle => undef,
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
	my $handle = $self->{handle};
	my $source = $self->{source};
	
	return 1 if defined $handle;
	$handle = DBI->new($source);
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
