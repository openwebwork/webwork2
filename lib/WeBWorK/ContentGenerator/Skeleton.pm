################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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

# SKEL: Welcome to the ContentGenerator skeleton!
#
# This module is designed to help you in creating subclasses of
# WeBWorK::ContentGenerator. Follow the instructions marked "SKEL" below to
# create your very own module.
#
# When you've finished, I recommend you do some cleanup. These modules are much
# easier to maintain if they doesn't contain "vestigal" garbage code. Remove the
# "SKEL" comments and anything else that that you're not using in your module.

# SKEL: Declare the name and superclass of your module here:
package WeBWorK::ContentGenerator::Skeleton;
use parent qw(WeBWorK::ContentGenerator);

# SKEL: change the name of the module below and provide a short description. Add
# additional POD documentation as you see fit.

=head1 NAME

WeBWorK::ContentGenerator::Skeleton - Template for creating subclasses of
WeBWorK::ContentGenerator.  Note that in addition to creating your module
from this template, you must create a Mojolicious template that generates
the main body of the page.

=cut

use strict;
use warnings;

# SKEL: Add "use" lines for libraries you will be using here. Note that you only
# need to add a "use" line here if you will be instantiating now objects or
# calling free functions. If you have an existing instance (like $self->r) you
# can use it without a corresponding "use" line. Sample lines are given below:
#
# You might need some utility functions:
#use WeBWorK::Utils qw(function1 function2);

# SKEL: If you need to do any processing before the HTTP header is sent, do it
# in this method:
#
#sub pre_header_initialize {
#	my ($self) = @_;
#
#	# Do your processing here! Don't print or return anything -- store data in
#	# the self hash for later retrieveal.
#}

# SKEL: This method is not actually of any use anymore.
#
#sub header {
#	my ($self) = @_;
#
#	# The return value of this method is not used.
#	# The practice is to return the status code of the response.
#	return 0;
#}

# SKEL: If you need to do any processing after the HTTP header is sent, but before
# any template processing occurs, or you need to calculate values that will be
# used in multiple methods, do it in this method:
#
#sub initialize {
#	my ($self) = @_;
#
#	# Do your processing here! Don't print or return anything -- store data in
#	# the self hash for later retrieveal.
#}

# Note that all of the template methods below except head should ensure that the
# return value is a Mojo::ByteStream object if the return value contains HTML.

# SKEL: If you need to add tags to the document <HEAD>, uncomment this method:
#
#sub head {
#	my ($self) = @_;
#
#	my $output = '';
#	# You can append head tags to $output, like <META>, <SCRIPT>, etc.
#
#	return $output;
#}

# SKEL: To fill in the "info" box (to the right of the main body), use this
# method:
#
#sub info {
#	my ($self) = @_;
#
#	my $output = '';
#	# Append HTML to $output.
#
#	return $output;
#}

# SKEL: To provide navigation links, use this method:
#
#sub nav {
#	my ($self, $args) = @_;
#
#	my $output = '';
#
#	# See the documentation of path() and pathMacro() in
#	# WeBWorK::ContentGenerator for more information.
#
#	return $output;
#}

# SKEL: For a little box for display options, etc., use this method:
#
#sub options {
#	my ($self) = @_;
#
#	my $output = '';
#	# Append HTML to $output.
#
#	return $output;
#}

# SKEL: For a list of sibling objects, use this method:
#
#sub siblings {
#	my ($self, $args) = @_;
#
#	my $output = '';
#
#	# See the documentation of siblings() and siblingsMacro() in
#	# WeBWorK::ContentGenerator for more information.
#	#
#	# Refer to implementations in ProblemSet and Problem.
#
#	return $output;
#}

1;
