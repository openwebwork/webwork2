################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: 
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

package WeBWorK::HTML::OptionList;
use base qw(Exporter);

=head1 NAME

WeBWorK::HTML::ScrollingRecordList - HTML widget for a textfield with a dropdown list

=cut

use strict;
use warnings;
use Carp;

our @EXPORT    = ();
our @EXPORT_OK = qw(
	optionList
);



sub optionList {
	my ($options, @Records) = @_;
	
	my %options = (%$options);
	# %options must contain:
	#  name - name of option list -- use $r->param("$name")
	#  request - the WeBWorK::Request object for the current request
	# may contain:
	#  default - default selection from pop_up list
	#  size - number of rows shown in option list
	#  multiple - are multiple selections allowed?
	
	croak "name not found in options" unless exists $options{name};
	croak "request not found in options" unless exists $options{request};
	my $name = $options{name};
	my $r = $options{request};
	
	my $default = $options{default};
	my $size = $options{size};
	$size = 1 unless defined $size;
	my $multiple = $options{multiple};
	$multiple = 0 unless defined $multiple;

	my $value = $r->param($name) || "";
	
	my @values = ref $options{values} eq "ARRAY" ? @{ $options{values} } : ();
	my %labels = ref $options{labels} eq "HASH" ? %{ $options{labels} } : map { $_ => $_ } @values;
	
	# if someone just sends in the labels parameter, use all of them as values
	@values = keys %labels if (%labels and not @values);


	map { $size = 4 + length if (length) > $size } @values;

	my %textfield_options = (
			name => $name,
			value => $value,
			size => $size,		# we need to calculate this to be the same as the popup_menu
	);
	
	my %popup_options = (
			-name => $name,
			-values => \@values,
			-labels => \%labels,
			-default => $default || $r->param($name) || 0,
	);	

	return CGI::span({-class=>"OptionList"},
		CGI::table({cellpadding => 0, cellspacing => 0, border => 0}, 
			CGI::Tr({}, CGI::td({}, CGI::textfield({%textfield_options}))),
			CGI::Tr({}, CGI::td({}, CGI::popup_menu({%popup_options}))),
		)
	);

	return CGI::span({-class=>"OptionList"},
		CGI::textfield({
			name => $name,
			value => $value,
			size => $size,		# we need to calculate this to be the same as the popup_menu
		}), CGI::br(),
		CGI::popup_menu(
			-name => $name,
			-values => \@values,
			-labels => \%labels,
			-default => $r->param($name),
		),
	);
}

1;
