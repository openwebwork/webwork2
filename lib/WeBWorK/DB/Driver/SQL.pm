################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Driver::SQL;

=head1 NAME

WeBWorK::DB::Driver::SQL - SQL style interface to SQL databases.

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

sub new($$$) {
	my ($proto, $source, $params) = @_;
	my $class = ref($proto) || $proto;
	
	my $handleRO = DBI->connect_cached($source, $params->{usernameRO}, $params->{passwordRO});
	return 0 unless defined $handleRO;
	
	my $handleRW = DBI->connect_cached($source, $params->{usernameRW}, $params->{passwordRW});
	return 0 unless defined $handleRW;
	
	my $self = {
		handle   => undef,
		handleRO => $handleRO,
		handleRW => $handleRW,
		source   => $source,
		params   => $params,
	};
	bless $self, $class;
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
# sql-style methods
################################################################################

sub handle($) {
	my ($self) = @_;
	return $self->{handle};
}

1;
