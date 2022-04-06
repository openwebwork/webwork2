################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
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
use base qw(Exporter);

=head1 NAME

WeBWorK::HTML::ScrollingRecordList - HTML widget for a scrolling list of
records.

=cut

use strict;
use warnings;
use Carp;
use WeBWorK::Utils::FormatRecords qw/getFormatsForClass formatRecords/;
use WeBWorK::Utils::SortRecords qw/getSortsForClass sortRecords/;
use WeBWorK::Utils::FilterRecords qw/getFiltersForClass filterRecords/;

our @EXPORT    = ();
our @EXPORT_OK = qw(scrollingRecordList);

sub scrollingRecordList {
	my ($options, @Records) = @_;

	my %options = (default_filters => [], default_sort => "", default_format => "", %$options);
	# %options must contain:
	#  name - name of scrolling list
	#  request - the WeBWorK::Request object for the current request
	# may contain:
	#  default_sort - name of sort to use by default
	#  default_format - name of format to use by default
	#  default_filter - listref, names of filters to apply by default (unimpl.)
	#  allowed_filters - hashref, mapping field name to list of allowed values (unimpl.)
	#  size - number of rows shown in scrolling list
	#  multiple - are multiple selections allowed?

	croak "name not found in options"    unless exists $options{name};
	croak "request not found in options" unless exists $options{request};
	my $name = $options{name};
	my $r    = $options{request};

	my ($sorts,   $sort_labels,   $selected_sort)   = ([], {}, "");
	my ($formats, $format_labels, $selected_format) = ([], {}, "");
	my ($filters, $filter_labels, @selected_filters) = ([], {});

	my @ids;
	my %labels;

	my $refresh_button_name =
		defined($options{refresh_button_name})
		? $options{refresh_button_name}
		: $r->maketext("Change Display Settings");

	my @selected_records = $r->param($name);

	if (@Records) {
		my $class = ref $Records[0];
		$class = $1 if $class =~ /(.*)Version$/;

		($filters, $filter_labels) = getFiltersForClass(@Records);
		if (defined $r->param("$name!filter")) {
			@selected_filters = $r->param("$name!filter");
			@selected_filters = ("all") unless @selected_filters;
		} else {
			@selected_filters = @{ $options{default_filters} };
		}

		($sorts, $sort_labels) = getSortsForClass($class);
		$selected_sort =
			$r->param("$name!sort")
			|| $options{default_sort}
			|| (@$sorts ? $sorts->[0] : "");

		($formats, $format_labels) = getFormatsForClass($class);
		$selected_format =
			$r->param("$name!format")
			|| $options{default_format}
			|| (@$formats ? $formats->[0] : "");

		@Records = filterRecords({ filter => \@selected_filters }, @Records);

		@Records = sortRecords({ preset => $selected_sort }, @Records);

		# Generate IDs from keyfields
		my @keyfields = $class->KEYFIELDS;
		foreach my $Record (@Records) {
			push @ids, join("!", map { $Record->$_ } @keyfields);
		}

		# Generate labels hash
		@labels{@ids} = @Records;
		%labels = formatRecords({ preset => $selected_format }, %labels);
	}

	return CGI::div(
		{ class => "card p-2" },
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => "$name!sort", class => 'col-form-label col-form-label-sm col-2 pe-1 text-nowrap' },
				$r->maketext('Sort:')
			),
			CGI::div(
				{ class => 'col-10' },
				CGI::popup_menu({
					name    => "$name!sort",
					id      => "$name!sort",
					values  => $sorts,
					default => $selected_sort,
					labels  => $sort_labels,
					class   => 'form-select form-select-sm'
				})
			)
		),
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => "$name!format", class => 'col-form-label col-form-label-sm col-2 pe-1 text-nowrap' },
				$r->maketext('Format:')
			),
			CGI::div(
				{ class => 'col-10' },
				CGI::popup_menu({
					name    => "$name!format",
					id      => "$name!format",
					values  => $formats,
					default => $selected_format,
					labels  => $format_labels,
					class   => 'form-select form-select-sm'
				})
			)
		),
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => "$name!filter", class => 'col-form-label col-form-label-sm col-2 pe-1 text-nowrap' },
				$r->maketext("Filter:")
			),
			CGI::div(
				{ class => 'col-10' },
				CGI::scrolling_list({
					name     => "$name!filter",
					id       => "$name!filter",
					values   => $filters,
					default  => \@selected_filters,
					labels   => $filter_labels,
					size     => 5,
					multiple => 1,
					class    => 'form-select form-select-sm'
				})
			)
		),
		CGI::div(CGI::submit(
			{ name => "$name!refresh", label => $refresh_button_name, class => 'btn btn-secondary btn-sm mb-2' }
		)),
		CGI::scrolling_list({
			name    => $name,
			id      => $name,
			values  => \@ids,
			default => \@selected_records,
			labels  => \%labels,
			class   => 'form-select form-select-sm',
			$options{attrs} ? %{ $options{attrs} } : ()
		}),
	);
}

1;
