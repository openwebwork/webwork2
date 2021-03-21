################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2020 The WeBWorK Project, https://openwebworkorg.wordpress.com/
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

package WeBWorK::Cookie;

=head1 NAME

WeBWorK::Cookie - inherit from either Apache::Cookie or CGI::Cookie
depending on mod_perl version.

=head1 SYNOPSIS

Given C<$r>, a WeBWorK::Request object

 my $cookie = new WeBWorK::Cookie

=cut

use strict;
use warnings;


use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

# This class inherits from Apache::Cookie under mod_perl and CGI::Cookie under mod_perl2
BEGIN {
	if (MP2) {
		require CGI::Cookie;
		CGI::Cookie->import;
		push @WeBWorK::Cookie::ISA, "CGI::Cookie";
	} else {
		require Apache::Cookie;
		Apache::Cookie->import;
		push @WeBWorK::Cookie::ISA, "Apache::Cookie";
	}
}

1;
