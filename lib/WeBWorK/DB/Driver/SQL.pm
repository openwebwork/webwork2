################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Driver/SQL.pm,v 1.7 2004/08/10 23:55:29 sh002i Exp $
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

=item usernameRO, passwordRO

Username and password for read-only access to SQL database.

=item usernameRW, passwordRW

Username and password for read-write access to SQL database.

=back

=cut

################################################################################
# constructor
################################################################################

sub new($$$) {
	my ($proto, $source, $params) = @_;
	
	my $handleRO = DBI->connect_cached($source, $params->{usernameRO}, $params->{passwordRO});
	die $DBI::errstr unless defined $handleRO;
	$handleRO->{RaiseError} = 1;
	
	my $handleRW = DBI->connect_cached($source, $params->{usernameRW}, $params->{passwordRW});
	die $DBI::errstr unless defined $handleRW;
	$handleRW->{RaiseError} = 1;
	
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
