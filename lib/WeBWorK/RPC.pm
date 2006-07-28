################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authen.pm,v 1.57 2006/07/15 14:07:31 sh002i Exp $
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

package WeBWorK::RPC;

=head1 NAME

WeBWorK::RPC - Remote Procedure Calls for WeBWorK.

=cut

use strict;
use warnings;

use Data::Dumper;
use WeBWorK::Authen;
use WeBWorK::Authz;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::RPC::Request;
use WeBWorK::Utils qw/runtime_use/;

sub bootstrap {
	my ($invocant, %params) = @_;
	my $class = ref $invocant || $invocant;
	my $self = bless {}, $class;
	
	my $r = $self->{r} = new WeBWorK::RPC::Request;
	
	my $ce = eval { new WeBWorK::CourseEnvironment(\%WeBWorK::SeedCE) };
	$@ and die "Failed to initialize course environment: $@\n";
	$r->ce($ce);
	
	my $authz = new WeBWorK::Authz($r);
	$r->authz($authz);
	
	my $authen_module = WeBWorK::Authen::class($ce, "user_module");
	runtime_use $authen_module;
	my $authen = $authen_module->new($r);
	$r->authen($authen);
	
	if (defined $ce->{courseName} and $ce->{courseName} ne "") {
		my $db = new WeBWorK::DB($ce->{dbLayout});
		$r->db($db);
	}
	
	return $self, %params;
}

sub hi {
	print STDERR __PACKAGE__."::hi(@_) called\n";
	return "hello, world";
}

sub bye {
	print STDERR __PACKAGE__."::bye(@_) called\n";
	return "goodbye, cruel world";
}

sub dumper {
	print STDERR __PACKAGE__."::dumper(@_) called\n";
	return Dumper(\@_);
}

sub get_course_environment {
	my ($self, %params) = bootstrap(@_);
	return $self->{r}->ce;
}

1;
