################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

WeBWorK::HTML::ScrollingRecordList - HTML widget for a scrolling list of
records.

=cut

use Carp;

use WeBWorK::Utils::FormatRecords qw(getFormatsForClass formatRecords);
use WeBWorK::Utils::SortRecords qw(getSortsForClass sortRecords);
use WeBWorK::Utils::FilterRecords qw(getFiltersForClass filterRecords);

our @EXPORT_OK = qw(scrollingRecordList);

sub scrollingRecordList ($options, @records) {
	my %options = (default_filters => [], default_sort => '', %$options);
	# %options must contain:
	#  name       - name of scrolling list
	#  controller - the WeBWorK::Controller object for the current route
	# may contain:
	#  default_sort - name of sort to use by default
	#  default_format - name of format to use by default
	#  default_filters - a reference to a list of names of filters to apply by default
	#  size - number of rows shown in scrolling list
	#  multiple - are multiple selections allowed?

	my $name = $options{name};
	my $c    = $options{controller};

	croak 'name not found in options'       unless defined $name;
	croak 'controller not found in options' unless defined $c;

	my ($sorts, $formats, $filters, $formattedRecords) = ([], [], [], []);

	if (@records) {
		my $class = (ref $records[0]) =~ s/Version$//r;

		$sorts   = getSortsForClass($class, $options{default_sort});
		$formats = getFormatsForClass($class, $options{default_format});
		# Remove sorts that are irrelevant for our formats
		my @format_keywords;
		for my $format (@$formats) {
			push(@format_keywords, (split /\W+/, $format->[0]));
		}
		my $format_keywords = join('|', @format_keywords);
		@$sorts = grep { $_->[0] =~ /$format_keywords/ } @$sorts;

		$filters = getFiltersForClass($c, @records);

		my @selected_filters;
		if (defined $c->param("$name!filter")) {
			@selected_filters = $c->param("$name!filter");
			@selected_filters = ("all") unless @selected_filters;
		} else {
			@selected_filters = @{ $options{default_filters} };
		}

		$formattedRecords = formatRecords(
			$c,
			$c->param("$name!format") || $options{default_format},
			sortRecords(
				$c->param("$name!sort") || $options{default_sort} || (@$sorts ? $sorts->[0][1] : ''),
				filterRecords($c, $c->param("$name!filter_combine") // 0, \@selected_filters, @records)
			)
		);
	}

	return $c->include(
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
