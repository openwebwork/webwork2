################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Driver/SQL.pm,v 1.15 2007/07/19 21:02:42 sh002i Exp $
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

package WeBWorK::DB::Driver::SQL;
use base qw(WeBWorK::DB::Driver);

=head1 NAME

WeBWorK::DB::Driver::SQL - SQL style interface to SQL databases.

=cut

use strict;
use warnings;
use DBI;

use constant STYLE => "dbi";

=head1 SOURCE FORMAT

The C<source> entry for tables handled by this driver should consist of a DBI
data source.

=head1 SUPPORTED PARAMS

This driver pays attention to the following items in the C<params> entry.

=over

=item username

Username for access to SQL database.

=item password

Password for access to SQL database.

=back

=cut

################################################################################
# constructor
################################################################################

sub new($$$) {
	my ($proto, $source, $params) = @_;
	
	my $self = $proto->SUPER::new($source, $params);
	
	# add handle
	$self->{handle} = DBI->connect_cached(
		$source,
		$params->{username},
		$params->{password},
		{
			PrintError => 0,
			RaiseError => 1,

			mysql_enable_utf8mb4 => 1,
			mysql_enable_utf8 => 1,  # for older versions of DBD-mysql Perl modules
		},
	);
	die $DBI::errstr unless defined $self->{handle};
	
	# set trace level from debug param
	#$self->{handle}->trace($params->{debug}) if $params->{debug};
	
	return $self;
}

################################################################################
# common methods
################################################################################

# deprecated, no-op
sub connect {
	return 1;
}

# deprecated, no-op
sub disconnect {
	return 1;
}

################################################################################
# dbi-style methods
################################################################################

sub dbi {
	my ($self) = @_;
	return $self->{handle};
}

1;

