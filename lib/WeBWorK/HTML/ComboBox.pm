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

package WeBWorK::HTML::ComboBox;
use base qw(Exporter);

=head1 NAME

WeBWorK::HTML::ComboBox - HTML widget for a textfield with a dropdown list

=cut

use strict;
use warnings;

our @EXPORT    = ();
our @EXPORT_OK = qw(comboBox);

sub comboBox {
	my ($options, @Records) = @_;

	# The parameters "name" and at least one of the "values" or "labels" are required.
	# The "default" value parameter is optional.

	my $name    = $options->{name};
	my $default = $options->{default};
	my @values  = ref $options->{values} eq "ARRAY" ? @{ $options->{values} } : ();
	my %labels  = ref $options->{labels} eq "HASH"  ? %{ $options->{labels} } : map { $_ => $_ } @values;

	# If only the labels are provided, use them as values as well.
	@values = keys %labels if (%labels and not @values);

	# Set $width equal to the length of the longest value
	my $width = 20;
	map { $width = length if (length) > $width } @values;

	return CGI::div(
		{ class => "combo-box" },
		CGI::div(
			CGI::textfield({
				name  => $name,
				value => $default // "",
				size  => $width,
				class => 'combo-box-text form-control mb-1'
			}),
			CGI::popup_menu({
				name    => $name,
				values  => \@values,
				labels  => \%labels,
				default => $default // 0,
				class   => 'combo-box-select form-select'
			})
		)
	);
}

1;
