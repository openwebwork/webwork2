################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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
# "SKEL" comments and anything else that you're not using in your module.

# SKEL: Declare the name and superclass of your module here:
package WeBWorK::ContentGenerator::Skeleton;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

# Add '-async_await' above if needed.  This is needed anytime a problem is
# rendered.

# SKEL: change the name of the module below and provide a short description. Add
# additional POD documentation as you see fit.

=head1 NAME

WeBWorK::ContentGenerator::Skeleton - Template for creating subclasses of
WeBWorK::ContentGenerator.  Note that in addition to creating your module
from this template, you must create a Mojolicious template that generates
the main body of the page.

=cut

# SKEL: Add "use" lines for libraries you will be using here. Note that you only
# need to add a "use" line here if you will be instantiating now objects or
# calling free functions. If you have an existing instance (like $self->c) you
# can use it without a corresponding "use" line. Sample lines are given below:
#
# You might need some utility functions:
#use WeBWorK::Utils qw(function1 function2);

# SKEL: If you need to do any processing before the HTTP header is sent, do it
# in this method.  Note that this method may be async.
#
#sub pre_header_initialize ($c) {
#	# Do your processing here! Don't print or return anything -- store data in
#	# the $c hash or in $c->stash for later retrieveal.
#}

# SKEL: This method is not actually of any use anymore.
#
#sub header ($c) {
#	# The return value of this method is not used.
#	# The practice is to return the status code of the response.
#	return 0;
#}

# SKEL: If you need to do any processing after the HTTP header is sent, but before
# any template processing occurs, or you need to calculate values that will be
# used in multiple methods, do it in this method.  Note that this method may be
# async.
#
#sub initialize ($c) {
#	# Do your processing here! Don't print or return anything -- store data in
#	# the $c hash or in $c->stash for later retrieveal.
#}

# Note that all of the template methods below except head should ensure that the
# return value is a Mojo::ByteStream object if the return value contains HTML.

# SKEL: If you need to add tags to the document <HEAD>, uncomment this method:
#
#sub head ($c) {
#	my $output = '';
#	# You can append head tags to $output, like <META>, <SCRIPT>, etc.
#
#	return $output;
#}

# SKEL: To fill in the "info" box (to the right of the main body), use this
# method:
#
#sub info ($c) {
#	my $output = '';
#	# Append HTML to $output.
#
#	# Make sure the return value is a Mojo::ByteStream object if it contains html.
#	return $output;
#}

# SKEL: To provide navigation links, use this method:
#
#sub nav ($c, $args) {
#	my $output = '';
#
#	# See the documentation of path() and pathMacro() in
#	# WeBWorK::ContentGenerator for more information.
#
#	# Make sure the return value is a Mojo::ByteStream object if it contains html.
#	return $output;
#}

# SKEL: For a little box for display options, etc., use this method:
#
#sub options ($c) {
#	my $output = '';
#	# Append HTML to $output.
#
#	# Make sure the return value is a Mojo::ByteStream object if it contains html.
#	return $output;
#}

# SKEL: For a list of sibling objects, use this method:
#
#sub siblings ($c, $args) {
#	my $output = '';
#
#	# See the documentation of siblings() in WeBWorK::ContentGenerator for more information.
#	# Also refer to the implementations in ProblemSet and Problem.
#
#	# Make sure the return value is a Mojo::ByteStream object if it contains html.
#	return $output;
#}

1;
