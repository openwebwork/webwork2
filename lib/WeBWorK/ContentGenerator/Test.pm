################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader$
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

package WeBWorK::ContentGenerator::Test;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Test - display debugging information.

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Form;
use WeBWorK::Utils qw(ref2string);

sub initialize {
	my $self = shift;
}

sub path {
	my $self = shift;
	my $args = $_[-1];
	return $self->pathMacro($args, Home => "../", Test => "");
}

sub siblings {
	my $self = shift;
	return $self->siblingsMacro(Test2 => "blah/", "Test Three" => "spoo");
}

sub nav {
	my $self = shift;
	my $args = $_[-1];
	return $self->navMacro($args, "", TestMinus1 => "-1/", TestPlusOne => "+1/");
}

sub title {
	return "Welcome to Hell";
}

sub body {
	my $self = shift;
	my $formFields = WeBWorK::Form->new_from_paramable($self->{r});
	my $courseEnvironment = $self->{ce};
	return
		CGI::h2("URL Authentication Arguments"), CGI::p($self->url_authen_args()),
		CGI::h2("Form Fields"), ref2string($formFields),
		CGI::h2("Course Environment"), ref2string($courseEnvironment),
}

1;
