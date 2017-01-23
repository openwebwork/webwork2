################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
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

package WeBWorK::HTML::DropdownRecordList;
use base qw(Exporter);

=head1 NAME

WeBWorK::HTML::DropdownList - HTML widget for a scrolling list of
records.

=cut

use strict;
use warnings;
use Carp;
use WeBWorK::Utils::FormatRecords qw/getFormatsForClass formatRecords/;
use WeBWorK::Utils::SortRecords qw/getSortsForClass sortRecords/;
use WeBWorK::Utils::FilterRecords qw/getFiltersForClass filterRecords/;

our @EXPORT    = ();
our @EXPORT_OK = qw(
	dropdownRecordList
);



sub dropdownRecordList {
	my ($options, @Records) = @_;
	
	my %options = (default_filters=>[],default_sort=>"",default_format=>"",%$options);
	# %options must contain:
	#  name - name of scrolling list -- use $r->param("$name")
	#  request - the WeBWorK::Request object for the current request
	# may contain:
	#  default_sort - name of sort to use by default
	#  default_format - name of format to use by default
	#  default_filter - listref, names of filters to apply by default (unimpl.)
	#  allowed_filters - hashref, mapping field name to list of allowed values (unimpl.)
	#  size - number of rows shown in scrolling list
	#  multiple - are multiple selections allowed?
	
	croak "name not found in options" unless exists $options{name};
	croak "request not found in options" unless exists $options{request};
	my $name = $options{name};
	my $r = $options{request};
	
	my $default_sort = $options{default_sort} || "";
	my $default_format = $options{default_format} || "";

	my @default_filters = @{$options{default_filters}} ;

	my $size = $options{size};
	my $multiple = $options{multiple};
	
	my $sorts = [];
	my $sort_labels = {};
	my $selected_sort = "";
	
	my $formats = [];
	my $format_labels = {};
	my $selected_format = "";
	
	my $filters = [];
	my $filter_labels = {};
	my @selected_filters= ();
	
	my @ids = ();
	my %labels = ();
	
	my @selected_records = $r->param("$name");

	if (@Records) {
		my $class = ref $Records[0];

		($filters, $filter_labels) = getFiltersForClass(@Records);
		if (defined $r->param("$name!filter")){
			@selected_filters = $r->param("$name!filter");
			@selected_filters = ("all") unless @selected_filters;
		}
		else {
			@selected_filters = @default_filters;
		}
	
		($sorts, $sort_labels) = getSortsForClass($class);
		$selected_sort = $r->param("$name!sort")
			|| $default_sort
			|| (@$sorts ? $sorts->[0] : "");
		
		($formats, $format_labels) = getFormatsForClass($class);
		$selected_format = $r->param("$name!format")
			|| $default_format
			|| (@$formats ? $formats->[0] : "");
		
		@Records = filterRecords({filter=>\@selected_filters},@Records);
		
		@Records = sortRecords({preset=>$selected_sort}, @Records);
		
		# generate IDs from keyfields
		my @keyfields = $class->KEYFIELDS;
		foreach my $Record (@Records) {
			push @ids, join("!", map { $Record->$_ } @keyfields);
		}
		
		# generate labels hash
		@labels{@ids} = @Records;
		%labels = formatRecords({preset=>$selected_format}, %labels);
	}
	
	my %sort_popup_options = (
		-name => "$name!sort",
		-values => $sorts,
		-default => $selected_sort,
		-labels => $sort_labels,
	);
	
	my %format_popup_options = (
		-name => "$name!format",
		-values => $formats,
		-default => $selected_format,
		-labels => $format_labels,
	);

	my %filter_options = (
		-name => "$name!filter",
		-values => $filters,
		-default => \@selected_filters,
		-labels => $filter_labels,
		-size => 3,
		-multiple => 1,
	);

	my %list_options = (
		-class=>"ScrollingRecordList",
		-name => "$name",
		-values => \@ids,
		-default => \@selected_records,
		-labels => \%labels,
	);
	$list_options{-size} = $size if $size;
	$list_options{-multiple} = $multiple if $multiple;
	
	my $value = $r->param($name) || "";
	
	map { $size = 4 + length if length > $size } values %{ $options{values} };

	my %textfield_options = (
			name => $name,
			value => $value,
			size => $size,		# we need to calculate this to be the same as the popup_menu
	);	
	
	return CGI::div({-class=>"ScrollingRecordList"},
		CGI::textfield(%textfield_options),
		CGI::scrolling_list(%list_options)
	);
	
	return CGI::div({-class=>"ScrollingRecordList"},
		$r->maketext("Sort:").' ', CGI::popup_menu(%sort_popup_options), CGI::br(),
		$r->maketext("Format:").' ', CGI::popup_menu(%format_popup_options), CGI::br(),
		$r->maketext("Filter:").' ', CGI::scrolling_list(%filter_options), CGI::br(),
		CGI::submit("$name!refresh", $->maketext("Change Display Settings")), CGI::br(),
		CGI::scrolling_list(%list_options)
	);
}

1;
