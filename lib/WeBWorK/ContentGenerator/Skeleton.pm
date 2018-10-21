################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Skeleton.pm,v 1.5 2006/07/08 14:07:34 gage Exp $
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
use base qw(WeBWorK::ContentGenerator);

# SKEL: change the name of the module below and provide a short description. Add
# additional POD documentation as you see fit.

=head1 NAME

WeBWorK::ContentGenerator::Skeleton - Template for creating subclasses of
WeBWorK::ContentGenerator.

=cut

use strict;
use warnings;

# SKEL: Add "use" lines for libraries you will be using here. Note that you only
# need to add a "use" line here if you will be instantiating now objects or
# calling free functions. If you have an existing instance (like $self->r) you
# can use it without a corresponding "use" line. Sample lines are given below:
# 
# You'll probably want to generate HTML code:
#use CGI qw(-nosticky );
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

# SKEL: To emit your own HTTP header, uncomment this:
# 
#sub header {
#	my ($self) = @_;
#	
#	# Generate your HTTP header here.
#	
#	# If you return something, it will be used as the HTTP status code for this
#	# request. The Apache::Constants module might be useful for gerating status
#	# codes. If you don't return anything, the status code "OK" will be used.
#	return "";
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

# SKEL: If you need to add tags to the document <HEAD>, uncomment this method:
# 
#sub head {
#	my ($self) = @_;
#	
#	# You can print head tags here, like <META>, <SCRIPT>, etc.
#	
#	return "";
#}

# SKEL: To fill in the "info" box (to the right of the main body), use this
# method:
# 
#sub info {
#	my ($self) = @_;
#	
#	# Print HTML here.
#	
#	return "";
#}

# SKEL: To provide navigation links, use this method:
# 
#sub nav {
#	my ($self, $args) = @_;
#	
#	# See the documentation of path() and pathMacro() in
#	# WeBWorK::ContentGenerator for more information.
#	
#	return "";
#}

# SKEL: For a little box for display options, etc., use this method:
# 
#sub options {
#	my ($self) = @_;
#	
#	# Print HTML here.
#	
#	return "";
#}

# SKEL: For a list of sibling objects, use this method:
# 
#sub siblings {
#	my ($self, $args) = @_;
#	
#	# See the documentation of siblings() and siblingsMacro() in
#	# WeBWorK::ContentGenerator for more information.
#	# 
#	# Refer to implementations in ProblemSet and Problem.
#	
#	return "";
#}

# SKEL: Okay, here's the body. Most of your stuff will go here:
# 
sub body {
	my ($self) = @_;
	
	# SKEL: Useful things from the superclass:
	# 
	# The WeBWorK::Request object. Good for accessing request params and so on.
	#my $r = $self->r;
	# 
	# Do you need data from the course environment?
	#my $ce = $r->ce;
	# 
	# Will you be accessing the database?
	#my $db = $r->db;
	# 
	# Query authorization:
	#my $authz = $r->authz;
	# 
	# The WeBWorK::URLPath object. Necessary for getting/generating URL data:
	#my $urlpath = $r->urlpath;
	
	# FIXME: Add more examples of common idioms, mention WeBWorK::HTML::*
	# classes, refer to superclass methods.
	
	# SKEL: Print your content here!
	
	return "";	
}

1;
