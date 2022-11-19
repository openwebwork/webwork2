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

package WeBWorK::HTML::ScrollingRecordList;
use parent qw(Exporter);

=head1 NAME

WeBWorK::HTML::ScrollingRecordList - HTML widget for a scrolling list of
records.

=cut

use strict;
use warnings;

use Carp;

use WeBWorK::Utils::FormatRecords qw(getFormatsForClass formatRecords);
use WeBWorK::Utils::SortRecords qw(getSortsForClass sortRecords);
use WeBWorK::Utils::FilterRecords qw(getFiltersForClass filterRecords);

our @EXPORT_OK = qw(scrollingRecordList);

sub scrollingRecordList {
	my ($options, @records) = @_;

	my %options = (default_filters => [], default_sort => '', %$options);
	# %options must contain:
	#  name - name of scrolling list
	#  request - the WeBWorK::Request object for the current request
	# may contain:
	#  default_sort - name of sort to use by default
	#  default_format - name of format to use by default
	#  default_filters - a reference to a list of names of filters to apply by default
	#  size - number of rows shown in scrolling list
	#  multiple - are multiple selections allowed?

	my $name = $options{name};
	my $r    = $options{request};

	croak 'name not found in options'    unless defined $name;
	croak 'request not found in options' unless defined $r;

	my ($sorts, $formats, $filters, $formattedRecords) = ([], [], [], []);

	if (@records) {
		my $class = (ref $records[0]) =~ s/Version$//r;

		$sorts   = getSortsForClass($class, $options{default_sort});
		$formats = getFormatsForClass($class, $options{default_format});
		$filters = getFiltersForClass(@records);

		my @selected_filters;
		if (defined $r->param("$name!filter")) {
			@selected_filters = $r->param("$name!filter");
			@selected_filters = ("all") unless @selected_filters;
		} else {
			@selected_filters = @{ $options{default_filters} };
		}

		$formattedRecords = formatRecords(
			$options{default_format},
			sortRecords(
				$r->param("$name!sort") || $options{default_sort} || (@$sorts ? $sorts->[0][1] : ''),
				filterRecords(\@selected_filters, @records)
			)
		);
	}

	return $r->include(
		'HTML/ScrollingRecordList/scrollingRecordList',
		name             => $name,
		options          => \%options,
		sorts            => $sorts,
		formats          => $formats,
		filters          => $filters,
		formattedRecords => $formattedRecords
	);
}

1;
