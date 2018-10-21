################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/CGI.pm,v 1.27 2006/09/15 22:02:37 sh002i Exp $
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

package WeBWorK::CGI;

use strict;
use warnings;

# from http://search.cpan.org/src/LDS/CGI.pm-3.20/cgi_docs.html#subclassing
use vars qw/@ISA $VERSION/;
require CGI;
@ISA = 'CGI';
$VERSION = "0.1";

$CGI::DefaultClass = __PACKAGE__;
$WeBWorK::CGI::AutoloadClass = 'CGI';

sub new {
	my $self = shift->SUPER::new(@_);
	$self->delete_all;
	return $self;
}

1;
