################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Driver::SQL;
use base qw(WeBWorK::DB::Driver);

=head1 NAME

WeBWorK::DB::Driver::SQL - SQL style interface to SQL databases.

=cut

use strict;
use warnings;
use DBI;

use constant STYLE => "dbi";

################################################################################
# constructor
################################################################################

sub new($$$) {
	my ($proto, $source, $params) = @_;
	
	my $handleRO = DBI->connect_cached($source, $params->{usernameRO}, $params->{passwordRO});
	return 0 unless defined $handleRO;
	
	my $handleRW = DBI->connect_cached($source, $params->{usernameRW}, $params->{passwordRW});
	return 0 unless defined $handleRW;
	
	my $self = $proto->SUPER::new($source, $params);
	
	# add DBI-specific data
	$self->{handle}   = undef;
	$self->{handleRO} = $handleRO;
	$self->{handleRW} = $handleRW;
	
	return $self;
}

################################################################################
# common methods
################################################################################

sub connect($$) {
	my ($self, $mode) = @_;
	
	if ($mode eq "ro") {
		$self->{handle} = $self->{handleRO};
	} else {
		$self->{handle} = $self->{handleRW};
	}
	
	return 1;
}

sub disconnect($) {
	my $self = shift;
	
	undef $self->{handle};
	
	return 1;
}

################################################################################
# dbi-style methods
################################################################################

sub dbi($) {
	my ($self) = @_;
	return $self->{handle};
}

1;
