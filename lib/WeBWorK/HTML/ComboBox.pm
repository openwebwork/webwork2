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

package WeBWorK::HTML::ComboBox;
use base qw(Exporter);

=head1 NAME

WeBWorK::HTML::ComboBox - HTML widget for a textfield with a dropdown list

=cut

use strict;
use warnings;
use Carp;

our @EXPORT    = ();
our @EXPORT_OK = qw(
	comboBox
);



sub comboBox {
	my ($options, @Records) = @_;
	
	my %options = (%$options);
	# %options must contain:
	#  name - name of combo list -- use $r->param("$name")
	#  request - the WeBWorK::Request object for the current request
	# may contain:
	#  default - default selection from pop_up list
	#  rows - number of rows shown in option list
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

	my $value = $r->param($name) || $default || "";
	
	my @values = ref $options{values} eq "ARRAY" ? @{ $options{values} } : ();
	my %labels = ref $options{labels} eq "HASH" ? %{ $options{labels} } : map { $_ => $_ } @values;
	
	# if someone just sends in the labels parameter, use all of them as values
	@values = keys %labels if (%labels and not @values);

	# makes $size = length of longest value + 4
	my $width = 20;
	map { $width = 4 + length if (length) > $width } @values;

	

	my %textfield_options = (
			-name => $name,
			-value => $value,
			-size => $width,		# we need to calculate this to be the same as the popup_menu
			-onKeyUp => "followType('$name')",
	);
	
	my %popup_options = (
			-name => $name,
			-values => \@values,
			-labels => \%labels,
			-default => $default || $r->param($name) || 0,
			-size => $size,
			-onChange => "changeText('$name')",
	);	

	return CGI::span({-class=>"OptionList"},
		CGI::table({cellpadding => 0, cellspacing => 0, border => 0}, 
			CGI::Tr({}, CGI::td({}, CGI::textfield({%textfield_options}))),
			CGI::Tr({}, CGI::td({}, CGI::popup_menu({%popup_options}))),
		),
		# this script alters the text box to be the same size as the select menu
		# and also provides a function to change the textbox text to the currently selected option
		CGI::script(join ("\n",
			"// set textbox width to be same as that of select menu",
			"document.getElementsByName('$name')[0].style.width = document.getElementsByName('$name')[1].offsetWidth;",
			"// set textbox text to be same as that of select menu",
			"function changeText (name) {
				var textbox = document.getElementsByName(name)[0];
				var select = document.getElementsByName(name)[1];
				textbox.value = select.options[select.selectedIndex].value;
			}",
			"// try to select best option in select menu as user types in textbox",
			"function followType (name) {
				var textbox = document.getElementsByName(name)[0];
				var select = document.getElementsByName(name)[1];
				var textboxValue = textbox.value
				for (var i = 0; (i < select.options.length) && (select.options[i].value.indexOf(textboxValue) != 0); i++) {}
				select.selectedIndex = i;
			}",
#			"changeText('$name');",
		)),
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
