################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Schema::Null;

=head1 NAME

WeBWorK::DB::Schema::Null - a dummy schema with no backend.

=cut

use strict;
use warnings;

use constant TABLES => qw(password permission key user set set_user problem problem_user);
use constant STYLE  => "dummy";

################################################################################
# static functions
################################################################################

sub tables() {
	return TABLES;
}

sub style() {
	return STYLE;
}

################################################################################
# constructor
################################################################################

sub new($$$$$) {
	my ($proto, $db, $driver, $table, $record, $params) = @_;
	my $class = ref($proto) || $proto;
	die "$table: unsupported table"
		unless grep { $_ eq $table } $proto->tables();
	die $driver->style(), ": style mismatch"
		unless $driver->style() eq $proto->style();
	my $self = {
		db     => $db,
		driver => $driver,
		table  => $table,
		record => $record,
		params => $params,
	};
	bless $self, $class;
	return $self;
}

################################################################################
# table access functions
################################################################################

sub list   { return ();    }
sub exists { return 1;     }
sub add    { return 0;     }
sub get    { return undef; }
sub put    { return 0;     }
sub delete { return 1;     }

1;
